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

enum VerificationLevel : ushort {
  NONE = 0,
  LOW = 1,
  MEDIUM = 2,
  HIGH = 3,
  EXTREME = 4,
}

class Role : IModel {
  mixin Model;

  Snowflake   id;
  Snowflake   guildID;

  string      name;
  bool        hoist;
  bool        managed;
  uint        color;
  Permission  permissions;
  short       position;
  bool        mentionable;

  @property Guild guild() {
    return this.client.state.guilds.get(this.guildID);
  }
}

class Emoji : IModel {
  mixin Model;

  Snowflake  id;
  Snowflake  guildID;
  string     name;
  bool       requireColons;
  bool       managed;

  Snowflake[]  roles;

  @property Guild guild() {
    return this.client.state.guilds.get(this.guildID);
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

  User       user;
  Snowflake  guildID;
  string     nick;
  string     joinedAt;
  bool       mute;
  bool       deaf;

  Snowflake[]  roles;

  @property Snowflake id() {
    return this.user.id;
  }

  @property Guild guild() {
    return this.client.state.guilds.get(this.guildID);
  }

  override string toString() {
    return format("<GuildMember %s#%s (%s / %s)>",
      this.user.username,
      this.user.discriminator,
      this.id,
      this.guild.id);
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

  @JSONListToMap("id")
  GuildMemberMap  members;

  @JSONListToMap("sessionID")
  VoiceStateMap   voiceStates;

  @JSONListToMap("id")
  ChannelMap      channels;

  @JSONListToMap("id")
  RoleMap         roles;

  @JSONListToMap("id")
  EmojiMap        emojis;

  override void init() {
    // It's possible these are not created
    if (!this.members) return;

    this.members.each((m) { m.guildID = this.id; });
    this.voiceStates.each((vc) { vc.guildID = this.id; });
    this.channels.each((c) { c.guildID = this.id; });
    this.roles.each((r) { r.guildID = this.id; });
    this.emojis.each((e) { e.guildID = this.id; });
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
    return this.members.get(id);
  }

  /// Kick a given GuildMember
  void kick(GuildMember member) {
    this.kick(member.user);
  }

  /// Kick a given User
  void kick(User user) {
    this.client.api.guildsMembersKick(this.id, user.id);
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

    // Iterate over roles and add permissions
    foreach (role; roles) {
      perm |= role.permissions;
    }

    return perm;
  }

  /// Set this servers name
  void setName(string name) {
    this.client.api.guildsModify(this.id, VibeJSON(["name" : VibeJSON(name)]));
  }

  /// Set this servers region
  void setRegion(string region) {
    this.client.api.guildsModify(this.id, VibeJSON(["region" : VibeJSON(region)]));
  }
}
