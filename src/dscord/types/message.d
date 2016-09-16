module dscord.types.message;

import std.stdio,
       std.variant,
       std.conv,
       std.format,
       std.regex,
       std.array,
       std.algorithm.iteration;

import dscord.types,
       dscord.client;

/**
  An interface implementting something that can be sent as a message.
*/
interface Sendable {
  /// Returns a string that will NEVER be greater than 2000 characters
  immutable(string) toSendableString();
}

class MessageEmbed : IModel {
  mixin Model;

  string  title;
  string  type;
  string  description;
  string  url;

  // TODO: thumbnail, provider

  override void load(JSONDecoder obj) {
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

  override void load(JSONDecoder obj) {
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
  bool       pinned;

  // TODO: GuildMemberMap here
  UserMap    mentions;
  RoleMap    roleMentions;

  // Embeds
  MessageEmbed[]  embeds;

  // Attachments
  MessageAttachment[]  attachments;

  this(Client client, JSONDecoder obj) {
    super(client, obj);
  }

  this(Channel channel, JSONDecoder obj) {
    this.channel = channel;
    super(channel.client, obj);
  }

  override void init() {
    this.mentions = new UserMap;
    this.roleMentions = new RoleMap;
  }

  override void load(JSONDecoder obj) {
    // TODO: avoid leaking user

    obj.keySwitch!(
      "id", "channel_id", "content", "timestamp", "edited_timestamp", "tts",
      "mention_everyone", "nonce", "author", "pinned", "mentions", "mention_roles",
      // "embeds", "attachments",
    )(
      { this.id = readSnowflake(obj); },
      { this.channelID = readSnowflake(obj); },
      { this.content = obj.read!string; },
      { this.timestamp = obj.read!string; },
      {
        if (obj.peek() == VibeJSON.Type.string) {
          this.editedTimestamp = obj.read!string;
        } else {
          obj.skipValue;
        }
      },
      { this.tts = obj.read!bool; },
      { this.mentionEveryone = obj.read!bool; },
      {
        if (obj.peek() == VibeJSON.Type.string) {
          this.nonce = obj.read!string;
        } else if (obj.peek() == VibeJSON.Type.null_) {
          obj.skipValue;
        } else {
          this.nonce = obj.read!long.to!string;
        }
      },
      { this.author = new User(this.client, obj); },
      { this.pinned = obj.read!bool; },
      { loadMany!User(this.client, obj, (u) { this.mentions[u.id] = u; }); },
      { obj.skipValue; },
      // { obj.skipValue; },
      // { obj.skipvalue; },
    );

    if (!this.channel && this.client.state.channels.has(this.channelID)) {
      this.channel = this.client.state.channels.get(this.channelID);
    }
  }

  override string toString() {
    return format("<Message %s>", this.id);
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

  /**
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

  /**
    Sends a new message to the same channel as this message.

    Params:
      content = the message contents
      nonce = the message nonce
      tts = whether this is a TTS message
  */
  Message reply(inout(string) content, string nonce=null, bool tts=false) {
    return this.client.api.sendMessage(this.channel.id, content, nonce, tts);
  }

  /**
    Sends a Sendable to the same channel as this message.
  */
  Message reply(Sendable obj) {
    return this.client.api.sendMessage(this.channel.id, obj.toSendableString(), null, false);
  }

  /**
    Sends a new formatted message to the same channel as this message.
  */
  Message replyf(T...)(inout(string) content, T args) {
    return this.client.api.sendMessage(this.channel.id, format(content, args), null, false);
  }

  /**
    Edits this message contents.
  */
  Message edit(inout(string) content) {
    return this.client.api.editMessage(this.channel.id, this.id, content);
  }

  /**
    Edits this message contents with a Sendable.
  */
  Message edit(Sendable obj) {
    return this.edit(obj.toSendableString());
  }

  /**
    Deletes this message.
  */
  void del() {
    if (!this.canDelete()) {
      throw new PermissionsError(Permissions.MANAGE_MESSAGES);
    }

    return this.client.api.deleteMessage(this.channel.id, this.id);
  }

  /*
    True if this message mentions the current user in any way (everyone, direct mention, role mention)
  */
  @property bool mentioned() {
    return this.mentionEveryone ||
      this.mentions.has(this.client.state.me.id) ||
      this.roleMentions.keyUnion(
        this.guild.getMember(this.client.state.me).roles
      ).length != 0;
  }

  /**
    Guild this message was sent in (if applicable).
  */
  @property Guild guild() {
    if (this.channel && this.channel.guild) return this.channel.guild;
    return null;
  }

  /**
    Returns an array of emoji IDs for all custom emoji used in this message.
  */
  @property Snowflake[] customEmojiByID() {
    return matchAll(this.content, regex("<:\\w+:(\\d+)>")).map!((m) => m.back.to!Snowflake).array;
  }

  /// Whether the bot can edit this message
  bool canDelete() {
    return (this.author.id == this.client.state.me.id ||
      this.channel.can(this.client.state.me, Permissions.MANAGE_MESSAGES));
  }

  /// Whether the bot can edit this message
  bool canEdit() {
    return (this.author.id == this.client.state.me.id);
  }
}
