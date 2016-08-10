/**
  Base abstractions for dealing with the Discord REST API
*/

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


/**
  APIClient is the base abstraction for interacting with the Discord API.
*/
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

  /**
    Makes a HTTP request to the API (with empty body), returning an APIResponse

    Params:
      method = HTTPMethod to use when requesting
      url = URL to make the request on
  */
  APIResponse requestJSON(HTTPMethod method, U url) {
    return requestJSON(method, url, "");
  }

  /**
    Makes a HTTP request to the API (with JSON body), returning an APIResponse

    Params:
      method = HTTPMethod to use when requesting
      url = URL to make the request on
      obj = VibeJSON object for the body
  */
  APIResponse requestJSON(HTTPMethod method, U url, VibeJSON obj) {
    return requestJSON(method, url, obj.toString);
  }

  /**
    Makes a HTTP request to the API (with string body), returning an APIResponse

    Params:
      method = HTTPMethod to use when requesting
      url = URL to make the request on
      data = string contents of the body
      timeout = HTTP timeout (default is 15 seconds)
  */
  APIResponse requestJSON(HTTPMethod method, U url, string data,
      Duration timeout=15.seconds) {

    // Grab the rate limit lock
    if (!this.ratelimit.wait(url.getBucket(), timeout)) {
      throw new APIError(-1, "Request expired before rate-limit");
    }

    this.log.tracef("API Request: [%s] %s: %s", method, this.baseURL ~ url.value, data);
    auto res = new APIResponse(requestHTTP(this.baseURL ~ url.value,
      (scope req) {
        req.method = method;
        req.headers["Authorization"] = "Bot " ~ this.token;
        req.headers["Content-Type"] = "application/json";
        req.bodyWriter.write(data);
    }));

    // If we got a 429, cooldown and recurse
    if (res.statusCode == 429) {
      this.ratelimit.cooldown(url.getBucket(),
          dur!"seconds"(res.header("Retry-After", "1").to!int));
      return this.requestJSON(method, url, data, timeout);
    // If we got a 502, just retry immedietly
    } else if (res.statusCode == 502) {
      return this.requestJSON(method, url, data, timeout);
    }

    return res;
  }

  /**
    Return the User object for the currently logged in user.
  */
  User me() {
    auto json = this.requestJSON(HTTPMethod.GET, U("users")("@me")).ok().fastJSON;
    return new User(this.client, json);
  }

  /**
    Return a User object for a Snowflake ID.
  */
  User user(Snowflake id) {
    auto json = this.requestJSON(HTTPMethod.GET, U("users")(id)).ok().fastJSON;
    return new User(this.client, json);
  }

  /**
    Modifies the current users settings. Returns a User object.
  */
  User meSettings(string username, string avatar) {
    auto json = this.requestJSON(HTTPMethod.PATCH, U("users")("@me")).ok().fastJSON;
    return new User(this.client, json);
  }

  /**
    Returns a list of Guild objects for the current user.
  */
  Guild[] meGuilds() {
    auto json = this.requestJSON(HTTPMethod.GET, U("users")("@me")("guilds")).ok().fastJSON;
    return loadManyArray!Guild(this.client, json);
  }

  /**
    Leaves a guild.
  */
  void meGuildLeave(Snowflake id) {
    this.requestJSON(HTTPMethod.DELETE, U("users")("@me")("guilds")(id)).ok();
  }

  /**
    Returns a list of Channel objects for the current user.
  */
  Channel[] meDMChannels() {
    auto json = this.requestJSON(HTTPMethod.GET, U("users")("@me")("channels")).ok().fastJSON;
    return loadManyArray!Channel(this.client, json);
  }

  /**
    Creates a new DM for a recipient (user) ID. Returns a Channel object.
  */
  Channel meDMCreate(Snowflake recipientID) {
    VibeJSON payload = VibeJSON.emptyObject;
    payload["recipient_id"] = VibeJSON(recipientID);
    auto json = this.requestJSON(HTTPMethod.POST,
        U("users")("@me")("channels"), payload).ok().fastJSON;
    return new Channel(this.client, json);
  }

  /**
    Returns a Guild for a Snowflake ID.
  */
  Guild guild(Snowflake id) {
    auto json = this.requestJSON(HTTPMethod.GET, U("guilds")(id)).ok().fastJSON;
    return new Guild(this.client, json);
  }

  /**
    Deletes a guild.
  */
  void guildDelete(Snowflake id) {
    this.requestJSON(HTTPMethod.DELETE, U("guilds")(id)).ok();
  }

  /**
    Returns a list of channels for a Guild.
  */
  Channel[] guildChannels(Snowflake id) {
    auto json = this.requestJSON(HTTPMethod.GET, U("guilds")(id)("channels")).ok().fastJSON;
    return loadManyArray!Channel(this.client, json);
  }

  /**
    Removes (kicks) a user from a Guild.
  */
  void guildRemoveMember(Snowflake id, Snowflake user) {
    this.requestJSON(HTTPMethod.DELETE, U("guilds")(id)("members")(user)).ok();
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

  /**
    Sends a message to a channel.
  */
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

  /**
    Edits a messages contents.
  */
  Message editMessage(Snowflake chan, Snowflake msg, string content) {
    VibeJSON payload = VibeJSON.emptyObject;
    payload["content"] = content;

    auto json = this.requestJSON(HTTPMethod.PATCH,
        U("channels")(chan)("messages")(msg).bucket("edit-message"), payload).ok().fastJSON;
    return new Message(this.client, json);
  }

  /**
    Deletes a message.
  */
  void deleteMessage(Snowflake chan, Snowflake msg) {
    this.requestJSON(HTTPMethod.DELETE,
        U("channels")(chan)("messages")(msg).bucket("del-message")).ok().fastJSON;
  }

  /**
    Deletes messages in bulk.
  */
  void bulkDeleteMessages(Snowflake chan, Snowflake[] msgs) {
    VibeJSON payload = VibeJSON.emptyObject;
    payload["messages"] = VibeJSON(array(map!((m) => VibeJSON(m))(msgs)));

    this.requestJSON(HTTPMethod.POST,
        U("channels")(chan)("messages")("bulk_delete").bucket("bulk-del-messages"),
        payload).ok();
  }

  /**
    Returns a valid Gateway Websocket URL
  */
  string gateway() {
    return this.requestJSON(HTTPMethod.GET, U("gateway")).ok().vibeJSON["url"].to!string;
  }
}
