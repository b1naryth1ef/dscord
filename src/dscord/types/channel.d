module dscord.types.channel;

import std.stdio,
       std.variant,
       core.vararg;

import dscord.client,
       dscord.voice.client,
       dscord.types.base,
       dscord.types.guild,
       dscord.types.message,
       dscord.types.user,
       dscord.types.permission,
       dscord.types.voice,
       dscord.util.json;

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

class PermissionOverwrite : Model {
	Snowflake  id;
  Channel    channel;

  // Overwrite type
	PermissionOverwriteType  type;

	// Permissions
	Permission  allow;
	Permission  deny;

  this(Client client, JSONObject obj) {
    super(client, obj);
  }

  override void load(JSONObject obj) {
    this.id = obj.get!Snowflake("id");
    this.allow = obj.get!Permission("allow");
    this.deny = obj.get!Permission("deny");

    this.type = obj.get!string("type") == "role" ?
      PermissionOverwriteType.ROLE :
      PermissionOverwriteType.MEMBER;
  }

  Snowflake getID() {
    return this.id;
  }
}

class Channel : Model {
  Snowflake    id;
  string      name;
  string      topic;
  Snowflake    guild_id;
  Snowflake    lastMessageID;
  ChannelType  type;
  short        position;
  uint         bitrate;
  User         recipient;

  // Overwrites
  PermissionOverwriteMap  overwrites;

  // Voice Connection
  VoiceClient  vc;

  this(Client client, JSONObject obj) {
    this.overwrites = new PermissionOverwriteMap;

    super(client, obj);
  }

  override void load(JSONObject obj) {
    this.id = obj.get!Snowflake("id");
    this.name = obj.maybeGet!string("name", "");
    this.topic = obj.maybeGet!string("topic", null);
    this.guild_id = obj.maybeGet!Snowflake("guild_id", 0);
    this.lastMessageID = obj.maybeGet!Snowflake("lastMessageID", 0);
    this.position = obj.maybeGet!short("position", 0);
    this.bitrate = obj.maybeGet!uint("bitrate", 0);

    if (obj.has("is_private") && obj.get!bool("is_private")) {
      this.type |= ChannelType.PRIVATE;
    } else {
      this.type |= ChannelType.PUBLIC;
    }

    if (obj.get!string("type") == "text") {
      this.type |= ChannelType.TEXT;
    } else {
      this.type |= ChannelType.VOICE;
    }

    foreach (Variant obj; obj.getRaw("permission_overwrites")) {
      auto overwrite = new PermissionOverwrite(this.client, new JSONObject(variantToJSON(obj)));
      overwrite.channel = this;
      this.overwrites[overwrite.id] = overwrite;
    }
  }

  Snowflake getID() {
    return this.id;
  }

  void sendMessage(string content, string nonce=null, bool tts=false) {
    this.client.api.sendMessage(this.id, content, nonce, tts);
  }

  Guild guild() {
    return this.client.state.guilds(this.guild_id);
  }

  @property bool DM() {
    return cast(bool)(this.type & ChannelType.PRIVATE);
  }

  @property bool voice() {
    return cast(bool)(this.type & ChannelType.VOICE);
  }

  @property bool text() {
    return cast(bool)(this.type & ChannelType.TEXT);
  }

  @property auto voiceStates() {
    return this.guild.voiceStates.filter(c => c.channel_id == this.id);
  }

  VoiceClient joinVoice() {
    this.vc = new VoiceClient(this);
    return this.vc;
  }
}
