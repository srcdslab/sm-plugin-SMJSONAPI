#pragma semicolon 1
#pragma newdecls required
#pragma dynamic 65535

#include <sourcemod>
#include <AsyncSocket>
#include <smjansson>

#define MAX_CLIENTS 16

#include "API.inc"
#include "Subscribe.inc"

static AsyncSocket g_ServerSocket;

static AsyncSocket g_Client_Socket[MAX_CLIENTS] = { null, ... };
static int g_Client_Subscriber[MAX_CLIENTS] = { -1, ... };

ConVar g_ListenAddr;
ConVar g_ListenPort;

public Plugin myinfo =
{
	name = "SM JSON API",
	author = "BotoX",
	description = "SourceMod TCP JSON API",
	version = "1.0",
	url = ""
}

public void OnPluginStart()
{
	Subscribe_OnPluginStart();

	g_ListenAddr = CreateConVar("sm_jsonapi_addr", "127.0.0.1", "SM JSON API listen ip address", FCVAR_PROTECTED);
	g_ListenPort = CreateConVar("sm_jsonapi_port", "27021", "SM JSON API listen ip address", FCVAR_PROTECTED, true, 1025.0, true, 65535.0);

	AutoExecConfig(true);
}

public void OnConfigsExecuted()
{
	if(g_ServerSocket)
		return;

	g_ServerSocket = new AsyncSocket();

	g_ServerSocket.SetConnectCallback(OnAsyncConnect);
	g_ServerSocket.SetErrorCallback(OnAsyncServerError);

	char sAddr[32];
	g_ListenAddr.GetString(sAddr, sizeof(sAddr));
	int Port = g_ListenPort.IntValue;

	g_ServerSocket.Listen(sAddr, Port);
	LogMessage("Listening on %s:%d", sAddr, Port);
}

static void OnAsyncConnect(AsyncSocket socket)
{
	int Client = GetFreeClientIndex();
	LogMessage("OnAsyncConnect(Client=%d)", Client);

	if(Client == -1)
	{
		delete socket;
		return;
	}

	g_Client_Socket[Client] = socket;
	socket.SetErrorCallback(OnAsyncClientError);
	socket.SetDataCallback(OnAsyncData);
}

static void OnAsyncServerError(AsyncSocket socket, int error, const char[] errorName)
{
	SetFailState("OnAsyncServerError(): %d, \"%s\"", error, errorName);
}

static void OnAsyncClientError(AsyncSocket socket, int error, const char[] errorName)
{
	int Client = ClientFromSocket(socket);
	LogMessage("OnAsyncClientError(Client=%d): %d, \"%s\"", Client, error, errorName);

	if(Client == -1)
	{
		delete socket;
		return;
	}

	if(g_Client_Subscriber[Client] != -1)
	{
		Subscriber_Destroy(g_Client_Subscriber[Client]);
		g_Client_Subscriber[Client] = -1;
	}

	g_Client_Socket[Client] = null;
	delete socket;
}

static void OnAsyncData(AsyncSocket socket, const char[] data, const int size)
{
	int Client = ClientFromSocket(socket);

	int iLine;
	int iColumn;
	static char sError[256];
	JSONValue jRequest = json_load_ex(data, sError, sizeof(sError), iLine, iColumn);

	if(jRequest == null)
	{
		JSONObject jResponse = new JSONObject();

		JSONObject jError = new JSONObject();
		jError.SetString("type", "json");
		jError.SetString("error", sError);
		jError.SetInt("line", iLine);
		jError.SetInt("column", iColumn);

		jResponse.Set("error", jError);

		jResponse.ToString(sError, sizeof(sError));
		socket.WriteNull(sError);

		delete jResponse;
		return;
	}

	if(jRequest.IsObject)
	{
		//view_as<JSONObject>(jRequest).DumpToServer();
		JSONObject jResponse = new JSONObject();
		// Negative values and objects indicate errors
		// 0 and positive integers indicate success
		jResponse.SetInt("error", 0);

		HandleRequest(Client, view_as<JSONObject>(jRequest), jResponse);

		static char sResponse[4096];
		jResponse.ToString(sResponse, sizeof(sResponse));
		socket.WriteNull(sResponse);
		delete jResponse;
	}

	delete jRequest;
}

