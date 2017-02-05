module dscord.types.user;

import std.stdio,
       std.format;

import dscord.types,
       dscord.client;

alias UserMap = ModelMap!(Snowflake, User);

enum GameType : ushort {
  DEFAULT = 0,
  STREAMING = 1,
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
  UserStatus  status;
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
}
