module dscord.api.client;

import std.stdio,
       std.array,
       std.variant,
       std.conv,
       core.time;

import vibe.http.client,
       vibe.stream.operations;

import dscord.types.all,
       dscord.api.ratelimit,
       dscord.util.errors;

class APIError : BaseError {
  this(int code, string msg) {
    super("[%s] %s", code, msg);
  }
}

// Simple URL constructor to help building routes
struct U {
  string  _bucket;
  string  value;

  this(string url) {
    if (url[0] != '/') {
      url = "/" ~ url;
    }

    this.value = url;
  }

  U opCall(string url) {
    this.value ~= "/" ~ url;
    return this;
  }

  U opCall(Snowflake s) {
    this.opCall(s.toString());
    return this;
  }

  U bucket(string bucket) {
    this._bucket = bucket;
    return this;
  }
}

// Wrapper for HTTP API Responses
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

  string header(string name, string def="") {
    if (name in this.res.headers) {
      return this.res.headers[name];
    }

    return def;
  }
}

// Actual API client used for making requests
class APIClient {
  string       baseURL = "https://discordapp.com/api/";
  string       token;
  RateLimiter  ratelimit;

  this(string token) {
    this.token = token;
    this.ratelimit = new RateLimiter;
  }

  APIResponse requestJSON(HTTPMethod method, U url) {
    return requestJSON(method, url, "");
  }

  APIResponse requestJSON(HTTPMethod method, U url, JSONObject data) {
    return requestJSON(method, url, data.dumps());
  }

  APIResponse requestJSON(HTTPMethod method, U url, string data,
      Duration timeout=15.seconds) {

    // Grab the rate limit lock
    if (!this.ratelimit.wait(url._bucket, timeout)) {
      throw new APIError(-1, "Request expired before rate-limit");
    }

    debug writefln("R: %s %s %s", method, this.baseURL ~ url.value, data);
    auto res = new APIResponse(requestHTTP(this.baseURL ~ url.value,
      (scope req) {
        req.method = method;
        req.headers["Authorization"] = this.token;
        req.headers["Content-Type"] = "application/json";
        req.bodyWriter.write(data);
    }));

    // If we got a 429, cooldown and recurse
    if (res.statusCode == 429) {
      this.ratelimit.cooldown(url._bucket,
          dur!"seconds"(res.header("Retry-After", "1").to!int));
      return this.requestJSON(method, url, data, timeout);
    }

    return res;
  }

  JSONObject me() {
    auto res = this.requestJSON(HTTPMethod.GET, U("users")("@me"));
    res.ok();
    return res.json;
  }

  JSONObject[] meGuilds() {
    auto res = this.requestJSON(HTTPMethod.GET, U("users")("@me")("guilds"));
    res.ok();
    return res.jsonArray;
  }

  JSONObject user(Snowflake id) {
    auto res = this.requestJSON(HTTPMethod.GET, U("users")(id));
    res.ok();
    return res.json;
  }

  JSONObject guild(Snowflake id) {
    auto res = this.requestJSON(HTTPMethod.GET, U("guilds")(id));
    res.ok();
    return res.json;
  }

  JSONObject sendMessage(Snowflake chan, string content, string nonce, bool tts) {
    auto payload = new JSONObject()
      .set!string("content", content)
      .set!string("nonce", nonce)
      .set!bool("tts", tts);

    auto res = this.requestJSON(HTTPMethod.POST,
        U("channels")(chan)("messages").bucket("send-message"), payload);
    res.ok();
    return res.json;
  }

  string gateway() {
    auto res = this.requestJSON(HTTPMethod.GET, U("gateway?v=4"));
    res.ok();
    return res.json.get!string("url");
  }
}
