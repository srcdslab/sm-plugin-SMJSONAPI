#if defined _class_response_
  #endinput
#endif
#define _class_response_

#include <basic>

methodmap Response < Basic
{
    // Constructor
    public Response()
    {
        Basic myclass = new Basic();

        myclass.SetHandle("error", null);
        myclass.SetString("function", "");
        myclass.SetString("method", "");
        myclass.SetString("module", "");
        myclass.SetHandle("args", null);
        myclass.SetHandle("events", null);
        myclass.SetInt("result", 0);

        return view_as<Response>(myclass);
    }

	public static Response FromString(const char[] data)
	{
		Response response = new Response();

		JSONObject jsonObject = JSONObject.FromString(data);

		if (jsonObject == null)
			return null;

		if (!jsonObject.Size)
        {
			delete jsonObject;
			return null;
        }

		response.result = jsonObject.GetInt("result");

		char sMethod[64];
		if (jsonObject.GetString("method", sMethod, sizeof(sMethod)) == true)
			response.SetMethod(sMethod);

		char sFunction[64];
		if (jsonObject.GetString("function", sFunction, sizeof(sFunction)) == true)
			response.SetFunction(sFunction);

		char sModule[64];
		if (jsonObject.GetString("module", sModule, sizeof(sModule)) == true)
			response.SetModule(sModule);

		if (jsonObject.HasKey("args"))
		{
			JSONType jsonType = jsonObject.GetType("args");
			if (jsonType == JSON_ARRAY)
			{
				response.args = view_as<JSONArray>(jsonObject.Get("args"));
			}
		}

		if (jsonObject.HasKey("events"))
		{
			JSONType jsonType = jsonObject.GetType("events");
			if (jsonType == JSON_ARRAY)
			{
				response.events = view_as<JSONArray>(jsonObject.Get("events"));
			}
		}

		if (jsonObject.HasKey("error"))
		{
			JSONType jsonType = jsonObject.GetType("error");
			if (jsonType == JSON_OBJECT)
			{
				response.error = view_as<JSONObject>(jsonObject.Get("error"));
			}
		}

		delete jsonObject;
		return response;
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

		char sFunction[64];
		if (this.GetFunction(sFunction, sizeof(sFunction)) == true)
			jsonData.SetString("function", sFunction);

		char sModule[64];
		if (this.GetModule(sModule, sizeof(sModule)) == true)
			jsonData.SetString("module", sModule);

		if (this.args != null)
		{
			jsonData.Set("args", this.args);
		}

		if (this.events != null)
		{
			jsonData.Set("events", this.events);
		}

		if (this.error != null)
		{
			jsonData.Set("error", this.error);
		}
		else
		{
			jsonData.SetInt("error", 0);
		}

		jsonData.SetInt("result", this.result);

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

        if (this.error != null)
            delete this.error;
    }

	public bool GetMethod(char[] buffer, int length)
	{
		return this.GetString("method", buffer, length);
	}

	public void SetMethod(const char[] buffer)
	{
		this.SetString("method", buffer);
	}

	public bool GetFunction(char[] buffer, int length)
	{
		return this.GetString("function", buffer, length);
	}

	public void SetFunction(const char[] buffer)
	{
		this.SetString("function", buffer);
	}

	public bool GetModule(char[] buffer, int length)
	{
		return this.GetString("module", buffer, length);
	}

	public void SetModule(const char[] buffer)
	{
		this.SetString("module", buffer);
	}

	property int result
	{
		public get()
		{
			return this.GetInt("result");
		}
		public set(int value)
		{
			this.SetInt("result", value);
		}
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

	property JSONObject error
	{
		public get()
		{
			return view_as<JSONObject>(this.GetHandle("error"));
		}
		public set(JSONObject error)
		{
			this.SetHandle("error", error);
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
