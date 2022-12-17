
public void OnClientPostAdminCheck(int client)
{
	JSONObject jEventData = new JSONObject();
	jEventData.SetInt("client", client);

	JSONObject jEvent = new JSONObject();
	jEvent.SetString("name", "OnClientPostAdminCheck");
	jEvent.Set("data", jEventData);

	Subscribe_Forwards_Publish("OnClientPostAdminCheck", jEvent);

	delete jEventData;
}