static int HandleRequest(int Client, JSONObject jRequest, JSONObject jResponse)
{
	static char sMethod[32];
	if(jRequest.GetString("method", sMethod, sizeof(sMethod)) < 0)
	{
		JSONObject jError = new JSONObject();
		jError.SetString("error", "Request has no 'method' string-value.");
		jResponse.Set("error", jError);
		return -1;
	}
	jResponse.SetString("method", sMethod);

	if(StrEqual(sMethod, "subscribe") || StrEqual(sMethod, "unsubscribe") || StrEqual(sMethod, "replay"))
	{
		int Subscriber = g_Client_Subscriber[Client];
		if(Subscriber == -1)
		{
			Subscriber = Subscriber_Create(Client);
			if(Subscriber < 0)
			{
				JSONObject jError = new JSONObject();
				jError.SetString("type", "subscribe");
				jError.SetString("error", "Could not allocate a subscriber.");
				jError.SetInt("code", Subscriber);
				jResponse.Set("error", jError);
				return -1;
			}
			g_Client_Subscriber[Client] = Subscriber;
		}

		return Subscriber_HandleRequest(Subscriber, jRequest, jResponse);
	}
	else if(StrEqual(sMethod, "function"))
	{
		static char sFunction[64];
		if(jRequest.GetString("function", sFunction, sizeof(sFunction)) < 0)
		{
			JSONObject jError = new JSONObject();
			jError.SetString("error", "Request has no 'function' string-value.");
			jResponse.Set("error", jError);
			return -1;
		}
		jResponse.SetString("function", sFunction);

		static char sAPIFunction[64];
		Format(sAPIFunction, sizeof(sAPIFunction), "API_%s", sFunction);

		Function Fun = GetFunctionByName(INVALID_HANDLE, sAPIFunction);
		if(Fun == INVALID_FUNCTION)
		{
			int Res = Call_StartNative(sFunction);
			if(!Res)
			{
				JSONObject jError = new JSONObject();
				jError.SetString("error", "Invalid function specified.");
				jError.SetInt("code", Res);
				jResponse.Set("error", jError);
				return -1;
			}
		}
		else
			Call_StartFunction(INVALID_HANDLE, Fun);

		JSONArray jArgsArray = view_as<JSONArray>(jRequest.Get("args"));
		if(jArgsArray == null || !jArgsArray.IsArray)
		{
			delete jArgsArray;
			Call_Cancel();
			JSONObject jError = new JSONObject();
			jError.SetString("error", "Request has no 'args' array-value.");
			jResponse.Set("error", jError);
			return -1;
		}

		int aiValues[32];
		int iValues = 0;

		float afValues[32];
		int fValues = 0;

		static char asValues[16][1024];
		int sValues = 0;

		for(int i = 0; i < jArgsArray.Length; i++)
		{
			bool Fail = false;
			JSONValue jValue;
			jValue = jArgsArray.Get(i);

			char sType1[32];
			jValue.TypeToString(sType1, sizeof(sType1));

			if(jValue.IsArray)
			{
				JSONArray jValueArray = view_as<JSONArray>(jValue);
				JSONValue jArrayValue = jValueArray.Get(0);

				char sType2[32];
				jArrayValue.TypeToString(sType2, sizeof(sType2));

				if(jArrayValue.IsInteger || jArrayValue.IsBoolean)
				{
					int iValues_ = iValues;
					for(int j = 0; j < jValueArray.Length; j++)
					{
						JSONInteger jInteger = view_as<JSONInteger>(jValueArray.Get(j));
						aiValues[iValues_++] = jInteger.Value;
						delete jInteger;
					}

					Call_PushArrayEx(aiValues[iValues], jValueArray.Length, SM_PARAM_COPYBACK);
					iValues += jValueArray.Length;
				}
				else if(jArrayValue.IsFloat)
				{
					int fValues_ = fValues;
					for(int j = 0; j < jValueArray.Length; j++)
					{
						JSONFloat jFloat = view_as<JSONFloat>(jValueArray.Get(j));
						afValues[fValues_++] = jFloat.Value;
						delete jFloat;
					}

					Call_PushArrayEx(afValues[fValues], jValueArray.Length, SM_PARAM_COPYBACK);
					fValues += jValueArray.Length;
				}
				/*else if(jArrayValue.IsString)
				{
					int sValues_ = sValues;
					for(int j = 0; j < jValueArray.Length; j++)
					{
						JSONString jString = view_as<JSONString>(jValueArray.Get(j));
						jString.GetString(asValues[sValues_++], sizeof(asValues[]));
						delete jString;
					}

					Call_PushArrayEx(view_as<int>(asValues[sValues]), jValueArray.Length, SM_PARAM_COPYBACK);
					sValues += jValueArray.Length;
				}*/
				else if(jArrayValue.IsArray) // Special
				{
					static char sSpecial[32];
					view_as<JSONArray>(jArrayValue).GetString(0, sSpecial, sizeof(sSpecial));

					if(StrEqual(sSpecial, "NULL_VECTOR"))
						Call_PushArrayEx(NULL_VECTOR, 3, 0);
					else if(StrEqual(sSpecial, "NULL_STRING"))
						Call_PushString(NULL_STRING);
					else
						Fail = true;
				}
				else
					Fail = true;

				if(Fail)
				{
					Call_Cancel();
					delete jArrayValue;
					delete jValue;
					delete jArgsArray;

					static char sType[16];
					jValue.TypeToString(sType, sizeof(sType));

					char sError[128];
					FormatEx(sError, sizeof(sError), "Unsupported parameter in list %d of type '%s'", i, sType);

					JSONObject jError = new JSONObject();
					jError.SetString("error", sError);
					jResponse.Set("error", jError);
					return -1;
				}
				delete jArrayValue;
			}
			else if(jValue.IsInteger || jValue.IsBoolean)
			{
				aiValues[iValues] = view_as<JSONInteger>(jValue).Value;
				Call_PushCell(aiValues[iValues++]);
			}
			else if(jValue.IsFloat)
			{
				afValues[fValues] = view_as<JSONFloat>(jValue).Value;
				Call_PushFloat(afValues[fValues++]);
			}
			else if(jValue.IsString)
			{
				// Broken: view_as<JSONString>(jValue).GetString(asValues[sValues], sizeof(asValues[]));
				JSONString jString = view_as<JSONString>(jValue);
				jString.GetString(asValues[sValues], sizeof(asValues[]));
				Call_PushStringEx(asValues[sValues++], sizeof(asValues[]), SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
			}
			else
			{
				Call_Cancel();
				delete jValue;
				delete jArgsArray;

				static char sType[16];
				jValue.TypeToString(sType, sizeof(sType));

				char sError[128];
				FormatEx(sError, sizeof(sError), "Unsupported parameter %d of type '%s'", i, sType);

				JSONObject jError = new JSONObject();
				jError.SetString("error", sError);
				jResponse.Set("error", jError);
				return -1;
			}
			delete jValue;
		}

		int Result;
		static char sException[1024];
		int Error = Call_FinishEx(Result, sException, sizeof(sException));

		if(Error != SP_ERROR_NONE)
		{
			delete jArgsArray;
			JSONObject jError = new JSONObject();
			jError.SetInt("error", Error);
			jError.SetString("exception", sException);
			jResponse.Set("error", jError);
			return -1;
		}

		jResponse.SetInt("result", Result);

		JSONArray jArgsResponse = new JSONArray();
		iValues = 0;
		fValues = 0;
		sValues = 0;

		for(int i = 0; i < jArgsArray.Length; i++)
		{
			JSONValue jValue;
			jValue = jArgsArray.Get(i);

			if(jValue.IsArray)
			{
				JSONArray jArrayResponse = new JSONArray();
				JSONArray jValueArray = view_as<JSONArray>(jValue);
				JSONValue jArrayValue = jValueArray.Get(0);

				if(jArrayValue.IsInteger || jArrayValue.IsBoolean)
				{
					for(int j = 0; j < jValueArray.Length; j++)
						jArrayResponse.AppendInt(aiValues[iValues++]);
				}
				else if(jArrayValue.IsFloat)
				{
					for(int j = 0; j < jValueArray.Length; j++)
						jArrayResponse.AppendFloat(afValues[fValues++]);
				}
				else if(jArrayValue.IsString)
				{
					for(int j = 0; j < jValueArray.Length; j++)
						jArrayResponse.AppendString(asValues[sValues++]);
				}
				else if(jArrayValue.IsArray) // Special
				{
					static char sSpecial[32];
					view_as<JSONArray>(jArrayValue).GetString(0, sSpecial, sizeof(sSpecial));
					jArrayResponse.AppendString(sSpecial);
				}
				delete jArrayValue;
				jArgsResponse.Append(jArrayResponse);
			}
			else if(jValue.IsInteger || jValue.IsBoolean)
			{
				jArgsResponse.AppendInt(aiValues[iValues++]);
			}
			else if(jValue.IsFloat)
			{
				jArgsResponse.AppendFloat(afValues[fValues++]);
			}
			else if(jValue.IsString)
			{
				jArgsResponse.AppendString(asValues[sValues++]);
			}
			delete jValue;
		}

		jResponse.Set("args", jArgsResponse);

		delete jArgsArray;
		return 0;
	}

	JSONObject jError = new JSONObject();
	jError.SetString("error", "No handler found for requested method.");
	jResponse.Set("error", jError);
	return -1;
}

int PublishEvent(int Client, JSONObject Object)
{
	if(Client < 0 || Client > MAX_CLIENTS || g_Client_Socket[Client] == null)
		return -1;

	static char sEvent[4096];
	Object.ToString(sEvent, sizeof(sEvent));
	g_Client_Socket[Client].WriteNull(sEvent);

	return 0;
}

static int GetFreeClientIndex()
{
	for(int i = 0; i < MAX_CLIENTS; i++)
	{
		if(!g_Client_Socket[i])
			return i;
	}
	return -1;
}

static int ClientFromSocket(AsyncSocket socket)
{
	for(int i = 0; i < MAX_CLIENTS; i++)
	{
		if(g_Client_Socket[i] == socket)
			return i;
	}
	return -1;
}
