public void API_PrintToChatAll(const char[] format, any ...)
{
	char buffer[254];

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			SetGlobalTransTarget(i);
			VFormat(buffer, sizeof(buffer), format, 2);
			PrintToChat(i, "%s", buffer);
		}
	}
}

public void API_PrintCenterTextAll(const char[] format, any ...)
{
	char buffer[254];

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			SetGlobalTransTarget(i);
			VFormat(buffer, sizeof(buffer), format, 2);
			PrintCenterText(i, "%s", buffer);
		}
	}
}

public void API_PrintHintTextToAll(const char[] format, any ...)
{
	char buffer[254];

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			SetGlobalTransTarget(i);
			VFormat(buffer, sizeof(buffer), format, 2);
			PrintHintText(i, "%s", buffer);
		}
	}
}

public void API_PrintToChat(int client, const char[] format, any ...)
{
	char buffer[254];

	if (IsClientInGame(client))
	{
		SetGlobalTransTarget(client);
		VFormat(buffer, sizeof(buffer), format, 3);
		PrintToChat(client, "%s", buffer);
	}
}

public void API_CPrintToChat(int client, const char[] format, any ...)
{
	char buffer[254];

	if (IsClientInGame(client))
	{
		SetGlobalTransTarget(client);
		VFormat(buffer, sizeof(buffer), format, 3);
		CPrintToChat(client, "%s", buffer);
	}
}

public void API_CPrintToChatAll(const char[] format, any ...)
{
	char buffer[254];

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			SetGlobalTransTarget(i);
			VFormat(buffer, sizeof(buffer), format, 2);
			CPrintToChat(i, "%s", buffer);
		}
	}
}

public int API_GetMaxClients()
{
	return MaxClients;
}

public int API_GetUserFlagBits(int client)
{
	if (!IsClientConnected(client))
		return 0;
	
	return GetUserFlagBits(client);
}

public void API_CreateMenu(int client, int data)
{
	if (!(1 <= client <= MaxClients) || !IsClientInGame(client))
		return;

	Menu menu = new Menu(API_MenuCallback);
	
	JSONObject dataObj = view_as<JSONObject>(data);
	
	char title[128];
	dataObj.GetString("title", title, sizeof(title));
	menu.SetTitle(title);
	
	JSONArray options = view_as<JSONArray>(dataObj.Get("options"));
	if (options == null)
		return;
	
	for (int i = 0; i < options.Length; i++)
	{
		JSONArray thisArr = view_as<JSONArray>(options.Get(i));
		if (thisArr == null)
			continue;
		
		char option_data[255], option_display[255];
		thisArr.GetString(0, option_data, sizeof(option_data));
		thisArr.GetString(1, option_display, sizeof(option_display));
		
		menu.AddItem(option_data, option_display);
	}

	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int API_MenuCallback(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End:
			delete menu;
		
		case MenuAction_Select:
		{
			char[] sEventName = "OnMenuSelect";
			
			JSONObject jEvent = new JSONObject();
			jEvent.SetString("name", sEventName);

			JSONObject jEventData = new JSONObject();
			jEventData.SetString("type", "trigger");
			jEventData.SetInt("client", param1);
			
			char option[255];
			menu.GetItem(param2, option, sizeof(option));
			
			jEventData.SetString("option", option);
		
			jEvent.Set("data", jEventData);
			
			Subscribe_Forwards_Publish(sEventName, jEvent);
			
			delete jEventData;
		}
	}
	
	return 0;
}
