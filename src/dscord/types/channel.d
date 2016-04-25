module dscord.types.channel;

import std.stdio,
       std.variant,
       core.vararg;

import dscord.client,
       dscord.types.base,
       dscord.types.guild,
       dscord.types.message,
       dscord.types.user,
       dscord.types.permission,
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
}

class Channel : Model {
  Snowflake    id;
  wstring      name;
  wstring      topic;
  Snowflake    guild_id;
  Snowflake    last_message_id;
  ChannelType  type;
  short        position;
  uint         bitrate;
  User*        recipient;

  // Overwrites
  PermissionOverwriteMap  overwrites;

  this(Client client, JSONObject obj) {
    this.overwrites = new PermissionOverwriteMap;

    super(client, obj);
  }

  override void load(JSONObject obj) {
    this.id = obj.get!Snowflake("id");
    this.name = obj.maybeGet!wstring("name", "");
    this.topic = obj.maybeGet!wstring("topic", null);
    this.guild_id = obj.maybeGet!Snowflake("guild_id", 0);
    this.last_message_id = obj.maybeGet!Snowflake("last_message_id", 0);
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

  void sendMessage(wstring content, string nonce=null, bool tts=false) {
    this.client.api.sendMessage(this.id, content, nonce, tts);
  }

  Guild guild() {
    return this.client.state.guild(this.guild_id);
  }

  /*Message lastMessage() {
    return this.client.state.message(this.last_message_id);
  }*/

  @property bool DM() {
    return cast(bool)(this.type & ChannelType.PRIVATE);
  }

  @property bool voice() {
    return cast(bool)(this.type & ChannelType.VOICE);
  }

  @property bool text() {
    return cast(bool)(this.type & ChannelType.TEXT);
  }
}
