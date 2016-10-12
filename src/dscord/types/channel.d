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

enum PermissionOverwriteType : string {
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
  Channel    channel;

  // Overwrite type
	PermissionOverwriteType  type;

	// Permissions
	Permission  allow;
	Permission  deny;

  this(Channel channel, JSONDecoder obj) {
    this.channel = channel;
    super(channel.client, obj);
  }

  override void load(JSONDecoder obj) {
    obj.keySwitch!(
      "id", "allow", "deny", "type"
    )(
      { this.id = readSnowflake(obj); },
      { this.allow = Permission(obj.read!uint); },
      { this.deny = Permission(obj.read!uint); },
      { this.type = cast(PermissionOverwriteType)obj.read!string; },
    );
  }
}

class Channel : IModel, IPermissible {
  mixin Model;
  mixin Permissible;

  Snowflake    id;
  string       name;
  string       topic;
  Guild        guild;
  Snowflake    lastMessageID;
  short        position;
  uint         bitrate;
  User         recipient;
  ChannelType  type;
  bool         isPrivate;

  // Overwrites
  PermissionOverwriteMap  overwrites;

  // Voice Connection
  VoiceClient  vc;

  this(Client client, JSONDecoder obj) {
    super(client, obj);
  }

  this(Guild guild, JSONDecoder obj) {
    this.guild = guild;
    super(guild.client, obj);
  }

  override void init() {
    this.overwrites = new PermissionOverwriteMap;
  }

  override void load(JSONDecoder obj) {
    obj.keySwitch!(
      "id", "name", "topic", "guild_id", "last_message_id", "position",
      "bitrate", "is_private", "type", "permission_overwrites",
    )(
      { this.id = readSnowflake(obj); },
      { this.name = obj.read!string; },
      { this.topic = obj.read!string; },
      { this.guild = this.client.state.guilds.get(readSnowflake(obj)); },
      { this.lastMessageID = readSnowflake(obj); },
      { this.position = obj.read!short; },
      { this.bitrate = obj.read!uint; },
      { this.isPrivate = obj.read!bool; },
      { this.type = cast(ChannelType)obj.read!ushort; },
      {
        loadManyComplex!(Channel, PermissionOverwrite)(this, obj, (p) { this.overwrites[p.id] = p; });
      },
    );
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
    return this.isPrivate;
  }

  @property bool voice() {
    return this.type == ChannelType.GUILD_VOICE;
  }

  @property bool text() {
    return this.type == ChannelType.GUILD_TEXT || this.type == ChannelType.DM;
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
