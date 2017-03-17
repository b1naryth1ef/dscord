module dscord.types.message;

import std.stdio,
       std.variant,
       std.conv,
       std.format,
       std.regex,
       std.array,
       std.algorithm.iteration,
       std.algorithm.setops : nWayUnion;

import dscord.types,
       dscord.client;

/**
  An interface implementting something that can be sent as a message.
*/
interface Sendable {
  /// Returns a string that will NEVER be greater than 2000 characters
  immutable(string) toSendableString();
}

/**
  Enum of all types a message can be.
*/
enum MessageType {
  DEFAULT = 0,
  RECIPIENT_ADD = 1,
  RECIPIENT_REMOVE = 2,
  CALL = 3,
  CHANNEL_NAME_CHANGE = 4,
  CHANNEL_ICON_CHANGE = 5,
  PINS_ADD = 6,
}

// TODO
class MessageReaction : IModel {
  mixin Model;
}

class MessageEmbedFooter : IModel {
  mixin Model;

  string  text;
  string  iconURL;
  string  proxyIconURL;
}

class MessageEmbed : IModel {
  mixin Model;

  string  title;
  string  type;
  string  description;
  string  url;

  // TODO: thumbnail, provider
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
}

class Message : IModel {
  mixin Model;

  Snowflake  id;
  Snowflake  channelID;
  User       author;
  string     content;
  string     timestamp; // TODO: timestamps lol
  string     editedTimestamp; // TODO: timestamps lol
  bool       tts;
  bool       mentionEveryone;
  string     nonce;
  bool       pinned;

  // TODO: GuildMemberMap here
  @JSONListToMap("id")
  UserMap    mentions;

  @JSONSource("mention_roles")
  Snowflake[]    roleMentions;

  // Embeds
  MessageEmbed[]  embeds;

  // Attachments
  MessageAttachment[]  attachments;

  @property Guild guild() {
    return this.channel.guild;
  }

  @property Channel channel() {
    return this.client.state.channels.get(this.channelID);
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
    }, (msg, role) { return "@" ~ msg.guild.roles.get(role).name; });
  }

  /**
    Returns the message contents, replacing all mentions with the result from the
    specified delegate.
  */
  string replaceMentions(string delegate(Message, User) fu, string delegate(Message, Snowflake) fr) {
    if (!this.mentions.length && !this.roleMentions.length) {
      return this.content;
    }

    string result = this.content;
    foreach (ref User user; this.mentions.values) {
      result = replaceAll(result, regex(format("<@!?(%s)>", user.id)), fu(this, user));
    }

    foreach (ref Snowflake role; this.roleMentions) {
      result = replaceAll(result, regex(format("<@!?(%s)>", role)), fr(this, role));
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
    return this.client.api.channelsMessagesCreate(this.channelID, content, nonce, tts);
  }

  /**
    Sends a Sendable to the same channel as this message.
  */
  Message reply(Sendable obj) {
    return this.client.api.channelsMessagesCreate(this.channelID, obj.toSendableString(), null, false);
  }

  /**
    Sends a new formatted message to the same channel as this message.
  */
  Message replyf(T...)(inout(string) content, T args) {
    return this.client.api.channelsMessagesCreate(this.channelID, format(content, args), null, false);
  }

  /**
    Edits this message contents.
  */
  Message edit(inout(string) content) {
    return this.client.api.channelsMessagesModify(this.channelID, this.id, content);
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

    return this.client.api.channelsMessagesDelete(this.channelID, this.id);
  }

  /*
    True if this message mentions the current user in any way (everyone, direct mention, role mention)
  */
  @property bool mentioned() {
    return this.mentionEveryone ||
      this.mentions.has(this.client.state.me.id) ||
        nWayUnion([this.roleMentions, this.guild.getMember(this.client.state.me).roles]).array.length != 0;
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
