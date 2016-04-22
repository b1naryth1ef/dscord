module types.channel;

import types.base,
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
  this(JSONObject obj) {
    super(obj);
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

  this(JSONObject obj) {
    super(obj);
  }

  override void load(JSONObject obj) {
    this.id = obj.get!Snowflake("id");
    this.name = obj.get!wstring("name");
    this.topic = obj.get!wstring("topic");
    this.guild_id = obj.get!Snowflake("guild_id");
    this.last_message_id = obj.get!Snowflake("last_message_id");
    this.position = obj.get!ushort("position");
    this.bitrate = obj.get!ushort("bitrate");

    if (obj.get!bool("is_private")) {
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
