module api.client;

import std.stdio,
       std.array,
       std.variant;

import vibe.http.client,
       vibe.stream.operations;

import util.json,
       util.errors,
       types.user,
       types.guild,
       types.base;

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
    if (100 < this.statusCode || this.statusCode < 400) {
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
      });

    return new APIResponse(res);
  }

  T spawn(T)(JSONObject obj) {
    T v = new T(obj);
    v.client = this;
    return v;
  }

  User me() {
    auto res = this.requestJSON(HTTPMethod.GET, URL("users")("@me"));
    res.ok();
    return this.spawn!User(res.json);
  }

  GuildMap meGuilds() {
    auto res = this.requestJSON(HTTPMethod.GET, URL("users")("@me")("guilds"));
    res.ok();

    GuildMap map;

    foreach (JSONObject guildObj; res.jsonArray) {
      auto g = this.spawn!Guild(guildObj);
      map[g.id] = g;
    }

    return map;
  }

  User user(Snowflake id) {
    auto res = this.requestJSON(HTTPMethod.GET, URL("users")(id));
    res.ok();
    return this.spawn!User(res.json);
  }

  Guild guild(Snowflake id) {
    auto res = this.requestJSON(HTTPMethod.GET, URL("guilds")(id));
    res.ok();
    return this.spawn!Guild(res.json);
  }
}
