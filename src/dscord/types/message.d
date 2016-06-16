module dscord.types.message;

import std.stdio,
       std.variant,
       std.conv,
       std.format,
       std.regex;

import dscord.client,
       dscord.types.all;

class MessageEmbed : IModel {
  mixin Model;

  string  title;
  string  type;
  string  description;
  string  url;

  // TODO: thumbnail, provider

  override void load(ref JSON obj) {
    obj.keySwitch!(
      "title", "type", "description", "url"
    )(
      { this.title = obj.read!string; },
      { this.type = obj.read!string; },
      { this.description = obj.read!string; },
      { this.url = obj.read!string; },
    );
  }
}

class MessageAttachment : IModel {
  mixin Model;

  Snowflake  id;
  string     filename;
  uint       size;
  string     url;
  string     proxyUrl;
  uint       height;
  uint       width;

  override void load(ref JSON obj) {
    obj.keySwitch!(
      "id", "filename", "size", "url", "proxy_url",
      "height", "width",
    )(
      { this.id = readSnowflake(obj); },
      { this.filename = obj.read!string; },
      { this.size = obj.read!uint; },
      { this.url = obj.read!string; },
      { this.proxyUrl = obj.read!string; },
      { this.height = obj.read!uint; },
      { this.width = obj.read!uint; },
    );
  }
}

class Message : IModel {
  mixin Model;

  Snowflake  id;
  Snowflake  channelID;
  Channel    channel;
  User       author;
  string     content;
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

  this(Client client, ref JSON obj) {
    super(client, obj);
  }

  this(Channel channel, ref JSON obj) {
    this.channel = channel;
    super(channel.client, obj);
  }

  override void init() {
    this.mentions = new UserMap;
    this.roleMentions = new RoleMap;
  }

  override void load(ref JSON obj) {
    // TODO: avoid leaking user

    obj.keySwitch!(
      "id", "channel_id", "content", "timestamp", "edited_timestamp", "tts",
      "mention_everyone", "nonce", "author", "mentions", "mention_roles",
      // "embeds", "attachments",
    )(
      { this.id = readSnowflake(obj); },
      { this.channelID = readSnowflake(obj); },
      { this.content = obj.read!string; },
      { this.timestamp = obj.read!string; },
      { this.editedTimestamp = obj.read!string; },
      { this.tts = obj.read!bool; },
      { this.mentionEveryone = obj.read!bool; },
      { this.nonce = obj.read!string; },
      { this.author = new User(this.client, obj); },
      { loadMany!User(this.client, obj, (u) { this.mentions[u.id] = u; }); },
      { obj.skipValue; },
      // { obj.skipValue; },
      // { obj.skipvalue; },
    );

    if (!this.channel && this.client.state.channels.has(this.channelID)) {
      this.channel = this.client.state.channels.get(this.channelID);
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
    this.client.api.sendMessage(this.channel.id, content, nonce, tts);
  }

  /*
    True if this message mentions the current user in any way (everyone, direct mention, role mention)
  */
  @property bool mentioned() {
    this.client.log.tracef("M: %s", this.mentions.keys);

    return this.mentionEveryone ||
      this.mentions.has(this.client.state.me.id) ||
      this.roleMentions.memberHasRoleWithin(
        this.guild.getMember(this.client.state.me));
  }

  @property Guild guild() {
    if (this.channel && this.channel.guild) return this.channel.guild;
    return null;
  }
}
