module dscord.types.message;

import std.stdio,
       std.variant;

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
  UserMap    mentions;

  /* TODO:
    attachments
    embeds
  */

  this(Client client, JSONObject obj) {
    this.mentions = new UserMap;
    super(client, obj);
  }

  override void load(JSONObject obj) {
    this.id = obj.get!Snowflake("id");
    this.channel_id = obj.get!Snowflake("channel_id");
    this.content = obj.maybeGet!wstring("content", "");
    this.timestamp = obj.maybeGet!string("timestamp", "");
    this.edited_timestamp = obj.maybeGet!string("edited_timestamp", "");
    this.tts = obj.maybeGet!bool("tts", false);
    this.mention_everyone = obj.maybeGet!bool("mention_everyone", false);
    this.nonce = obj.maybeGet!string("nonce", "");

    if (obj.has("author")) {
      auto auth = obj.get!JSONObject("author");

      if (this.client.state.users.has(auth.get!Snowflake("id"))) {
        this.author = this.client.state.users.get(auth.get!Snowflake("id"));
        this.author.load(auth);
      } else {
        this.author = new User(this.client, auth);
        this.client.state.users.set(this.author.id, this.author);
      }
    }

    if (obj.has("mentions")) {
      foreach (Variant obj; obj.getRaw("mentions")) {
        auto user = new User(this.client, new JSONObject(variantToJSON(obj)));
        this.mentions.set(user.id, user);
      }
    }
  }

  void reply(wstring content, string nonce=null, bool tts=false, bool mention=false) {
    // TODO: mention
    this.client.api.sendMessage(this.channel_id, content, nonce, tts);
  }

  @property Channel channel() {
    return this.client.state.channels.get(this.channel_id);
  }
}
