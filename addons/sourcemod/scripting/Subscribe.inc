#include "GameEvents.inc"
#include "Forwards.inc"

#define MAX_SUBSCRIBERS MAX_CLIENTS

enum
{
	eSubscribeError_OutOfRange = -1,
	eSubscribeError_Inactive = -2,
	eSubscribeError_GameEvent = -3,
	eSubscribeError_Forward = -4,
}

static bool g_Subscriber_Active[MAX_SUBSCRIBERS] = { false, ... };
static int g_Subscriber_Client[MAX_SUBSCRIBERS] = { -1, ... };

static ArrayList g_Subscriber_GameEvents[MAX_SUBSCRIBERS];
static ArrayList g_Subscriber_Forwards[MAX_SUBSCRIBERS];

bool Subscribe_OnPluginStart()
{
	GameEvents_Init();
}

int Subscriber_Create(int Client)
{
	int Index = Client;
	if(Index < 0 || Index >= MAX_SUBSCRIBERS || g_Subscriber_Active[Index])
	{
		Index = GetFreeSubscriberIndex();
		if(Index == eSubscribeError_OutOfRange)
			return eSubscribeError_OutOfRange;
	}

	g_Subscriber_Active[Index] = true;
	g_Subscriber_Client[Index] = Client;

	g_Subscriber_GameEvents[Index] = new ArrayList(ByteCountToCells(32));
	g_Subscriber_Forwards[Index] = new ArrayList(ByteCountToCells(32));

	return Index;
}

int Subscriber_Destroy(int Index)
{
	if(Index < 0 || Index >= MAX_SUBSCRIBERS)
		return eSubscribeError_OutOfRange;

	if(!g_Subscriber_Active[Index])
		return eSubscribeError_Inactive;

	for(int i = 0; i < g_Subscriber_GameEvents[Index].Length; i++)
	{
		static char sEventName[32];
		g_Subscriber_GameEvents[Index].GetString(i, sEventName, sizeof(sEventName));
		GameEvents_Unhook(sEventName);
	}

	delete g_Subscriber_GameEvents[Index];
	delete g_Subscriber_Forwards[Index];

	g_Subscriber_Active[Index] = false;
	g_Subscriber_Client[Index] = -1;
	return 0;
}

int Subscriber_HandleRequest(int Index, JSONObject Request, JSONObject Response)
{
	static char sMethod[32];
	Request.GetString("method", sMethod, sizeof(sMethod));

	static char sModule[32];
	if(Request.GetString("module", sModule, sizeof(sModule)) == false)
	{
		JSONObject jError = new JSONObject();
		jError.SetString("error", "Request has no 'module' string-value.");
		Response.Set("error", jError);
		return -1;
	}
	Response.SetString("module", sModule);

	if(StrEqual(sModule, "gameevents"))
	{
		JSONArray EventArray = view_as<JSONArray>(Request.Get("events"));
		if(EventArray == null || !EventArray.Length)
		{
			delete EventArray;
			JSONObject jError = new JSONObject();
			jError.SetString("error", "Request has no 'events' array-value.");
			Response.Set("error", jError);
			return -1;
		}

		int Method = 0;
		if(StrEqual(sMethod, "subscribe"))
			Method = 1;
		else if(StrEqual(sMethod, "unsubscribe"))
			Method = 2;
		else if(StrEqual(sMethod, "replay"))
			Method = 3;

		JSONArray EventArrayResponse = new JSONArray();

		for(int i = 0; i < EventArray.Length; i++)
		{
			static char sEventName[32];
			if(EventArray.GetString(i, sEventName, sizeof(sEventName)) == false)
			{
				JSONObject jError = new JSONObject();
				jError.SetString("error", "not a string-value");
				EventArrayResponse.Push(jError);
				continue;
			}

			int Res;
			if(Method == 1)
				Res = Subscribe_GameEvents_Subscribe(Index, sEventName);
			else if(Method == 2)
				Res = Subscribe_GameEvents_Unsubscribe(Index, sEventName);
			else if(Method == 3)
				Res = Subscribe_GameEvents_Replay(Index, sEventName);

			EventArrayResponse.PushInt(Res);
		}
		delete EventArray;

		Response.Set("events", EventArrayResponse);
		return 0;
	}
	else if(StrEqual(sModule, "forwards"))
	{
		JSONArray EventArray = view_as<JSONArray>(Request.Get("events"));
		if(EventArray == null || !EventArray.Length)
		{
			delete EventArray;
			JSONObject jError = new JSONObject();
			jError.SetString("error", "Request has no 'events' array-value.");
			Response.Set("error", jError);
			return -1;
		}

		int Method = 0;
		if(StrEqual(sMethod, "subscribe"))
			Method = 1;
		else if(StrEqual(sMethod, "unsubscribe"))
			Method = 2;
		else if(StrEqual(sMethod, "replay"))
			Method = 3;

		JSONArray EventArrayResponse = new JSONArray();

		for(int i = 0; i < EventArray.Length; i++)
		{
			static char sEventName[32];
			if(EventArray.GetString(i, sEventName, sizeof(sEventName)) == false)
			{
				JSONObject jError = new JSONObject();
				jError.SetString("error", "not a string-value");
				EventArrayResponse.Push(jError);
				continue;
			}

			int Res;
			if(Method == 1)
				Res = Subscribe_Forwards_Subscribe(Index, sEventName);
			else if(Method == 2)
				Res = Subscribe_Forwards_Unsubscribe(Index, sEventName);
			else if(Method == 3)
				Res = Subscribe_Forwards_Replay(Index, sEventName);

			EventArrayResponse.PushInt(Res);
		}
		delete EventArray;

		Response.Set("events", EventArrayResponse);
		return 0;
	}

	JSONObject jError = new JSONObject();
	jError.SetString("error", "No handler found for requested module.");
	Response.Set("error", jError);
	return -1;
}

