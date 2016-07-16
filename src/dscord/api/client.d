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

  /* -- USERS -- */
  User me() {
    auto json = this.requestJSON(HTTPMethod.GET, U("users")("@me")).ok().fastJSON;
    return new User(this.client, json);
  }

  User user(Snowflake id) {
    auto json = this.requestJSON(HTTPMethod.GET, U("users")(id)).ok().fastJSON;
    return new User(this.client, json);
  }

  User meSettings(string username, string avatar) {
    auto json = this.requestJSON(HTTPMethod.PATCH, U("users")("@me")).ok().fastJSON;
    return new User(this.client, json);
  }

  Guild[] meGuilds() {
    auto json = this.requestJSON(HTTPMethod.GET, U("users")("@me")("guilds")).ok().fastJSON;
    return loadManyArray!Guild(this.client, json);
  }

  void meGuildLeave(Snowflake id) {
    this.requestJSON(HTTPMethod.DELETE, U("users")("@me")("guilds")(id)).ok();
  }

  Channel[] meDMChannels() {
    auto json = this.requestJSON(HTTPMethod.GET, U("users")("@me")("channels")).ok().fastJSON;
    return loadManyArray!Channel(this.client, json);
  }

  Channel meDMCreate(Snowflake recipientID) {
    VibeJSON payload = VibeJSON.emptyObject;
    payload["recipient_id"] = VibeJSON(recipientID);
    auto json = this.requestJSON(HTTPMethod.POST,
        U("users")("@me")("channels"), payload).ok().fastJSON;
    return new Channel(this.client, json);
  }

  /* -- GUILDS -- */
  Guild guild(Snowflake id) {
    auto json = this.requestJSON(HTTPMethod.GET, U("guilds")(id)).ok().fastJSON;
    return new Guild(this.client, json);
  }

  void guildDelete(Snowflake id) {
    this.requestJSON(HTTPMethod.DELETE, U("guilds")(id)).ok();
  }

  Channel[] guildChannels(Snowflake id) {
    auto json = this.requestJSON(HTTPMethod.GET, U("guilds")(id)("channels")).ok().fastJSON;
    return loadManyArray!Channel(this.client, json);
  }

  /*
  Channel guildChannelCreate(Snowflake id, string name, string type, int bitrate = -1, int userLimit = -1) {
    VibeJSON payload = VibeJSON.emptyObject;
    payload["name"] = VibeJSON(id);
    payload["type"] = VibeJSON(type);
    if (bitrate > -1) payload["bitrate"] = VibeJSON(bitrate);
    if (userLimit > -1) payload["user_limit"] = VibeJSON(userLimit);
  }
  */

  /* -- CHANNELS -- */
  Message sendMessage(Snowflake chan, string content, string nonce, bool tts) {
    VibeJSON payload = VibeJSON.emptyObject;
    payload["content"] = VibeJSON(content);
    payload["nonce"] = VibeJSON(nonce);
    payload["tts"] = VibeJSON(tts);

    // Send payload and return message object
    auto json = this.requestJSON(HTTPMethod.POST,
        U("channels")(chan)("messages").bucket("send-message"), payload).ok().fastJSON;
    return new Message(this.client, json);
  }

  Message editMessage(Snowflake chan, Snowflake msg, string content) {
    VibeJSON payload = VibeJSON.emptyObject;
    payload["content"] = content;

    auto json = this.requestJSON(HTTPMethod.PATCH,
        U("channels")(chan)("messages")(msg).bucket("edit-message"), payload).ok().fastJSON;
    return new Message(this.client, json);
  }

  void deleteMessage(Snowflake chan, Snowflake msg) {
    this.requestJSON(HTTPMethod.DELETE,
        U("channels")(chan)("messages")(msg).bucket("del-message")).ok().fastJSON;
  }

  void bulkDeleteMessages(Snowflake chan, Snowflake[] msgs) {
    VibeJSON payload = VibeJSON.emptyObject;
    payload["messages"] = VibeJSON(array(map!((m) => VibeJSON(m))(msgs)));

    this.requestJSON(HTTPMethod.POST,
        U("channels")(chan)("messages")("bulk_delete").bucket("bulk-del-messages"),
        payload).ok();
  }

  string gateway() {
    return this.requestJSON(HTTPMethod.GET, U("gateway?v=4")).ok().vibeJSON["url"].to!string;
  }
}
