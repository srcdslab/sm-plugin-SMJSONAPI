#pragma semicolon 1
#pragma newdecls required
#pragma dynamic 65535

#include <sourcemod>
#include <AsyncSocket>
#include <ripext>
#include <multicolors>

#define MAX_CLIENTS 16

#include "Request.inc"
#include "Response.inc"
#include "API.inc"
#include "Subscribe.inc"

#define LOCALHOST_IP "127.0.0.1"

static AsyncSocket g_ServerSocket = null;

static AsyncSocket g_Client_Socket[MAX_CLIENTS] = { null, ... };
static int g_Client_Subscriber[MAX_CLIENTS] = { -1, ... };

ConVar g_ListenAddr;
ConVar g_ListenPort;
ConVar g_Debug;
ConVar g_WhitelistedIPs;

StringMap g_smWhitelistedIPs;

public Plugin myinfo =
{
	name = "SM JSON API",
	author = "BotoX, maxime1907",
	description = "SourceMod TCP JSON API",
	version = "1.2.1",
	url = ""
}

public void OnPluginStart()
{
	Subscribe_OnPluginStart();

	g_ListenAddr = CreateConVar("sm_jsonapi_addr", "127.0.0.1", "SM JSON API listen ip address", FCVAR_PROTECTED);
	g_ListenPort = CreateConVar("sm_jsonapi_port", "27021", "SM JSON API listen ip address", FCVAR_PROTECTED, true, 1025.0, true, 65535.0);
	g_Debug = CreateConVar("sm_jsonapi_debug", "0", "Print debug logs", FCVAR_NONE);
	g_WhitelistedIPs = CreateConVar("sm_jsonapi_whitelisted_ips", "172.17.0.1", "Whitelisted IPs (Separated by ',' empty means only localhost can connect)", FCVAR_PROTECTED);

	AutoExecConfig(true);
}

public void OnConfigsExecuted()
{
	if (g_ServerSocket)
		return;

	g_ServerSocket = new AsyncSocket();

	g_ServerSocket.SetConnectCallback(OnAsyncConnect);
	g_ServerSocket.SetErrorCallback(OnAsyncServerError);

	char sAddr[32];
	g_ListenAddr.GetString(sAddr, sizeof(sAddr));
	int Port = g_ListenPort.IntValue;

	g_ServerSocket.Listen(sAddr, Port);
	LogMessage("Listening on %s:%d", sAddr, Port);

	// Get whitelisted ips:
	delete g_smWhitelistedIPs;

	char sWhitelistedAddrs[256];
	g_WhitelistedIPs.GetString(sWhitelistedAddrs, sizeof(sWhitelistedAddrs));

	if (!sWhitelistedAddrs[0])
		return;

	g_smWhitelistedIPs = new StringMap();

	if (StrContains(sWhitelistedAddrs, ",") == -1)
	{
		g_smWhitelistedIPs.SetValue(sWhitelistedAddrs, true);
		return;		
	}

	int iAddrsCount = 0;
	for (int i = 0; i < strlen(sWhitelistedAddrs); i++)
	{
		if (sWhitelistedAddrs[i] == ',')
			iAddrsCount++;
	}

	// Impossible to happen but just to be safe.
	if (iAddrsCount == 0)
		return;

	char[][] sWhitelistedAddrsArr = new char[++iAddrsCount][32];
	ExplodeString(sWhitelistedAddrs, ",", sWhitelistedAddrsArr, iAddrsCount, 32);

	for (int i = 0; i < iAddrsCount; i++)
	{
		TrimString(sWhitelistedAddrsArr[i]);
		g_smWhitelistedIPs.SetValue(sWhitelistedAddrsArr[i], true);
	}
}

