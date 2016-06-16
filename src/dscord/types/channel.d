module dscord.types.channel;

import std.stdio,
       std.variant,
       core.vararg;

import dscord.client,
       dscord.voice.client,
       dscord.types.all;

alias ChannelMap = ModelMap!(Snowflake, Channel);
alias PermissionOverwriteMap = ModelMap!(Snowflake, PermissionOverwrite);

enum ChannelType {
  NONE,
  TEXT = 1 << 0,
  VOICE = 1 << 1,
  PUBLIC = 1 << 2,
  PRIVATE = 1 << 3,
};

enum PermissionOverwriteType {
	ROLE = 1 << 0,
	MEMBER = 1 << 1,
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

  this(Channel channel, ref JSON obj) {
    this.channel = channel;
    super(channel.client, obj);
  }

  override void load(ref JSON obj) {
    obj.keySwitch!(
      "id", "allow", "deny", "type"
    )(
      { this.id = readSnowflake(obj); },
      { this.allow = Permission(obj.read!uint); },
      { this.deny = Permission(obj.read!uint); },
      { this.type = obj.read!string == "role" ?
        PermissionOverwriteType.ROLE :
        PermissionOverwriteType.MEMBER;
      },
    );
  }

  Snowflake getID() {
    return this.id;
  }
}

class Channel : IModel {
  mixin Model;

  Snowflake    id;
  string       name;
  string       topic;
  Guild        guild;
  Snowflake    lastMessageID;
  // ChannelType  type;
  short        position;
  uint         bitrate;
  User         recipient;
  string       type;
  bool         isPrivate;

  // Overwrites
  PermissionOverwriteMap  overwrites;

  // Voice Connection
  VoiceClient  vc;

  this(Client client, ref JSON obj) {
    super(client, obj);
  }

  this(Guild guild, ref JSON obj) {
    this.guild = guild;
    super(guild.client, obj);
  }

  override void init() {
    this.overwrites = new PermissionOverwriteMap;
  }

  override void load(ref JSON obj) {
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
      { this.type = obj.read!string; },
      {
        loadManyComplex!(Channel, PermissionOverwrite)(this, obj, (p) { this.overwrites[p.id] = p; });
      },
    );
  }

  Snowflake getID() {
    return this.id;
  }

  void sendMessage(string content, string nonce=null, bool tts=false) {
    this.client.api.sendMessage(this.id, content, nonce, tts);
  }

  @property bool DM() {
    return this.isPrivate;
  }

  @property bool voice() {
    return this.type == "voice";
  }

  @property bool text() {
    return this.type == "text";
  }

  @property auto voiceStates() {
    return this.guild.voiceStates.filter(c => c.channelID == this.id);
  }

  VoiceClient joinVoice() {
    this.vc = new VoiceClient(this);
    return this.vc;
  }
}
