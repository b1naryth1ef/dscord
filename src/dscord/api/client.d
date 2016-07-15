module dscord.api.client;

import std.array,
       std.variant,
       std.conv,
       std.algorithm.iteration,
       core.time;

import vibe.http.client,
       vibe.stream.operations;

import dscord.types.all,
       dscord.api.ratelimit,
       dscord.api.util;

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

  APIResponse requestJSON(HTTPMethod method, U url, VibeJSON obj) {
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

  User me() {
    auto res = this.requestJSON(HTTPMethod.GET, U("users")("@me"));
    res.ok();
    auto json = res.fastJSON();
    return new User(this.client, json);
  }

  Guild[] meGuilds() {
    auto res = this.requestJSON(HTTPMethod.GET, U("users")("@me")("guilds"));
    res.ok();
    auto json = res.fastJSON();
    return loadManyArray!Guild(this.client, json);
  }

  User user(Snowflake id) {
    auto res = this.requestJSON(HTTPMethod.GET, U("users")(id));
    res.ok();
    auto json = res.fastJSON();
    return new User(this.client, json);
  }

  Guild guild(Snowflake id) {
    auto res = this.requestJSON(HTTPMethod.GET, U("guilds")(id));
    res.ok();
    auto json = res.fastJSON();
    return new Guild(this.client, json);
  }

  Message sendMessage(Snowflake chan, string content, string nonce, bool tts) {
    VibeJSON payload = VibeJSON.emptyObject;
    payload["content"] = VibeJSON(content);
    payload["nonce"] = VibeJSON(nonce);
    payload["tts"] = VibeJSON(tts);

    // Send payload and return message object
    auto res = this.requestJSON(HTTPMethod.POST,
        U("channels")(chan)("messages").bucket("send-message"), payload);
    res.ok();
    auto json = res.fastJSON();
    return new Message(this.client, json);
  }

  Message editMessage(Snowflake chan, Snowflake msg, string content) {
    VibeJSON payload = VibeJSON.emptyObject;
    payload["content"] = content;

    auto res = this.requestJSON(HTTPMethod.PATCH,
        U("channels")(chan)("messages")(msg).bucket("edit-message"), payload);
    res.ok();

    auto json = res.fastJSON();
    return new Message(this.client, json);
  }

  void deleteMessage(Snowflake chan, Snowflake msg) {
    auto res = this.requestJSON(HTTPMethod.DELETE,
        U("channels")(chan)("messages")(msg).bucket("del-message"));
    res.ok();
  }

  void bulkDeleteMessages(Snowflake chan, Snowflake[] msgs) {
    VibeJSON payload = VibeJSON.emptyObject;
    payload["messages"] = VibeJSON(array(map!(a => VibeJSON(a))(msgs)));

    auto res = this.requestJSON(HTTPMethod.POST,
        U("channels")(chan)("messages")("bulk_delete").bucket("bulk-del-messages"),
        payload);
    res.ok();
  }

  string gateway() {
    auto res = this.requestJSON(HTTPMethod.GET, U("gateway?v=4"));
    res.ok();
    return res.vibeJSON["url"].to!string;
  }
}
