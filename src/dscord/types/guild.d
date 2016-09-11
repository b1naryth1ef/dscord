module dscord.types.guild;

import std.stdio,
       std.algorithm,
       std.array,
       std.conv;

import dscord.types,
       dscord.client,
       dscord.gateway;

alias GuildMap = ModelMap!(Snowflake, Guild);
alias RoleMap = ModelMap!(Snowflake, Role);
alias GuildMemberMap = ModelMap!(Snowflake, GuildMember);
alias EmojiMap = ModelMap!(Snowflake, Emoji);

class Role : IModel {
  mixin Model;

  Snowflake   id;
  Guild       guild;
  Permission  permissions;

  string  name;
  uint    color;
  bool    hoist;
  short   position;
  bool    managed;
  bool    mentionable;

  this(Client client, ref JSON obj) {
    super(client, obj);
  }

  this(Guild guild, ref JSON obj) {
    this.guild = guild;
    super(guild.client, obj);
  }

  override void load(ref JSON obj) {
    obj.keySwitch!(
      "id", "name", "hoist", "position", "permissions",
      "managed", "mentionable", "color"
    )(
      { this.id = readSnowflake(obj); },
      { this.name = obj.read!string; },
      { this.hoist = obj.read!bool; },
      { this.position = obj.read!short; },
      { this.permissions = Permission(obj.read!uint); },
      { this.managed = obj.read!bool; },
      { this.mentionable = obj.read!bool; },
      { this.color = obj.read!uint; },
    );
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
  bool       requireColons;
  bool       managed;

  Snowflake[]  roles;

  this(Client client, ref JSON obj) {
    super(client, obj);
  }

  this(Guild guild, ref JSON obj) {
    this.guild = guild;
    super(guild.client, obj);
  }

  override void load(ref JSON obj) {
    obj.keySwitch!(
      "id", "name", "require_colons", "managed", "roles"
    )(
      { this.id = readSnowflake(obj); },
      { this.name = obj.read!string; },
      { this.requireColons = obj.read!bool; },
      { this.managed = obj.read!bool; },
      { this.roles = obj.read!(string[]).map!((c) => c.to!Snowflake).array; },
    );
  }

  bool matches(string usage) {
    if (this.name == ":" ~ usage ~ ":") {
      return true;
    } else if (this.requireColons) {
      return false;
    } else {
      return this.name == usage;
    }
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

  private Snowflake[]  _roles;

  this(Client client, ref JSON obj) {
    super(client, obj);
  }

  this(Guild guild, ref JSON obj) {
    this.guild = guild;
    super(guild.client, obj);
  }

  void fromUpdate(GuildMemberUpdate update) {
    this.user = update.user;
    this._roles = update.roles;
  }

  override void load(ref JSON obj) {
    obj.keySwitch!(
      "user", "guild_id", "roles", "nick", "mute", "deaf", "joined_at"
    )(
      { this.user = new User(this.client, obj); },
      { this.guild = this.client.state.guilds.get(readSnowflake(obj)); },
      { this._roles = obj.read!(string[]).map!((c) => c.to!Snowflake).array; },
      { this.nick = obj.read!string; },
      { this.mute = obj.read!bool; },
      { this.deaf = obj.read!bool; },
      { this.joinedAt = obj.read!string; },
    );
  }

  override string toString() {
    return format("<GuildMember %s#%s (%s / %s)>",
      this.user.username,
      this.user.discriminator,
      this.id,
      this.guild.id);
  }

  @property Snowflake[] roles() {
    return this._roles ~ [this.guild.id];
  }

  @property Snowflake id() {
    return this.user.id;
  }

  bool hasRole(Role role) {
    return this.hasRole(role.id);
  }

  bool hasRole(Snowflake id) {
    return this.roles.canFind(id);
  }
}

class Guild : IModel, IPermissible {
  mixin Model;
  mixin Permissible;

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
  ushort     mfaLevel;
  string[]   features;

  bool  unavailable;

  // Mappings
  GuildMemberMap  members;
  VoiceStateMap   voiceStates;
  ChannelMap      channels;
  RoleMap         roles;
  EmojiMap        emojis;

  void fromUpdate(GuildUpdate update) {
    auto guild = update.guild;
    assert(this.id == guild.id, "Cannot update from mismatched GuildUpdate");

    this.ownerID = guild.ownerID;
    this.afkChannelID = guild.afkChannelID;
    this.embedChannelID = guild.embedChannelID;
    this.name = guild.name;
    this.icon = guild.icon;
    this.splash = guild.splash;
    this.afkTimeout = guild.afkTimeout;
    this.embedEnabled = guild.embedEnabled;
    this.verificationLevel = guild.verificationLevel;
    this.mfaLevel = guild.mfaLevel;
    this.features = guild.features;
  }

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
      "splash", "afk_timeout", "channels", "roles", "members",
      "voice_states", "emojis", "features", "mfa_level",
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
      { this.afkTimeout = obj.read!uint; },
      {
        loadManyComplex!(Guild, Channel)(this, obj, (c) { this.channels[c.id] = c; });
      },
      {
        loadManyComplex!(Guild, Role)(this, obj, (r) { this.roles[r.id] = r; });
      },
      {
        loadManyComplex!(Guild, GuildMember)(this, obj, (m) { this.members[m.user.id] = m; });
      },
      {
        loadMany!VoiceState(this.client, obj, (v) { this.voiceStates[v.sessionID] = v; });
      },
      {
        loadManyComplex!(Guild, Emoji)(this, obj, (e) { this.emojis[e.id] = e; });
      },
      { this.features = obj.read!(string[]); },
      { this.mfaLevel = obj.read!ushort; },
    );
  }

  override string toString() {
    return format("<Guild %s (%s)>", this.name, this.id);
  }

  /// Returns a GuildMember for a given user object
  GuildMember getMember(User obj) {
    return this.getMember(obj.id);
  }

  /// Returns a GuildMember for a given user/member id
  GuildMember getMember(Snowflake id) {
    return this.members[id];
  }

  /// Kick a given GuildMember
  void kick(GuildMember member) {
    this.kick(member.user);
  }

  /// Kick a given User
  void kick(User user) {
    this.client.api.guildRemoveMember(this.id, user.id);
  }

  /// Default role for this Guild
  @property Role defaultRole() {
    return this.roles.pick((r) {
      return r.id == this.id;
    });
  }

  /// Default channel for this Guild
  @property Channel defaultChannel() {
    return this.channels.pick((c) {
      return c.id == this.id;
    });
  }

  /// Request offline members for this guild
  void requestOfflineMembers() {
    this.client.gw.send(new RequestGuildMembers(this.id));
  }

  override Permission getPermissions(Snowflake user) {
    // If we're the owner, we have alllll the permissions
    if (this.ownerID == user) {
      return Permissions.ADMINISTRATOR;
    }

    // Otherwise grab the member object
    GuildMember member = this.getMember(user);
    Permission perm;
    auto roles = member.roles.map!((rid) => this.roles.get(rid));
    this.client.log.infof("%s", member.roles);

    foreach (role; roles) {
      this.client.log.infof("role: %s, perms: %s", role.name, role.permissions);
      perm |= role.permissions;
    }

    return perm;
  }
}
