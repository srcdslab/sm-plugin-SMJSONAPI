static KeyValues g_Config;

bool GameEvents_Init()
{
	char sGame[32];
	GetGameFolderName(sGame, sizeof(sGame));

	char sConfigFile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sConfigFile, sizeof(sConfigFile), "configs/Events.%s.cfg", sGame);
	if(!FileExists(sConfigFile))
	{
		SetFailState("Could not find config: \"%s\"", sConfigFile);
	}

	g_Config = new KeyValues("allevents");
	if(!g_Config.ImportFromFile(sConfigFile))
	{
		delete g_Config;
		SetFailState("ImportFromFile() failed!");
	}

	return true;
}

static void GameEvents_OnHook(Event event, const char[] name, bool dontBroadcast)
{
	static char sEventName[32];
	event.GetName(sEventName, sizeof(sEventName));

	g_Config.JumpToKey(sEventName);

	JSONObject jEvent = new JSONObject();
	jEvent.SetString("name", sEventName);

	JSONObject jEventData = new JSONObject();

	if(g_Config.GotoFirstSubKey(false))
	{
		do
		{
			static char sKey[32];
			static char sType[8];

			g_Config.GetSectionName(sKey, sizeof(sKey));
			g_Config.GetString(NULL_STRING, sType, sizeof(sType));

			if(StrEqual(sKey, "_hooked"))
				continue;

			if(StrEqual(sType, "short") || StrEqual(sType, "long") || StrEqual(sType, "byte"))
			{
				int iValue = event.GetInt(sKey);
				jEventData.SetInt(sKey, iValue);
			}
			else if(StrEqual(sType, "float"))
			{
				float fValue = event.GetFloat(sKey);
				jEventData.SetFloat(sKey, fValue);
			}
			else if(StrEqual(sType, "bool"))
			{
				bool bValue = event.GetBool(sKey);
				jEventData.SetBool(sKey, bValue);
			}
			else if(StrEqual(sType, "string"))
			{
				static char sValue[1024];
				event.GetString(sKey, sValue, sizeof(sValue));
				jEventData.SetString(sKey, sValue);
			}
		} while(g_Config.GotoNextKey(false));
	}
	g_Config.Rewind();

	jEvent.Set("data", jEventData);

	Subscribe_GameEvents_Publish(sEventName, jEvent);
}

int GameEvents_Hook(const char[] sEventName)
{
	if(!g_Config.JumpToKey(sEventName))
		return -1;

	int Hooked = g_Config.GetNum("_hooked", 0);
	if(Hooked)
	{
		g_Config.SetNum("_hooked", Hooked + 1);
		g_Config.Rewind();
		return Hooked + 1;
	}

	Hooked = HookEventEx(sEventName, GameEvents_OnHook, EventHookMode_Post);
	if(Hooked)
		g_Config.SetNum("_hooked", 1);

	g_Config.Rewind();
	return Hooked ? 1 : -1;
}

int GameEvents_Unhook(const char[] sEventName)
{
	if(!g_Config.JumpToKey(sEventName))
		return -1;

	int Hooked = g_Config.GetNum("_hooked", 0);
	if(!Hooked)
	{
		g_Config.Rewind();
		return 0;
	}

	if(Hooked == 1)
		UnhookEvent(sEventName, GameEvents_OnHook, EventHookMode_Post);

	g_Config.SetNum("_hooked", Hooked - 1);

	g_Config.Rewind();
	return Hooked - 1;
}

stock void GameEvents_HookAll()
{
	g_Config.GotoFirstSubKey(false);

	do
	{
		static char sKey[32];
		g_Config.GetSectionName(sKey, sizeof(sKey));

		int Hooked = g_Config.GetNum("_hooked", 0);
		if(!Hooked)
		{
			if(HookEventEx(sKey, GameEvents_OnHook, EventHookMode_Post))
				g_Config.SetNum("_hooked", 1);
		}
		else
			g_Config.SetNum("_hooked", Hooked + 1);
	} while(g_Config.GotoNextKey(true));

	g_Config.Rewind();
}

stock void GameEvents_UnhookAll()
{
	g_Config.GotoFirstSubKey(false);

	do
	{
		static char sKey[32];
		g_Config.GetSectionName(sKey, sizeof(sKey));

		int Hooked = g_Config.GetNum("_hooked", 0);
		if(Hooked)
		{
			UnhookEvent(sKey, GameEvents_OnHook, EventHookMode_Post);
			g_Config.SetNum("_hooked", 0);
		}
	} while(g_Config.GotoNextKey(true));

	g_Config.Rewind();
}
