module dscord.api.client;

import std.stdio,
       std.array,
       std.variant;

import vibe.http.client,
       vibe.stream.operations;

import dscord.types.all,
       dscord.util.errors;

class APIError : BaseError {
  this(int code, string msg) {
    super("[%s] %s", code, msg);
  }
}

struct URL {
  string url;

  this(string url) {
    if (url[0] != '/') {
      url = "/" ~ url;
    }

    this.url = url;
  }

  URL opCall(string url) {
    this.url ~= "/" ~ url;
    return this;
  }

  URL opCall(Snowflake s) {
    this.opCall(s.toString());
    return this;
  }
}

class APIResponse {
  private {
    HTTPClientResponse res;
  }

  this(HTTPClientResponse res) {
    this.res = res;
  }

  void ok() {
    if (100 < this.statusCode && this.statusCode < 400) {
      return;
    }

    throw new APIError(this.statusCode, this.content);
  }

  @property string contentType() {
    return this.res.contentType;
  }

  @property int statusCode() {
    return this.res.statusCode;
  }

  @property JSONObject json() {
    return new JSONObject(this.content);
  }

  @property JSONObject[] jsonArray() {
    return fromJSONArray(this.content);
  }

  @property string content() {
    return this.res.bodyReader.readAllUTF8();
  }
}

class APIClient {
  string baseURL = "https://discordapp.com/api/";
  string token;

  this(string token) {
    this.token = token;
  }

  APIResponse requestJSON(HTTPMethod method, URL url) {
    return requestJSON(method, url, "");
  }

  APIResponse requestJSON(HTTPMethod method, URL url, JSONObject data) {
    return requestJSON(method, url, data.dumps());
  }

  APIResponse requestJSON(HTTPMethod method, URL url, string data) {
    auto res = requestHTTP(this.baseURL ~ url.url,
      (scope req) {
        req.method = method;
        req.headers["Authorization"] = this.token;
        req.headers["Content-Type"] = "application/json";
        req.bodyWriter.write(data);
      });

    return new APIResponse(res);
  }

  JSONObject me() {
    auto res = this.requestJSON(HTTPMethod.GET, URL("users")("@me"));
    res.ok();
    return res.json;
  }

  JSONObject[] meGuilds() {
    auto res = this.requestJSON(HTTPMethod.GET, URL("users")("@me")("guilds"));
    res.ok();
    return res.jsonArray;
  }

  JSONObject user(Snowflake id) {
    auto res = this.requestJSON(HTTPMethod.GET, URL("users")(id));
    res.ok();
    return res.json;
  }

  JSONObject guild(Snowflake id) {
    auto res = this.requestJSON(HTTPMethod.GET, URL("guilds")(id));
    res.ok();
    return res.json;
  }

  JSONObject sendMessage(Snowflake chan, wstring content, string nonce, bool tts) {
    auto payload = new JSONObject()
      .set!wstring("content", content)
      .set!string("nonce", nonce)
      .set!bool("tts", tts);

    auto res = this.requestJSON(HTTPMethod.POST, URL("channels")(chan)("messages"), payload);
    res.ok();
    return res.json;
  }

  string gateway() {
    auto res = this.requestJSON(HTTPMethod.GET, URL("gateway"));
    res.ok();
    return res.json.get!string("url");
  }
}
