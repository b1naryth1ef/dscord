module dscord.api.routes;

import std.format,
       std.array,
       std.typecons,
       std.algorithm.searching;

import vibe.http.client;

private string safeFormat(T...)(inout(string) fmt, T args) {
  import std.format : formattedWrite, FormatException;
  import std.array : appender;
  auto w = appender!(immutable(char)[]);
  auto n = formattedWrite(w, fmt, args);
  return w.data;
}

private string replaceMajorVariables(string data) {
  return data.replace("$GUILD", "%s").replace("$CHANNEL", "%s");
}

alias Bucket = Tuple!(HTTPMethod, string);

struct CompiledRoute {
  Route route;
  string key;
  string compiled;

  @property Bucket bucket() {
    return tuple(this.route.method, this.key);
  }

  @property HTTPMethod method() {
    return this.route.method;
  }
}

struct Route {
  HTTPMethod method;
  string url;

  this(HTTPMethod method, string url) {
    this.method = method;
    this.url = url;
  }

  CompiledRoute opCall(T...)(T args) {
    // First generate the keyed route
    string key = safeFormat(replaceMajorVariables(this.url.replace("%s", "")), args);

    // Then generate the actual request url
    string url = format(replaceMajorVariables(this.url), args);

    return CompiledRoute(this, key, url);
  }
}

enum Routes : Route {
  // /users/@me
  GET_ME = Route(HTTPMethod.GET, "/users/@me"),
  PATCH_ME = Route(HTTPMethod.PATCH, "/users/@me"),
  GET_ME_GUILDS = Route(HTTPMethod.GET, "/users/@me/guilds"),
  GET_ME_CHANNELS = Route(HTTPMethod.GET, "/users/@me/channels"),
  LEAVE_GUILD = Route(HTTPMethod.DELETE, "/users/@me/guilds/$GUILD"),
  CREATE_DM = Route(HTTPMethod.POST, "/users/@me/channels"),

  GET_USER = Route(HTTPMethod.GET, "/users/%s"),
  GET_GUILD = Route(HTTPMethod.GET, "/guilds/$GUILD"),
  DELETE_GUILD = Route(HTTPMethod.DELETE, "/guilds/$GUILD"),
  PATCH_GUILD = Route(HTTPMethod.PATCH, "/guilds/$GUILD"),
  GET_GUILD_CHANNELS = Route(HTTPMethod.GET, "/guilds/$GUILD/channels"),

  DELETE_MEMBER = Route(HTTPMethod.DELETE, "/guilds/$GUILD/members/%s"),
  SEND_MESSAGE = Route(HTTPMethod.POST, "/channels/$CHANNEL/messages"),
  EDIT_MESSAGE = Route(HTTPMethod.PATCH, "/channels/$CHANNEL/messages/%s"),
  DELETE_MESSAGE = Route(HTTPMethod.DELETE, "/channels/$CHANNEL/messages/%s"),
  BULK_DELETE_MESSAGES = Route(HTTPMethod.POST, "/channels/$CHANNEL/messages/bulk_delete"),

  GET_GATEWAY = Route(HTTPMethod.GET, "/gateway"),
}

