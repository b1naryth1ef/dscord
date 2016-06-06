module dscord.types.guild;

import std.stdio,
       std.variant,
       std.conv;

import dscord.client,
       dscord.types.all,
       dscord.util.json;

alias GuildMap = ModelMap!(Snowflake, Guild);
alias RoleMap = ModelMap!(Snowflake, Role);
alias GuildMemberMap = ModelMap!(Snowflake, GuildMember);
alias EmojiMap = ModelMap!(Snowflake, Emoji);

bool memberHasRoleWithin(RoleMap map, GuildMember mem) {
  foreach (ref role; map.values) {
    if (mem.hasRole(role)) return true;
  }
  return false;
}

class Role : IModel {
  mixin Model;

  Snowflake   id;
  Guild       guild;
  Permission  permission;

  string  name;
  uint    color;
  bool    hoist;
  short   position;
  bool    managed;
  bool    mentionable;


  this(Guild guild, ref JSON obj) {
    this.guild = guild;
    super(guild.client, obj);
  }

  override void load(ref JSON obj) {
    /*
    this.id = obj.get!Snowflake("id");
    this.name = obj.get!string("name");
    this.hoist = obj.get!bool("hoist");
    this.position = obj.get!short("position");
    this.permission = obj.get!Permission("permissions");
    this.managed = obj.get!bool("managed");
    this.mentionable = obj.get!bool("mentionable");

    // Lets guard shitty data
    if (obj.get!int("color") < 0) {
      this.color = 0;
    } else {
      this.color = obj.get!uint("color");
    }
    */
  }

  Snowflake getID() {
    return this.id;
  }
}

class Emoji : IModel {
  mixin Model;

  Snowflake  id;
  Guild      guild;
  string     name;
  Role[]     roles;
  bool       requireColons;
  bool       managed;

  this(Guild guild, ref JSON obj) {
    this.guild = guild;
    super(guild.client, obj);
  }

  override void load(ref JSON obj) {
    /*
    this.id = obj.get!Snowflake("id");
    this.name = obj.get!string("name");
    this.requireColons = obj.get!bool("require_colons");
    this.managed = obj.get!bool("managed");

    foreach (Variant v; obj.getRaw("roles")) {
      this.roles ~= this.guild.roles.get(v.coerce!Snowflake);
    }
    */
  }
}

class GuildMember : IModel {
  mixin Model;

  User    user;
  Guild   guild;
  string  nick;
  string  joinedAt;
  bool    mute;
  bool    deaf;

  RoleMap    roles;

  this(Guild guild, ref JSON obj) {
    this.guild = guild;
    super(client, obj);
  }

  override void init() {
    this.roles = new RoleMap;
  }

  override void load(ref JSON obj) {
    /*
    auto uobj = obj.get!JSONObject("user");
    if (this.client.state.users.has(uobj.get!Snowflake("id"))) {
      this.user = this.client.state.users.get(uobj.get!Snowflake("id"));
      this.user.load(uobj);
    } else {
      this.user = new User(this.client, uobj);
      this.client.state.users.set(this.user.id, this.user);
    }

    if (obj.has("guild_id")) {
      this.guild = this.client.state.guilds.get(obj.get!Snowflake("guild_id"));
    }

    if (obj.has("roles")) {
      foreach (Variant v; obj.getRaw("roles")) {
        auto roleID = v.coerce!Snowflake;
        auto role = this.guild.roles.get(roleID);
        if (!role) continue;
        this.roles[role.id] = role;
      }
    }

    this.nick = obj.maybeGet!string("nick", "");
    this.mute = obj.get!bool("mute");
    this.deaf = obj.get!bool("deaf");
    */
  }

  Snowflake getID() {
    return this.user.id;
  }

  bool hasRole(Role role) {
    return this.hasRole(role.id);
  }

  bool hasRole(Snowflake id) {
    return this.roles.has(id);
  }
}

class Guild : IModel {
  mixin Model;

  Snowflake  id;
  Snowflake  ownerID;
  Snowflake  afkChannelID;
  Snowflake  embedChannelID;
  string     name;
  string     icon;
  string     splash;
  string     region;
  uint       afkTimeout;
  bool       embedEnabled;
  ushort     verificationLevel;
  string[]   features;

  bool  unavailable;

  // Mappings
  GuildMemberMap  members;
  VoiceStateMap   voiceStates;
  ChannelMap      channels;
  RoleMap         roles;
  EmojiMap        emojis;

  override void init() {
    this.members = new GuildMemberMap;
    this.voiceStates = new VoiceStateMap;
    this.channels = new ChannelMap;
    this.roles = new RoleMap;
    this.emojis = new EmojiMap;
  }

  override void load(ref JSON obj) {
    obj.keySwitch!(
      "id", "unavailable", "owner_id", "name", "icon",
      "region", "verification_level", "afk_channel_id",
      "splash", "afk_timeout",
    )(
      { this.id = readSnowflake(obj); },
      { this.unavailable = obj.read!bool; },
      { this.ownerID = readSnowflake(obj); },
      { this.name = obj.read!string; },
      { this.icon = obj.read!string; },
      { this.region = obj.read!string; },
      { this.verificationLevel = obj.read!ushort; },
      { this.afkChannelID = readSnowflake(obj); },
      { this.splash = obj.read!string; },
      { this.afkTimeout = obj.read!uint; });


    /*
    if (obj.has("channels")) {
      foreach (Variant obj; obj.getRaw("channels")) {
        auto channel = new Channel(this.client, new JSONObject(variantToJSON(obj)));
        channel.guild_id = this.id;
        this.channels[channel.id] = channel;
      }
    }

    if (obj.has("roles")) {
      foreach (Variant obj; obj.getRaw("roles")) {
        auto role = new Role(this, new JSONObject(variantToJSON(obj)));
        this.roles[role.id] = role;
      }
    }

    if (obj.has("members")) {
      foreach (Variant obj; obj.getRaw("members")) {
        auto member = new GuildMember(this.client, this, new JSONObject(variantToJSON(obj)));
        this.members[member.user.id] = member;
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

    if (obj.has("emoji")) {
      foreach (Variant obj; obj.getRaw("emoji")) {
        auto emoji = new Emoji(this, new JSONObject(variantToJSON(obj)));
        this.emojis[emoji.id] = emoji;
      }
    }

    if (obj.has("features")) {
      foreach (Variant obj; obj.getRaw("features")) {
        this.features ~= obj.coerce!string;
      }
    }
    */
  }

  GuildMember getMember(User obj) {
    return this.getMember(obj.id);
  }

  GuildMember getMember(Snowflake id) {
    return this.members[id];
  }

  Snowflake getID() {
    return this.id;
  }
}
