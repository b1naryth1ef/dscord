module dscord.types.message;

import std.stdio;

import dscord.client,
       dscord.types.base,
       dscord.types.user,
       dscord.types.channel,
       dscord.util.json;


class Message : Model {
  Snowflake  id;
  Snowflake  channel_id;
  User       author;
  wstring    content;
  string     timestamp; // TODO: timestamps lol
  string     edited_timestamp; // TODO: timestamps lol
  bool       tts;
  bool       mention_everyone;
  string     nonce;

  /* TODO:
    mentions
    attachments
    embeds
  */

  this(Client client, JSONObject obj) {
    super(client, obj);
  }

  override void load(JSONObject obj) {
    this.id = obj.get!Snowflake("id");
    this.channel_id = obj.get!Snowflake("channel_id");
    this.content = obj.get!wstring("content");
    this.timestamp = obj.get!string("timestamp");
    this.edited_timestamp = obj.get!string("edited_timestamp");
    this.tts = obj.get!bool("tts");
    this.mention_everyone = obj.get!bool("mention_everyone");
    this.nonce = obj.get!string("nonce");

    auto auth = obj.get!JSONObject("author");
    this.author = this.client.state.users.getOrSet(
      auth.get!Snowflake("id"),
      { return new User(this.client, auth); }
    );
  }

  @property Channel channel() {
    return this.client.state.channels.get(this.channel_id);
  }
}
