module dscord.api.client;

import std.array,
       std.variant,
       std.conv,
       core.time;

import vibe.http.client,
       vibe.stream.operations;

import dscord.types.all,
       dscord.api.ratelimit,
       dscord.api.util;

// Actual API client used for making requests
class APIClient {
  string       baseURL = "https://discordapp.com/api";
  string       token;
  RateLimiter  ratelimit;
  Client       client;
  Logger       log;

  this(Client client) {
    this.client = client;
    this.log = client.log;
    this.token = client.token;
    this.ratelimit = new RateLimiter;
  }

  APIResponse requestJSON(HTTPMethod method, U url) {
    return requestJSON(method, url, "");
  }

  APIResponse requestJSON(HTTPMethod method, U url, JSONValue obj) {
    return requestJSON(method, url, obj.toString);
  }

  APIResponse requestJSON(HTTPMethod method, U url, string data,
      Duration timeout=15.seconds) {

    // Grab the rate limit lock
    if (!this.ratelimit.wait(url._bucket, timeout)) {
      throw new APIError(-1, "Request expired before rate-limit");
    }

    this.log.tracef("API Request: [%s] %s: %s", method, this.baseURL ~ url.value, data);
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
    // If we got a 502, just retry immedietly
    } else if (res.statusCode == 502) {
      return this.requestJSON(method, url, data, timeout);
    }

    return res;
  }

  JSONValue me() {
    auto res = this.requestJSON(HTTPMethod.GET, U("users")("@me"));
    res.ok();
    return res.json;
  }

  JSONValue meGuilds() {
    auto res = this.requestJSON(HTTPMethod.GET, U("users")("@me")("guilds"));
    res.ok();
    return res.json;
  }

  JSONValue user(Snowflake id) {
    auto res = this.requestJSON(HTTPMethod.GET, U("users")(id));
    res.ok();
    return res.json;
  }

  JSONValue guild(Snowflake id) {
    auto res = this.requestJSON(HTTPMethod.GET, U("guilds")(id));
    res.ok();
    return res.json;
  }

  JSONValue sendMessage(Snowflake chan, string content, string nonce, bool tts) {
    JSONValue payload;
    payload["content"] = JSONValue(content);
    payload["nonce"] = JSONValue(nonce);
    payload["tts"] = JSONValue(tts);
    auto res = this.requestJSON(HTTPMethod.POST,
        U("channels")(chan)("messages").bucket("send-message"), payload);
    res.ok();
    return res.json;
  }

  string gateway() {
    auto res = this.requestJSON(HTTPMethod.GET, U("gateway?v=4"));
    res.ok();
    return res.json["url"].str();
  }
}
