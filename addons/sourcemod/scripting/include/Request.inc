#if defined _class_request_
  #endinput
#endif
#define _class_request_

#include <basic>

methodmap Request < Basic
{
	// Constructor
	public Request()
	{
		Basic myclass = new Basic();

		myclass.SetString("method", "");
		myclass.SetString("module", "");
		myclass.SetString("function", "");
		myclass.SetHandle("events", null);
		myclass.SetHandle("args", null);

		return view_as<Request>(myclass);
	}

	public static Request FromString(const char[] data)
	{
		Request request = new Request();

		JSONObject jsonObject = JSONObject.FromString(data);

		if (jsonObject == null)
			return null;

		if (!jsonObject.Size)
		{
			delete jsonObject;
			return null;
		}

		char sMethod[64];
		if (jsonObject.GetString("method", sMethod, sizeof(sMethod)) == true)
			request.SetMethod(sMethod);

		char sModule[64];
		if (jsonObject.GetString("module", sModule, sizeof(sModule)) == true)
			request.SetModule(sModule);

		char sFunction[64];
		if (jsonObject.GetString("function", sFunction, sizeof(sFunction)) == true)
			request.SetFunction(sFunction);

		if (jsonObject.HasKey("args"))
		{
			JSONType jsonType = jsonObject.GetType("args");
			if (jsonType == JSON_ARRAY)
			{
				request.args = view_as<JSONArray>(jsonObject.Get("args"));
			}
		}

		if (jsonObject.HasKey("events"))
		{
			JSONType jsonType = jsonObject.GetType("events");
			if (jsonType == JSON_ARRAY)
			{
				request.events = view_as<JSONArray>(jsonObject.Get("events"));
			}
		}

		delete jsonObject;
		return request;
	}

	// Retrieves the JSON string representation.
	//
	// @param buffer     String buffer to write to.
	// @param maxlength  Maximum length of the string buffer.
	// @param flags      Encoding flags.
	// @return           True on success, false on failure.
	public bool ToString(char[] buffer, int maxlength, int flags = 0)
	{
		JSONObject jsonData = new JSONObject();

		char sMethod[64];
		if (this.GetMethod(sMethod, sizeof(sMethod)) == true)
			jsonData.SetString("method", sMethod);

		char sModule[64];
		if (this.GetMethod(sModule, sizeof(sModule)) == true)
			jsonData.SetString("module", sModule);

		char sFunction[64];
		if (this.GetFunction(sFunction, sizeof(sFunction)) == true)
			jsonData.SetString("function", sFunction);

		if (this.args != null)
		{
			jsonData.Set("args", this.args);
		}

		bool success = jsonData.ToString(buffer, maxlength, flags);

		delete jsonData;

		return success;
	}

    public void Delete()
    {
		if (this.args != null)
			delete this.args;

		if (this.events != null)
			delete this.events;
    }

	public bool GetMethod(char[] buffer, int length)
	{
		return this.GetString("method", buffer, length);
	}

	public void SetMethod(const char[] buffer)
	{
		this.SetString("method", buffer);
	}

	public bool GetModule(char[] buffer, int length)
	{
		return this.GetString("module", buffer, length);
	}

	public void SetModule(const char[] buffer)
	{
		this.SetString("module", buffer);
	}

	public bool GetFunction(char[] buffer, int length)
	{
		return this.GetString("function", buffer, length);
	}

	public void SetFunction(const char[] buffer)
	{
		this.SetString("function", buffer);
	}

	property JSONArray args
	{
		public get()
		{
			return view_as<JSONArray>(this.GetHandle("args"));
		}
		public set(JSONArray args)
		{
			this.SetHandle("args", args);
		}
	}

	property JSONArray events
	{
		public get()
		{
			return view_as<JSONArray>(this.GetHandle("events"));
		}
		public set(JSONArray events)
		{
			this.SetHandle("events", events);
		}
	}
};
