/**
  Base abstractions for dealing with the Discord REST API
*/

module dscord.api.client;

import std.conv,
       std.array,
       std.format,
       std.variant,
       std.algorithm.iteration,
       core.time;

import vibe.core.core,
       vibe.http.client,
       vibe.stream.operations;

import dscord.api,
       dscord.info,
       dscord.types,
       dscord.api.routes,
       dscord.api.ratelimit;

/**
  APIClient is the base abstraction for interacting with the Discord API.
*/
class APIClient {
  string       baseURL = "https://discordapp.com/api";
  string       userAgent;
  string       token;
  RateLimiter  ratelimit;
  Client       client;
  Logger       log;

  this(Client client) {
    this.client = client;
    this.log = client.log;
    this.token = client.token;
    this.ratelimit = new RateLimiter;

    this.userAgent = format("DiscordBot (%s %s) %s",
        GITHUB_REPO, VERSION,
        "vibe.d/" ~ vibeVersionString);
  }

  /**
    Makes a HTTP request to the API (with empty body), returning an APIResponse

    Params:
      route = route to make the request for
  */
  APIResponse requestJSON(CompiledRoute route) {
    return requestJSON(route, "");
  }

  /**
    Makes a HTTP request to the API (with JSON body), returning an APIResponse

    Params:
      route = route to make the request for
      obj = VibeJSON object for the JSON body
  */
  APIResponse requestJSON(CompiledRoute route, VibeJSON obj) {
    return requestJSON(route, obj.toString);
  }

  /**
    Makes a HTTP request to the API (with string body), returning an APIResponse

    Params:
      route = route to make the request for
      content = body content as a string
  */
  APIResponse requestJSON(CompiledRoute route, string content) {
    // High timeout, we should never hit this
    Duration timeout = 15.seconds;

    // Check the rate limit for the route (this may sleep)
    if (!this.ratelimit.check(route.bucket, timeout)) {
      throw new APIError(-1, "Request expired before rate-limit cooldown.");
    }

    auto res = new APIResponse(requestHTTP(this.baseURL ~ route.compiled,
      (scope req) {
        req.method = route.method;
        req.headers["Authorization"] = "Bot " ~ this.token;
        req.headers["Content-Type"] = "application/json";
        req.headers["User-Agent"] = this.userAgent;
        req.bodyWriter.write(content);
    }));
    this.log.tracef("[%s] [%s] %s: \n\t%s", route.method, res.statusCode, this.baseURL ~ route.compiled, content);

    // If we returned ratelimit headers, update our ratelimit states
    if (res.header("X-RateLimit-Limit", "") != "") {
      this.ratelimit.update(route.bucket,
            res.header("X-RateLimit-Remaining"),
            res.header("X-RateLimit-Reset"),
            res.header("Retry-After", ""));
    }

    // We ideally should never hit 429s, but in the case we do just retry the
    /// request fully.
    if (res.statusCode == 429) {
      this.log.error("Request returned 429. This should not happen.");
      return this.requestJSON(route, content);
    // If we got a 502, just retry after a random backoff
    } else if (res.statusCode == 502) {
      sleep(randomBackoff());
      return this.requestJSON(route, content);
    }

    return res;
  }

  /**
    Return the User object for the currently logged in user.
  */
  User me() {
    auto json = this.requestJSON(Routes.GET_ME()).ok().fastJSON;
    return new User(this.client, json);
  }

  /**
    Return a User object for a Snowflake ID.
  */
  User user(Snowflake id) {
    auto json = this.requestJSON(Routes.GET_USER(id)).fastJSON;
    return new User(this.client, json);
  }

  /**
    Modifies the current users settings. Returns a User object.
  */
  User meSettings(string username, string avatar) {
    VibeJSON data = VibeJSON(["username": VibeJSON(username), "avatar": VibeJSON(avatar)]);
    auto json = this.requestJSON(Routes.PATCH_ME(), data).fastJSON;
    return new User(this.client, json);
  }