static int GetFreeSubscriberIndex()
{
	for(int i = 0; i < MAX_SUBSCRIBERS; i++)
	{
		if(!g_Subscriber_Active[i])
			return i;
	}
	return eSubscribeError_OutOfRange;
}

/* GameEvents */
static int Subscribe_GameEvents_Subscribe(int Index, const char[] sEventName)
{
	if(Index < 0 || Index >= MAX_SUBSCRIBERS)
		return eSubscribeError_OutOfRange;

	if(!g_Subscriber_Active[Index])
		return eSubscribeError_Inactive;

	int Find = g_Subscriber_GameEvents[Index].FindString(sEventName);
	if(Find != -1)
		return Find;

	if(GameEvents_Hook(sEventName) < 0)
		return eSubscribeError_GameEvent;

	return g_Subscriber_GameEvents[Index].PushString(sEventName);
}

static int Subscribe_GameEvents_Unsubscribe(int Index, const char[] sEventName)
{
	if(Index < 0 || Index >= MAX_SUBSCRIBERS)
		return eSubscribeError_OutOfRange;

	if(!g_Subscriber_Active[Index])
		return eSubscribeError_Inactive;

	int Find = g_Subscriber_GameEvents[Index].FindString(sEventName);
	if(Find == -1)
		return 0;

	if(GameEvents_Unhook(sEventName) < 0)
		return eSubscribeError_GameEvent;

	g_Subscriber_GameEvents[Index].Erase(Find);
	return Find;
}

static int Subscribe_GameEvents_Replay(int Index, const char[] sEventName)
{
	if(Index < 0 || Index >= MAX_SUBSCRIBERS)
		return eSubscribeError_OutOfRange;

	if(!g_Subscriber_Active[Index])
		return eSubscribeError_Inactive;

	if(StrEqual(sEventName, "player_connect"))
	{
		for(int client = 1; client <= MaxClients; client++)
		{
			if(!IsClientConnected(client))
				continue;

			char sName[MAX_NAME_LENGTH];
			GetClientName(client, sName, sizeof(sName));

			char sSteamID[32];
			GetClientAuthId(client, AuthId_Engine, sSteamID, sizeof(sSteamID), false);

			char sAddress[32];
			GetClientIP(client, sAddress, sizeof(sAddress), false);

			JSONObject jEventData = new JSONObject();
			jEventData.SetString("name", sName);
			jEventData.SetInt("index", client - 1);
			jEventData.SetInt("userid", GetClientUserId(client));
			jEventData.SetString("networkid", sSteamID);
			jEventData.SetString("address", sAddress);
			jEventData.SetBool("bot", IsFakeClient(client));

			Subscribe_GameEvents_FakePublish(g_Subscriber_Client[Index], sEventName, jEventData);
		}
	}
	else if(StrEqual(sEventName, "player_activate"))
	{
		for(int client = 1; client <= MaxClients; client++)
		{
			if(!IsClientInGame(client))
				continue;

			JSONObject jEventData = new JSONObject();
			jEventData.SetInt("userid", GetClientUserId(client));

			Subscribe_GameEvents_FakePublish(g_Subscriber_Client[Index], sEventName, jEventData);
		}
	}
	else
		return eSubscribeError_GameEvent;

	return 0;
}

