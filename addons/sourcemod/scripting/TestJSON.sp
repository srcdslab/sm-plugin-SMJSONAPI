#pragma semicolon 1
#pragma newdecls required
#pragma dynamic 65535

#include <sourcemod>
#include <ripext>

#define MAX_CLIENTS 16

public Plugin myinfo =
{
	name = "Test JSON",
	author = "BotoX, maxime1907",
	description = "Test JSON",
	version = "1.0.3",
	url = ""
}

stock void JSON_FreeArray(JSONArray &jsonArray)
{
	for (int i = 0; i < jsonArray.Length; i++)
	{
		JSONType jSubType = jsonArray.GetType(i);
		if (jSubType == JSON_ARRAY)
		{
			JSONArray jSubValue = view_as<JSONArray>(jsonArray.Get(i));
			JSON_FreeArray(jSubValue);
		}
		else if (jSubType == JSON_OBJECT)
		{
			JSONObject jSubValue = view_as<JSONObject>(jsonArray.Get(i));
			JSON_FreeObject(jSubValue);
		}
		jsonArray.Remove(i);
	}

	delete jsonArray;
}

stock void JSON_FreeObject(JSONObject &jsonObject)
{
	JSONObjectKeys jKeys = jsonObject.Keys();
	char sKey[64];

	while (jKeys.ReadKey(sKey, sizeof(sKey)))
	{
		JSONType jType = jsonObject.GetType(sKey);

		if (jType == JSON_ARRAY)
		{
			JSONArray jValue = view_as<JSONArray>(jsonObject.Get(sKey));
			JSON_FreeArray(jValue);
		}
		else if (jType == JSON_OBJECT)
		{
			JSONObject jValue = view_as<JSONObject>(jsonObject.Get(sKey));
			JSON_FreeObject(jValue);
		}
		jsonObject.Remove(sKey);
	}

	delete jKeys;
	delete jsonObject;
}

public void OnConfigsExecuted()
{
    JSONObj jResponse = new JSONObj();
    JSONObject jObject = new JSONObject();
    jResponse.SetObject("obj", jObject);
    jResponse.RemoveObject("obj");

    delete jResponse;
}
