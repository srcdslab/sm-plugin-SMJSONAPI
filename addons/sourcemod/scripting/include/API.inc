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
	return GetUserFlagBits(client);
}