  /**
    Returns a list of Guild objects for the current user.
  */
  Guild[] meGuilds() {
    auto json = this.requestJSON(Routes.GET_ME_GUILDS()).ok().fastJSON;
    return loadManyArray!Guild(this.client, json);
  }

  /**
    Leaves a guild.
  */
  void meGuildLeave(Snowflake id) {
    this.requestJSON(Routes.LEAVE_GUILD(id)).ok();
  }

  /**
    Returns a list of Channel objects for the current user.
  */
  Channel[] meDMChannels() {
    auto json = this.requestJSON(Routes.GET_ME_CHANNELS()).ok().fastJSON;
    return loadManyArray!Channel(this.client, json);
  }

  /**
    Creates a new DM for a recipient (user) ID. Returns a Channel object.
  */
  Channel meDMCreate(Snowflake recipientID) {
    VibeJSON payload = VibeJSON(["recipient_id": VibeJSON(recipientID)]);
    auto json = this.requestJSON(Routes.CREATE_DM()).ok().fastJSON;
    return new Channel(this.client, json);
  }

  /**
    Returns a Guild for a Snowflake ID.
  */
  Guild guild(Snowflake id) {
    auto json = this.requestJSON(Routes.GET_GUILD(id)).ok().fastJSON;
    return new Guild(this.client, json);
  }

  /**
    Modifies a guild.
  */
  Guild guildModify(Snowflake id, VibeJSON obj) {
    auto json = this.requestJSON(Routes.PATCH_GUILD(id), obj).fastJSON;
    return new Guild(this.client, json);
  }

  /**
    Deletes a guild.
  */
  void guildDelete(Snowflake id) {
    this.requestJSON(Routes.DELETE_GUILD(id)).ok();
  }

  /**
    Returns a list of channels for a Guild.
  */
  Channel[] guildChannels(Snowflake id) {
    auto json = this.requestJSON(Routes.GET_GUILD_CHANNELS(id)).ok().fastJSON;
    return loadManyArray!Channel(this.client, json);
  }

  /**
    Removes (kicks) a user from a Guild.
  */
  void guildRemoveMember(Snowflake id, Snowflake user) {
    this.requestJSON(Routes.DELETE_MEMBER(id, user)).ok();
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
  Message sendMessage(Snowflake chan, inout(string) content, string nonce, bool tts) {
    VibeJSON payload = VibeJSON([
      "content": VibeJSON(content),
      "nonce": VibeJSON(nonce),
      "tts": VibeJSON(tts),
    ]);

    // Send payload and return message object
    auto json = this.requestJSON(Routes.SEND_MESSAGE(chan), payload).ok().fastJSON;
    return new Message(this.client, json);
  }

  /**
    Edits a messages contents.
  */
  Message editMessage(Snowflake chan, Snowflake msg, inout(string) content) {
    VibeJSON payload = VibeJSON(["content": VibeJSON(content)]);

    auto json = this.requestJSON(Routes.EDIT_MESSAGE(chan, msg), payload).ok().fastJSON;
    return new Message(this.client, json);
  }

  /**
    Deletes a message.
  */
  void deleteMessage(Snowflake chan, Snowflake msg) {
    this.requestJSON(Routes.DELETE_MESSAGE(chan, msg)).ok();
  }

  /**
    Deletes messages in bulk.
  */
  void bulkDeleteMessages(Snowflake chan, Snowflake[] msgs) {
    VibeJSON payload = VibeJSON(["messages": VibeJSON(array(map!((m) => VibeJSON(m))(msgs)))]);
    this.requestJSON(Routes.BULK_DELETE_MESSAGES(chan)).ok();
  }

  /**
    Returns a valid Gateway Websocket URL
  */
  string gateway() {
    return this.requestJSON(Routes.GET_GATEWAY()).ok().vibeJSON["url"].to!string;
  }
}
