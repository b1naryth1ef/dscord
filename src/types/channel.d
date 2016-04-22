module types.channel;

import std.stdio;

import client,
       types.base,
       types.guild,
       types.message,
       types.user,
       util.json;

alias ChannelMap = ModelMap!(Snowflake, Channel);
alias PermissionOverwriteMap = ModelMap!(Snowflake, PermissionOverwrite);

enum ChannelType {
  None,
  TEXT = 1 << 0,
  VOICE = 1 << 1,
  PUBLIC = 1 << 2,
  PRIVATE = 1 << 3,
};

class PermissionOverwrite : Model {
  this(Client client, JSONObject obj) {
    super(client, obj);
  }

  override void load(JSONObject obj) {

  }
}

class Channel : Model {
  Snowflake    id;
  wstring      name;
  wstring      topic;
  Snowflake    guild_id;
  Snowflake    last_message_id;
  ChannelType  type;
  ushort       position;
  uint         bitrate;
  User*        recipient;

  // Overwrites
  PermissionOverwriteMap  overwrites;

  this(Client client, JSONObject obj) {
    super(client, obj);
  }

  override void load(JSONObject obj) {
    this.id = obj.get!Snowflake("id");
    this.name = obj.get!wstring("name");
    this.topic = obj.maybeGet!wstring("topic", null);
    this.guild_id = obj.maybeGet!Snowflake("guild_id", 0);
    this.last_message_id = obj.maybeGet!Snowflake("last_message_id", 0);
    this.position = obj.get!ushort("position");
    this.bitrate = obj.maybeGet!ushort("bitrate", 0);

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
