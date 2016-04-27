module dscord.types.guild;

import std.stdio,
       std.variant,
       std.conv;

import dscord.client,
       dscord.types.all,
       dscord.util.json;

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
    auto uobj = obj.get!JSONObject("user");
    if (this.client.state.users.has(uobj.get!Snowflake("id"))) {
      this.user = this.client.state.users.get(uobj.get!Snowflake("id"));
      this.user.load(uobj);
    } else {
      this.user = new User(this.client, uobj);
      this.client.state.users.set(this.user.id, this.user);
    }

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
  VoiceStateMap  voiceStates;
  ChannelMap     channels;
  RoleMap        roles;

  // Role[] roles;
  // Emoji[] emoji;
  // Channel[]  channels;

  this(Client client, JSONObject obj) {
    this.voiceStates = new VoiceStateMap;
    this.channels = new ChannelMap;
    this.roles = new RoleMap;
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

    if (obj.has("voice_states")) {
      foreach (Variant obj; obj.getRaw("voice_states")) {
        auto state = new VoiceState(this.client, new JSONObject(variantToJSON(obj)));
        state.guild_id = this.id;
        this.voiceStates[state.session_id] = state;
        // TODO: update the users/channels state?
      }
    }

    // this.features = obj.get!string[]("features");
  }
}
