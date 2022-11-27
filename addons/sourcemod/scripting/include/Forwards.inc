
public void OnClientPostAdminCheck(int client)
{
	JSONObject jEvent = new JSONObject();
	jEvent.SetString("name", "OnClientPostAdminCheck");

	JSONObject jEventData = new JSONObject();
	jEventData.SetInt("client", client);

	jEvent.Set("data", jEventData);

	Subscribe_Forwards_Publish("OnClientPostAdminCheck", jEvent);
}
