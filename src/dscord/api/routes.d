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
  GATEWAY_GET = Route(HTTPMethod.GET, "/gateway"),

  CHANNELS_GET = Route(HTTPMethod.GET, "/channels/$CHANNEL"),
  CHANNELS_MODIFY = Route(HTTPMethod.PATCH, "/channels/$CHANNEL"),
  CHANNELS_DELETE = Route(HTTPMethod.DELETE, "/channels/$CHANNEL"),

  CHANNELS_MESSAGES_LIST = Route(HTTPMethod.GET, "/channels/$CHANNEL/messages"),
  CHANNELS_MESSAGES_GET = Route(HTTPMethod.GET, "/channels/$CHANNEL/messages/%s"),
  CHANNELS_MESSAGES_CREATE = Route(HTTPMethod.POST, "/channels/$CHANNEL/messages"),
  CHANNELS_MESSAGES_MODIFY = Route(HTTPMethod.PATCH, "/channels/$CHANNEL/messages/%s"),
  CHANNELS_MESSAGES_DELETE = Route(HTTPMethod.DELETE, "/channels/$CHANNEL/messages/%s"),
  CHANNELS_MESSAGES_DELETE_BULK = Route(HTTPMethod.POST, "/channels/$CHANNEL/messages/bulk_delete"),

  CHANNELS_PERMISSIONS_MODIFY = Route(HTTPMethod.PUT, "/channels/$CHANNEL/permissions/%s"),
  CHANNELS_PERMISSIONS_DELETE = Route(HTTPMethod.DELETE, "/channels/$CHANNEL/permissions/%s"),
  CHANNELS_INVITES_LIST = Route(HTTPMethod.GET, "/channels/$CHANNEL/invites"),
  CHANNELS_INVITES_CREATE = Route(HTTPMethod.POST, "/channels/$CHANNEL/invites"),

  CHANNELS_PINS_LIST = Route(HTTPMethod.GET, "/channels/$CHANNEL/pins"),
  CHANNELS_PINS_CREATE = Route(HTTPMethod.PUT, "/channels/$CHANNEL/pins/%s"),
  CHANNELS_PINS_DELETE = Route(HTTPMethod.DELETE, "/channels/$CHANNEL/pins/%s"),

  GUILDS_GET = Route(HTTPMethod.GET, "/guilds/$GUILD"),
  GUILDS_MODIFY = Route(HTTPMethod.PATCH, "/guilds/$GUILD"),
  GUILDS_DELETE = Route(HTTPMethod.DELETE, "/guilds/$GUILD"),
  GUILDS_CHANNELS_LIST = Route(HTTPMethod.GET, "/guilds/$GUILD/channels"),
  GUILDS_CHANNELS_CREATE = Route(HTTPMethod.POST, "/guilds/$GUILD/channels"),
  GUILDS_CHANNELS_MODIFY = Route(HTTPMethod.PATCH, "/guilds/$GUILD/channels"),
  GUILDS_MEMBERS_LIST = Route(HTTPMethod.GET, "/guilds/$GUILD/members"),
  GUILDS_MEMBERS_GET = Route(HTTPMethod.GET, "/guilds/$GUILD/members/%s"),
  GUILDS_MEMBERS_MODIFY = Route(HTTPMethod.PATCH, "/guilds/$GUILD/members/%s"),
  GUILDS_MEMBERS_KICK = Route(HTTPMethod.DELETE, "/guilds/$GUILD/members/%s"),
  GUILDS_BANS_LIST = Route(HTTPMethod.GET, "/guilds/$GUILD/bans"),
  GUILDS_BANS_CREATE = Route(HTTPMethod.PUT, "/guilds/$GUILD/bans/%s"),
  GUILDS_BANS_DELETE = Route(HTTPMethod.DELETE, "/guilds/$GUILD/bans/%s"),
  GUILDS_ROLES_LIST = Route(HTTPMethod.GET, "/guilds/$GUILD/roles"),
  GUILDS_ROLES_CREATE = Route(HTTPMethod.POST, "/guilds/$GUILD/roles"),
  GUILDS_ROLES_MODIFY_BATCH = Route(HTTPMethod.PATCH, "/guilds/$GUILD/roles"),
  GUILDS_ROLES_MODIFY = Route(HTTPMethod.PATCH, "/guilds/$GUILD/roles/%s"),
  GUILDS_ROLES_DELETE = Route(HTTPMethod.DELETE, "/guilds/$GUILD/roles/%s"),
  GUILDS_PRUNE_COUNT = Route(HTTPMethod.GET, "/guilds/$GUILD/prune"),
  GUILDS_PRUNE_BEGIN = Route(HTTPMethod.POST, "/guilds/$GUILD/prune"),
  GUILDS_VOICE_REGIONS_LIST = Route(HTTPMethod.GET, "/guilds/$GUILD/regions"),
  GUILDS_INVITES_LIST = Route(HTTPMethod.GET, "/guilds/$GUILD/invites"),
  GUILDS_INTEGRATIONS_LIST = Route(HTTPMethod.GET, "/guilds/$GUILD/integrations"),
  GUILDS_INTEGRATIONS_CREATE = Route(HTTPMethod.POST, "/guilds/$GUILD/integrations"),
  GUILDS_INTEGRATIONS_MODIFY = Route(HTTPMethod.PATCH, "/guilds/$GUILD/integrations/%s"),
  GUILDS_INTEGRATIONS_DELETE = Route(HTTPMethod.DELETE, "/guilds/$GUILD/integrations/%s"),
  GUILDS_INTEGRATIONS_SYNC = Route(HTTPMethod.POST, "/guilds/$GUILD/integrations/%s/sync"),
  GUILDS_EMBED_GET = Route(HTTPMethod.GET, "/guilds/$GUILD/embed"),
  GUILDS_EMBED_MODIFY = Route(HTTPMethod.PATCH, "/guilds/$GUILD/embed"),

  USERS_ME_GET = Route(HTTPMethod.GET, "/users/@me"),
  USERS_ME_PATCH = Route(HTTPMethod.PATCH, "/users/@me"),
  USERS_ME_GUILDS_LIST = Route(HTTPMethod.GET, "/users/@me/guilds"),
  USERS_ME_GUILDS_LEAVE = Route(HTTPMethod.DELETE, "/users/@me/guilds/$GUILD"),
  USERS_ME_DMS_LIST = Route(HTTPMethod.GET, "/users/@me/channels"),
  USERS_ME_DMS_CREATE = Route(HTTPMethod.POST, "/users/@me/channels"),
  USERS_ME_CONNECTIONS_LIST = Route(HTTPMethod.GET, "/users/@me/connections"),
  USERS_GET = Route(HTTPMethod.GET, "/users/%s"),

  INVITES_GET = Route(HTTPMethod.GET, "/invites/%s"),
  INVITES_DELETE = Route(HTTPMethod.DELETE, "/invites/%s"),
}

