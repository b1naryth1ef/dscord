module dscord.api.routes;

import std.format;
import vibe.http.client;

struct CompiledRoute {
  Route route;
  string compiled;

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
    return CompiledRoute(this, format(this.url, args));
  }
}

enum Routes : Route {
  // /users/@me
  GET_ME = Route(HTTPMethod.GET, "/users/@me"),
  PATCH_ME = Route(HTTPMethod.PATCH, "/users/@me"),
  GET_ME_GUILDS = Route(HTTPMethod.GET, "/users/@me/guilds"),
  GET_ME_CHANNELS = Route(HTTPMethod.GET, "/users/@me/channels"),
  LEAVE_GUILD = Route(HTTPMethod.DELETE, "/users/@me/guilds/%s"),
  CREATE_DM = Route(HTTPMethod.POST, "/users/@me/channels"),

  GET_USER = Route(HTTPMethod.GET, "/users/%s"),
  GET_GUILD = Route(HTTPMethod.GET, "/guilds/%s"),
  DELETE_GUILD = Route(HTTPMethod.DELETE, "/guilds/%s"),
  PATCH_GUILD = Route(HTTPMethod.PATCH, "/guilds/%s"),
  GET_GUILD_CHANNELS = Route(HTTPMethod.GET, "/guilds/%s/channels"),

  DELETE_MEMBER = Route(HTTPMethod.DELETE, "/guilds/%s/members/%s"),
  SEND_MESSAGE = Route(HTTPMethod.POST, "/channels/%s/messages"),
  EDIT_MESSAGE = Route(HTTPMethod.PATCH, "/channels/%s/messages/%s"),
  DELETE_MESSAGE = Route(HTTPMethod.DELETE, "/channels/%s/messages/%s"),
  BULK_DELETE_MESSAGES = Route(HTTPMethod.POST, "/channels/%s/messages/bulk_delete"),

  GET_GATEWAY = Route(HTTPMethod.GET, "/gateway"),
}

