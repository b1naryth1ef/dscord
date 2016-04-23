module types.guild;

import std.stdio,
       std.variant,
       std.conv;

import client,
       types.base,
       types.channel,
       types.user,
       types.permission,
       util.json;

alias GuildMap = ModelMap!(Snowflake, Guild);
alias RoleMap = ModelMap!(Snowflake, Role);

class Role : Model {
  Snowflake   id;
  wstring     name;
  uint        color;
  bool        hoist;
  short       position;
  Permission  permission;
  bool        managed;

  Guild  guild;

  this(Client client, JSONObject obj) {
    super(client, obj);
  }

  override void load(JSONObject obj) {
    // writeln(obj.dumps);
    this.id = obj.get!Snowflake("id");
    this.name = obj.get!wstring("name");
    this.hoist = obj.get!bool("hoist");
    this.position = obj.get!short("position");
    this.permission = obj.get!Permission("permissions");
    this.managed = obj.get!bool("managed");

    // Lets guard shitty data
    if (obj.get!int("color") < 0) {
      this.color = 0;
    } else {
      this.color = obj.get!uint("color");
    }

  }
}

/*
class Emoji {
  Snowflake id;
  string name;
  Role[] roles;
  bool require_colons;
  bool managed;
}
*/

class GuildMember : Model {
  User    user;
  string  joined_at;
  bool    mute;
  bool    deaf;

  // Role[]  roles;

  this(Client client, JSONObject obj) {
    super(client, obj);
  }

  override void load(JSONObject obj) {
    auto user = obj.get!JSONObject("user");
    this.user = client.state.users.getOrSet(
      user.get!Snowflake("id"), {
        return new User(this.client, user);
    });

    this.mute = obj.get!bool("mute");
    this.deaf = obj.get!bool("deaf");
  }
}

class Guild : Model {
  Snowflake  id;
  Snowflake  owner_id;
  Snowflake  afk_channel_id;
  Snowflake  embed_channel_id;
  wstring    name;
  string     icon;
  string     splash;
  string     region;
  uint       afk_timeout;
  bool       embed_enabled;
  ushort     verification_level;
  string[]   features;

  // Mappings
  ChannelMap  channels;
  RoleMap     roles;

  // Role[] roles;
  // Emoji[] emoji;
  // Channel[]  channels;

  this(Client client, JSONObject obj) {
    this.channels = new ChannelMap(
      &client.state.channels.get,
      &client.state.channels.set);

    this.roles = new RoleMap();

    super(client, obj);
  }

  override void load(JSONObject obj) {
    this.id = obj.get!Snowflake("id");

    if (obj.has("unavailable") && obj.get!bool("unavailable")) {
      return;
    }

    this.owner_id = obj.get!string("owner_id").to!Snowflake;
    this.name = obj.get!wstring("name");
    this.icon = obj.get!string("icon");
    this.region = obj.get!string("region");
    this.verification_level = obj.get!ushort("verification_level");
    this.afk_channel_id = obj.maybeGet!Snowflake("afk_channel_id", 0);
    this.splash = obj.maybeGet!string("splash", null);
    this.afk_timeout = obj.maybeGet!uint("afk_timeout", 0);

    if (obj.has("channels")) {
      foreach (Variant obj; obj.getRaw("channels")) {
        auto channel = new Channel(this.client, new JSONObject(variantToJSON(obj)));
        channel.guild_id = this.id;
        this.channels[channel.id] = channel;
      }
    }

    if (obj.has("roles")) {
      foreach (Variant obj; obj.getRaw("roles")) {
        auto role = new Role(this.client, new JSONObject(variantToJSON(obj)));
        role.guild = this;
        this.roles[role.id] = role;
      }
    }

    // this.features = obj.get!string[]("features");
  }
}