static int Subscribe_GameEvents_FakePublish(int Index, const char[] sEventName, JSONObject jEventData)
{
	if(Index < 0 || Index >= MAX_SUBSCRIBERS)
		return eSubscribeError_OutOfRange;

	if(!g_Subscriber_Active[Index])
		return eSubscribeError_Inactive;

	JSONObject jEvent = new JSONObject();
	jEvent.SetString("name", sEventName);
	jEvent.Set("data", jEventData);

	JSONObject jPublish = new JSONObject();
	jPublish.SetString("method", "publish");
	jPublish.SetString("module", "gameevents");
	jPublish.Set("event", jEvent);

	PublishEvent(g_Subscriber_Client[Index], jPublish);
	delete jPublish;

	return 0;
}

void Subscribe_GameEvents_Publish(const char[] sEventName, JSONObject jEvent)
{
	JSONObject jPublish = new JSONObject();
	jPublish.SetString("method", "publish");
	jPublish.SetString("module", "gameevents");
	jPublish.Set("event", jEvent);

	for(int Index = 0; Index < MAX_SUBSCRIBERS; Index++)
	{
		if(!g_Subscriber_Active[Index])
			continue;

		if(g_Subscriber_GameEvents[Index].FindString(sEventName) == -1)
			continue;

		PublishEvent(g_Subscriber_Client[Index], jPublish);
	}

	delete jPublish;
}
/* GameEvents */

/* Forwards */
static int Subscribe_Forwards_Subscribe(int Index, const char[] sEventName)
{
	if(Index < 0 || Index >= MAX_SUBSCRIBERS)
		return eSubscribeError_OutOfRange;

	if(!g_Subscriber_Active[Index])
		return eSubscribeError_Inactive;

	int Find = g_Subscriber_Forwards[Index].FindString(sEventName);
	if(Find != -1)
		return Find;

	// TODO: forward exists?

	return g_Subscriber_Forwards[Index].PushString(sEventName);
}

static int Subscribe_Forwards_Unsubscribe(int Index, const char[] sEventName)
{
	if(Index < 0 || Index >= MAX_SUBSCRIBERS)
		return eSubscribeError_OutOfRange;

	if(!g_Subscriber_Active[Index])
		return eSubscribeError_Inactive;

	int Find = g_Subscriber_Forwards[Index].FindString(sEventName);
	if(Find == -1)
		return 0;

	g_Subscriber_Forwards[Index].Erase(Find);
	return Find;
}

static int Subscribe_Forwards_Replay(int Index, const char[] sEventName)
{
	if(Index < 0 || Index >= MAX_SUBSCRIBERS)
		return eSubscribeError_OutOfRange;

	if(!g_Subscriber_Active[Index])
		return eSubscribeError_Inactive;

	if(StrEqual(sEventName, "OnClientPostAdminCheck"))
	{
		for(int client = 1; client <= MaxClients; client++)
		{
			if(!IsClientInGame(client) || !IsClientAuthorized(client))
				continue;

			JSONObject jEventData = new JSONObject();
			jEventData.SetInt("client", client);

			Subscribe_Forwards_FakePublish(g_Subscriber_Client[Index], sEventName, jEventData);
		}
	}
	else
		return eSubscribeError_Forward;

	return 0;
}

static int Subscribe_Forwards_FakePublish(int Index, const char[] sEventName, JSONObject jEventData)
{
	if(Index < 0 || Index >= MAX_SUBSCRIBERS)
		return eSubscribeError_OutOfRange;

	if(!g_Subscriber_Active[Index])
		return eSubscribeError_Inactive;

	JSONObject jEvent = new JSONObject();
	jEvent.SetString("name", sEventName);
	jEvent.Set("data", jEventData);

	JSONObject jPublish = new JSONObject();
	jPublish.SetString("method", "publish");
	jPublish.SetString("module", "forwards");
	jPublish.Set("event", jEvent);

	PublishEvent(g_Subscriber_Client[Index], jPublish);
	delete jPublish;

	return 0;
}

void Subscribe_Forwards_Publish(const char[] sEventName, JSONObject jEvent)
{
	JSONObject jPublish = new JSONObject();
	jPublish.SetString("method", "publish");
	jPublish.SetString("module", "forwards");
	jPublish.Set("event", jEvent);

	for(int Index = 0; Index < MAX_SUBSCRIBERS; Index++)
	{
		if(!g_Subscriber_Active[Index])
			continue;

		if(g_Subscriber_Forwards[Index].FindString(sEventName) == -1)
			continue;

		PublishEvent(g_Subscriber_Client[Index], jPublish);
	}

	delete jPublish;
}
/* Forwards */