static void OnAsyncConnect(AsyncSocket socket)
{
	char ip[32];
	socket.GetClientIP(ip, sizeof(ip));

	if (!IsIPWhitelisted(ip))
	{
		LogMessage("Blocked receiving data from: %s", ip);
		delete socket;
		return;
	}

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
	Request request = Request.FromString(data);

	Response response = new Response();

	if (request == null)
	{
		int iLine;
		int iColumn;
		char sError[256];

		JSONObject jError = new JSONObject();
		jError.SetString("type", "json");
		jError.SetString("error", sError);
		jError.SetInt("line", iLine);
		jError.SetInt("column", iColumn);

		response.error = jError;
	}
	else
	{
		if (g_Debug.IntValue)
		{
			char sRequest[4096];
			request.ToString(sRequest, sizeof(sRequest));
			LogMessage("%s", sRequest);
		}

		int client = ClientFromSocket(socket);
		HandleRequest(client, request, response);

		request.Delete();
		delete request;
	}

	char sResponse[4096];
	response.ToString(sResponse, sizeof(sResponse));

	if (g_Debug.IntValue)
		LogMessage("%s", sResponse);

	socket.WriteNull(sResponse);

	response.Delete();
	delete response;
}

stock JSONArray HandleRequestFunctionArgs(Request request, Response response)
{
	JSONArray jArgsArray = request.args;
	if(jArgsArray == null || !jArgsArray.Length)
	{
		Call_Cancel();
		JSONObject jError = new JSONObject();
		jError.SetString("error", "Request has no 'args' array-value.");
		response.error = jError;
		return null;
	}

	int aiValues[32];
	int iValues = 0;

	float afValues[32];
	int fValues = 0;

	char asValues[16][1024];
	int sValues = 0;

	for(int i = 0; i < jArgsArray.Length; i++)
	{
		bool Fail = false;

		JSONType jType = jArgsArray.GetType(i);

		if(jType == JSON_ARRAY)
		{
			JSONArray jValueArray = view_as<JSONArray>(jArgsArray.Get(i));
			JSONType jTypeArray = jValueArray.GetType(0);

			if(jTypeArray == JSON_INTEGER || jTypeArray == JSON_TRUE || jTypeArray == JSON_FALSE)
			{
				int iValues_ = iValues;
				for(int j = 0; j < jValueArray.Length; j++)
				{
					aiValues[iValues_++] = jValueArray.GetInt(j);
				}

				Call_PushArrayEx(aiValues[iValues], jValueArray.Length, SM_PARAM_COPYBACK);
				iValues += jValueArray.Length;
			}
			else if(jTypeArray == JSON_REAL)
			{
				int fValues_ = fValues;
				for(int j = 0; j < jValueArray.Length; j++)
				{
					afValues[fValues_++] = jValueArray.GetFloat(j);
				}

				Call_PushArrayEx(afValues[fValues], jValueArray.Length, SM_PARAM_COPYBACK);
				fValues += jValueArray.Length;
			}
			/*else if(jTypeArray == JSON_STRING)
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
			else if(jTypeArray == JSON_ARRAY) // Special
			{
				char sSpecial[32];
				JSONArray jArrayValue = view_as<JSONArray>(jValueArray.Get(0));
				jArrayValue.GetString(0, sSpecial, sizeof(sSpecial));

				if(StrEqual(sSpecial, "NULL_VECTOR"))
					Call_PushArrayEx(NULL_VECTOR, 3, 0);
				else if(StrEqual(sSpecial, "NULL_STRING"))
					Call_PushString(NULL_STRING);
				else
					Fail = true;
				
				delete jArrayValue;
			}
			else
				Fail = true;

			delete jValueArray;

			if(Fail)
			{
				Call_Cancel();

				char sError[128];
				FormatEx(sError, sizeof(sError), "Unsupported parameter in list %d of type '%d'", i, jTypeArray);

				JSONObject jError = new JSONObject();
				jError.SetString("error", sError);
				response.error = jError;

				return null;
			}
		}
		else if(jType == JSON_INTEGER || jType == JSON_TRUE || jType == JSON_FALSE)
		{
			aiValues[iValues] = jArgsArray.GetInt(i);
			Call_PushCell(aiValues[iValues++]);
		}
		else if(jType == JSON_REAL)
		{
			afValues[fValues] = jArgsArray.GetFloat(i);
			Call_PushFloat(afValues[fValues++]);
		}
		else if(jType == JSON_STRING)
		{
			jArgsArray.GetString(i, asValues[sValues], sizeof(asValues[]));
			Call_PushStringEx(asValues[sValues++], sizeof(asValues[]), SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
		}
		else if(jType == JSON_OBJECT)
		{
			aiValues[iValues] = view_as<int>(jArgsArray.Get(i));
			Call_PushCell(aiValues[iValues++]);
		}
		else
		{
			Call_Cancel();

			char sError[128];
			FormatEx(sError, sizeof(sError), "Unsupported parameter %d of type '%d'", i, jType);

			JSONObject jError = new JSONObject();
			jError.SetString("error", sError);
			response.error = jError;
			return null;
		}
	}

	int result;
	char sException[1024] = "Failed to execute function";
	#if defined Call_FinishEx
	int Error = Call_FinishEx(result, sException, sizeof(sException));
	#else
	int Error = Call_Finish(result);
	#endif

	if(Error != SP_ERROR_NONE)
	{
		JSONObject jError = new JSONObject();
		jError.SetInt("error", Error);
		jError.SetString("exception", sException);
		response.error = jError;
		return null;
	}

	response.result = result;

	JSONArray jArgsResponse = new JSONArray();
	iValues = 0;
	fValues = 0;
	sValues = 0;

	for(int i = 0; i < jArgsArray.Length; i++)
	{
		JSONType jType = jArgsArray.GetType(i);

		if(jType == JSON_ARRAY)
		{
			JSONArray jValueArray = view_as<JSONArray>(jArgsArray.Get(i));
			JSONType jTypeArray = jValueArray.GetType(0);

			JSONArray jArrayResponse = new JSONArray();

			if(jTypeArray == JSON_INTEGER || jTypeArray == JSON_TRUE || jTypeArray == JSON_FALSE)
			{
				for(int j = 0; j < jValueArray.Length; j++)
					jArrayResponse.PushInt(aiValues[iValues++]);
			}
			else if(jTypeArray == JSON_REAL)
			{
				for(int j = 0; j < jValueArray.Length; j++)
					jArrayResponse.PushFloat(afValues[fValues++]);
			}
			else if(jTypeArray == JSON_STRING)
			{
				for(int j = 0; j < jValueArray.Length; j++)
					jArrayResponse.PushString(asValues[sValues++]);
			}
			else if(jTypeArray == JSON_ARRAY) // Special
			{
				char sSpecial[32];
				JSONArray jArrayValue = view_as<JSONArray>(jValueArray.Get(0));
				jArrayValue.GetString(0, sSpecial, sizeof(sSpecial));
				jArrayResponse.PushString(sSpecial);

				delete jArrayValue;
			}
			jArgsResponse.Push(jArrayResponse);

			delete jValueArray;
		}
		else if(jType == JSON_INTEGER || jType == JSON_TRUE || jType == JSON_FALSE)
		{
			jArgsResponse.PushInt(aiValues[iValues++]);
		}
		else if(jType == JSON_REAL)
		{
			jArgsResponse.PushFloat(afValues[fValues++]);
		}
		else if(jType == JSON_STRING)
		{
			jArgsResponse.PushString(asValues[sValues++]);
		}
		else if(jType == JSON_OBJECT)
		{
			jArgsResponse.Push(view_as<JSON>(aiValues[iValues++]));
		}
	}
	return jArgsResponse;
}

stock int HandleRequestFunction(Request request, Response response)
{
	char sFunction[64];
	if(request.GetFunction(sFunction, sizeof(sFunction)) == false)
	{
		JSONObject jError = new JSONObject();
		jError.SetString("error", "Request has no 'function' string-value.");
		response.error = jError;
		return -1;
	}
	response.SetFunction(sFunction);

	char sAPIFunction[64];
	Format(sAPIFunction, sizeof(sAPIFunction), "API_%s", sFunction);

	Function Fun = INVALID_FUNCTION;
	Handle FunPlugin = INVALID_HANDLE;

	Fun = GetFunctionByName(FunPlugin, sAPIFunction);
	if (Fun == INVALID_FUNCTION)
	{
		Handle hPluginIterator = GetPluginIterator();
		while (MorePlugins(hPluginIterator))
		{
			FunPlugin = ReadPlugin(hPluginIterator);
			Fun = GetFunctionByName(FunPlugin, sFunction);
			if (Fun != INVALID_FUNCTION)
				break;
		}
	}

	if(Fun == INVALID_FUNCTION)
	{
		int Res = 0;
		#if defined Call_StartNative
		Res = Call_StartNative(sFunction);
		#endif
		if(!Res)
		{
			JSONObject jError = new JSONObject();
			jError.SetString("error", "Invalid function specified.");
			jError.SetInt("code", Res);
			response.error = jError;
			return -1;
		}
	}
	else
		Call_StartFunction(FunPlugin, Fun);

	JSONArray jArgsResponse = HandleRequestFunctionArgs(request, response);

	if (jArgsResponse == null)
		return -1;

	response.args = jArgsResponse;

	return 0;
}

stock int HandleRequestSubscriber(int Client, Request request, Response response)
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
			response.error = jError;
			return -1;
		}
		g_Client_Subscriber[Client] = Subscriber;
	}

	return Subscriber_HandleRequest(Subscriber, request, response);
}

static int HandleRequest(int client, Request request, Response response)
{
	char sMethod[32];
	if (request.GetMethod(sMethod, sizeof(sMethod)) == false)
	{
		JSONObject jError = new JSONObject();
		jError.SetString("error", "Request has no 'method' string-value.");
		response.error = jError;
		return -1;
	}
	response.SetMethod(sMethod);

	if (StrEqual(sMethod, "subscribe") || StrEqual(sMethod, "unsubscribe") || StrEqual(sMethod, "replay"))
	{
		return HandleRequestSubscriber(client, request, response);
	}
	else if (StrEqual(sMethod, "function"))
	{
		return HandleRequestFunction(request, response);
	}

	JSONObject jError = new JSONObject();
	jError.SetString("error", "No handler found for requested method.");
	response.error = jError;
	return -1;
}

int PublishEvent(int Client, JSONObject Object)
{
	if(Client < 0 || Client > MAX_CLIENTS || g_Client_Socket[Client] == null)
		return -1;

	char sEvent[4096];
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

/**
 * Checks if an IP string (e.g. "172.17.0.5") matches a CIDR range or exact IP (e.g. "172.17.0.0/16" or "192.168.1.50").
 *
 * @param clientIp    	The incoming client IP string.
 * @param cidrEntry   	The whitelist entry (e.g., "172.17.0.0/16" or "192.168.1.1").
 * @return              True if the IP matches, false otherwise.
 */
bool IsIPInCIDR(const char[] clientIp, const char[] cidrEntry)
{
    char rangeIp[16];
    char prefixBit[4];
    
    int iSlashPos = SplitString(cidrEntry, "/", rangeIp, sizeof(rangeIp));
    int iPrefixLen = 32;
    
    if (iSlashPos != -1)
    {
        strcopy(prefixBit, sizeof(prefixBit), cidrEntry[iSlashPos]);
        iPrefixLen = StringToInt(prefixBit);
    }
    else
    {
        strcopy(rangeIp, sizeof(rangeIp), cidrEntry);
    }

    if (iPrefixLen <= 0)
    	return true;
    if (iPrefixLen > 32)
    	iPrefixLen = 32;

    int iClientIp = IPv4ToInt(clientIp);
    int iRangeIp  = IPv4ToInt(rangeIp);

    if (iClientIp == 0 || iRangeIp == 0)
        return false;

    int iMask = (iPrefixLen == 32) ? -1 : ~((1 << (32 - iPrefixLen)) - 1);

    return (iClientIp & iMask) == (iRangeIp & iMask);
}

int IPv4ToInt(const char[] ip)
{
    char octets[4][4];
    if (ExplodeString(ip, ".", octets, 4, 4) != 4)
        return 0;

    int b1 = StringToInt(octets[0]);
    int b2 = StringToInt(octets[1]);
    int b3 = StringToInt(octets[2]);
    int b4 = StringToInt(octets[3]);

    return (b1 << 24) | (b2 << 16) | (b3 << 8) | b4;
}

bool IsIPWhitelisted(const char[] ip)
{
	if (strcmp(ip, LOCALHOST_IP) == 0 || strcmp(ip, "::1") == 0)
		return true;

	if (!g_smWhitelistedIPs)
		return false;

	bool value;
	if (g_smWhitelistedIPs.GetValue(ip, value))
		return true;

	StringMapSnapshot snapshot = g_smWhitelistedIPs.Snapshot();
	bool match = false;
	for (int i = 0; i < snapshot.Length; i++)
	{
		char thisIp[32];
		if (!snapshot.GetKey(i, thisIp, sizeof(thisIp)))
			continue;

		if (IsIPInCIDR(ip, thisIp))
		{
			match = true;
			break;
		}
	}

	delete snapshot;
	return match;
}
