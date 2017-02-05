module dscord.types.channel;

import std.stdio,
       std.format,
       std.variant,
       std.algorithm,
       core.vararg;

import dscord.types,
       dscord.voice,
       dscord.client;

alias ChannelMap = ModelMap!(Snowflake, Channel);
alias PermissionOverwriteMap = ModelMap!(Snowflake, PermissionOverwrite);

enum PermissionOverwriteType {
  ROLE = "role",
  MEMBER = "member" ,
}

enum ChannelType : ushort {
  GUILD_TEXT = 0,
  DM = 1,
  GUILD_VOICE = 2,
  GROUP_DM = 3,
}

class PermissionOverwrite : IModel {
  mixin Model;

  Snowflake  id;

  // Overwrite type
  PermissionOverwriteType  type;

  // Permissions
  Permission  allow;
  Permission  deny;

  // Parent channel
  Channel    channel;
}

class Channel : IModel, IPermissible {
  mixin Model;
  mixin Permissible;

  Snowflake    id;
  Snowflake    guildID;
  string       name;
  string       topic;
  Snowflake    lastMessageID;
  short        position;
  uint         bitrate;
  ChannelType  type;

  @JSONListToMap("id")
  UserMap         recipients;

  // Overwrites
  @JSONListToMap("id")
  @JSONSource("permission_overwrites")
  PermissionOverwriteMap  overwrites;

  // Voice Connection
  //  TODO: move?
  @JSONIgnore
  VoiceClient  vc;

  @property Guild guild() {
    return this.client.state.guilds.get(this.guildID);
  }

  override void init() {
    this.overwrites = new PermissionOverwriteMap;
  }

  override string toString() {
    return format("<Channel %s (%s)>", this.name, this.id);
  }

  Message sendMessage(inout(string) content, string nonce=null, bool tts=false) {
    return this.client.api.channelsMessagesCreate(this.id, content, nonce, tts);
  }

  Message sendMessagef(T...)(inout(string) content, T args) {
    return this.client.api.channelsMessagesCreate(this.id, format(content, args), null, false);
  }

  Message sendMessage(Sendable obj) {
    return this.sendMessage(obj.toSendableString());
  }

  @property bool DM() {
    return (
      this.type == ChannelType.DM ||
      this.type == ChannelType.GROUP_DM
    );
  }

  @property bool voice() {
    return (
      this.type == ChannelType.GUILD_VOICE ||
      this.type == ChannelType.GROUP_DM ||
      this.type == ChannelType.DM
    );
  }

  @property bool text() {
    return (
      this.type == ChannelType.GUILD_TEXT ||
      this.type == ChannelType.DM ||
      this.type == ChannelType.GROUP_DM
    );
  }

  @property auto voiceStates() {
    return this.guild.voiceStates.filter(c => c.channelID == this.id);
  }

  VoiceClient joinVoice() {
    this.vc = new VoiceClient(this);
    return this.vc;
  }

  override Permission getPermissions(Snowflake user) {
    GuildMember member = this.guild.getMember(user);
    Permission perm = this.guild.getPermissions(user);

    // Apply any role overwrites
    foreach (overwrite; this.overwrites.values) {
      if (overwrite.type != PermissionOverwriteType.ROLE) continue;
      if (!member.roles.canFind(overwrite.id)) continue;
      perm ^= overwrite.deny;
      perm |= overwrite.allow;
    }

    // Finally grab a user overwrite
    if (this.overwrites.has(member.id)) {
      perm ^= this.overwrites.get(member.id).deny;
      perm |= this.overwrites.get(member.id).allow;
    }

    return perm;
  }
}
