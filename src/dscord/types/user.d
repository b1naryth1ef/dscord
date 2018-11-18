module dscord.types.user;

import std.stdio,
       std.format,
       std.algorithm.searching;

import dscord.types,
       dscord.client;

alias UserMap = ModelMap!(Snowflake, User);

enum GameType : ushort {
  DEFAULT = 0,
  STREAMING = 1,
  LISTENING = 2,
  WATCHING = 3,
}

enum UserStatus : string {
  ONLINE = "online",
  IDLE = "idle",
  DND = "dnd",
  INVISIBLE = "invisible",
  OFFLINE = "offline",
}


class Game {
  string name;
  string url;
  GameType type;

  this(string name="", string url="", GameType type=GameType.DEFAULT) {
    this.name = name;
    this.url = url;
    this.type = type;
  }

  // TODO: remove
  VibeJSON dump() {
    VibeJSON obj = VibeJSON.emptyObject;

    obj["name"] = VibeJSON(this.name);

    if (this.url != "") {
      obj["url"] = VibeJSON(this.url);
      obj["type"] = VibeJSON(cast(ushort)this.type);
    }

    return obj;
  }
}

class Presence : IModel {
  mixin Model;

  User        user;
  Game        game;
  // UserStatus  status;
}

enum DefaultAvatarColor {
  BLURPLE = 0,
  GREY = 1,
  GREEN = 2,
  ORANGE = 3,
  RED = 4,
}

class User : IModel {
  mixin Model;

  Snowflake  id;
  string     username;
  string     discriminator;
  string     avatar;
  bool       verified;
  string     email;

  override string toString() {
    return format("<User %s#%s (%s)>", this.username, this.discriminator, this.id);
  }

  string getAvatarURL(string fmt = null, size_t size = 1024) {
    if (!this.avatar) {
      return format("https://cdn.discordapp.com/embed/avatars/%s.png", cast(int)this.defaultAvatarColor);
    }

    if (fmt is null) {
      fmt = this.avatar.startsWith("a_") ? "gif" : "webp";
    }

    return format("https://cdn.discordapp.com/avatars/%s/%s.%s?size=%s", this.id, this.avatar, fmt, size);
  }

  @property DefaultAvatarColor defaultAvatarColor() {
    // TODO
    return DefaultAvatarColor.BLURPLE;
  }
}

enum RelationshipType : ushort {
  FRIEND = 1,
  BLOCKED = 2,
  INCOMING_REQUEST = 3,
  OUTGOING_REQUEST = 4,
}

class Relationship : IModel {
  mixin Model;

  Snowflake id;
  User user;
  RelationshipType type;
}

class ReadState : IModel {
  mixin Model;

  Snowflake id;
  Snowflake lastMessageID;
  uint mentionCount;
}

class Settings : IModel {
  mixin Model;

  Snowflake[] guildPositions;
}
