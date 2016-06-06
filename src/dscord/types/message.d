module dscord.types.message;

import std.stdio,
       std.variant,
       std.conv,
       std.format,
       std.regex;

import dscord.client,
       dscord.types.base,
       dscord.types.user,
       dscord.types.guild,
       dscord.types.channel,
       dscord.util.json;

class MessageEmbed : Model {
  string  title;
  string  type;
  string  description;
  string  url;

  // TODO: thumbnail, provider

  this(Client client, JSONObject obj) {
    super(client, obj);
  }

  override void load(JSONObject obj) {
    this.title = obj.get!string("title");
    this.type = obj.get!string("type");
    this.description = obj.get!string("description");
    this.url = obj.get!string("url");
  }
}

class MessageAttachment : Model {
  Snowflake  id;
  string     filename;
  uint       size;
  string     url;
  string     proxyUrl;
  uint       height;
  uint       width;

  this(Client client, JSONObject obj) {
    super(client, obj);
  }

  override void load(JSONObject obj) {
    this.id = obj.get!Snowflake("id");
    this.filename = obj.get!string("filename");
    this.size = obj.get!uint("size");
    this.url = obj.get!string("url");
    this.proxyUrl = obj.maybeGet!string("proxy_url", "");
    this.height = obj.maybeGet!uint("height", 0);
    this.width = obj.maybeGet!uint("width", 0);
  }
}

class Message : Model {
  Snowflake  id;
  Snowflake  channelID;
  User       author;
  string    content;
  string     timestamp; // TODO: timestamps lol
  string     editedTimestamp; // TODO: timestamps lol
  bool       tts;
  bool       mentionEveryone;
  string     nonce;

  // TODO: GuildMemberMap here
  UserMap    mentions;
  RoleMap    roleMentions;

  // Embeds
  MessageEmbed[]  embeds;

  // Attachments
  MessageAttachment[]  attachments;


  this(Client client, JSONObject obj) {
    this.mentions = new UserMap;
    this.roleMentions = new RoleMap;
    super(client, obj);
  }

  override void load(JSONObject obj) {
    this.id = obj.get!Snowflake("id");
    this.channelID = obj.get!Snowflake("channel_id");
    this.content = obj.maybeGet!(string)("content", "");
    this.timestamp = obj.maybeGet!string("timestamp", "");
    this.editedTimestamp = obj.maybeGet!string("edited_timestamp", "");
    this.tts = obj.maybeGet!bool("tts", false);
    this.mentionEveryone = obj.maybeGet!bool("mention_everyone", false);
    this.nonce = obj.maybeGet!string("nonce", "");

    if (obj.has("author")) {
      auto auth = obj.get!JSONObject("author");

      if (this.client.state.users.has(auth.get!Snowflake("id"))) {
        this.author = this.client.state.users(auth.get!Snowflake("id"));
        this.author.load(auth);
      } else {
        this.author = new User(this.client, auth);
        this.client.state.users.set(this.author.id, this.author);
      }
    }

    if (obj.has("mentions")) {
      foreach (Variant v; obj.getRaw("mentions")) {
        auto user = new User(this.client, new JSONObject(variantToJSON(v)));
        if (this.client.state.users.has(user.id)) {
          user = this.client.state.users.get(user.id);
        }
        this.mentions.set(user.id, user);
      }
    }

    if (obj.has("mention_roles")) {
      foreach (Variant v; obj.getRaw("mention_roles")) {
        auto roleID = v.coerce!Snowflake;
        this.roleMentions[roleID] = this.guild.roles.get(roleID);
      }
    }

    if (obj.has("embeds")) {
      foreach (Variant v; obj.getRaw("embeds")) {
        auto embed = new MessageEmbed(this.client, new JSONObject(variantToJSON(v)));
        this.embeds ~= embed;
      }
    }

    if (obj.has("attachments")) {
      foreach (Variant v; obj.getRaw("attachments")) {
        auto attach = new MessageAttachment(this.client,
          new JSONObject(variantToJSON(v)));
        this.attachments ~= attach;
      }
    }
  }

  /*
    Returns a version of the message contents, with mentions completely removed
  */
  string withoutMentions() {
    return this.replaceMentions((m, u) => "", (m, r) => "");
  }

  /*
    Returns a version of the message contents, replacing all mentions with user/nick names
  */
  string withProperMentions(bool nicks=true) {
    return this.replaceMentions((msg, user) {
      GuildMember m;
      if (nicks) {
        m = msg.guild.members.get(user.id);
      }
      return "@" ~ ((m && m.nick != "") ? m.nick : user.username);
    }, (msg, role) { return "@" ~ role.name; });
  }

  /*
    Returns the message contents, replacing all mentions with the result from the
    specified delegate.
  */
  string replaceMentions(string delegate(Message, User) fu, string delegate(Message, Role) fr) {
    if (!this.mentions.length) {
      return this.content;
    }

    string result = this.content;
    foreach (ref User user; this.mentions.values) {
      result = replaceAll(result, regex(format("<@!?(%s)>", user.id)), fu(this, user));
    }

    foreach (ref Role role; this.roleMentions.values) {
      result = replaceAll(result, regex(format("<@!?(%s)>", role.id)), fr(this, role));
    }

    return result;
  }

  void reply(string content, string nonce=null, bool tts=false, bool mention=false) {
    // TODO: support mentioning
    this.client.api.sendMessage(this.channelID, content, nonce, tts);
  }

  /*
    True if this message mentions the current user in any way (everyone, direct mention, role mention)
  */
  @property bool mentioned() {
    return this.mentionEveryone ||
      this.mentions.has(this.client.state.me.id) ||
      this.roleMentions.memberHasRoleWithin(
        this.guild.getMember(this.client.state.me));
  }

  @property Guild guild() {
    if (this.channel) return this.channel.guild;
    return null;
  }

  @property Channel channel() {
    // TODO: properly handle PM's
    if (this.client.state.channels.has(this.channelID)) {
      return this.client.state.channels.get(this.channelID);
    } else {
      return null;
    }
  }
}
