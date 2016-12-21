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

  static Game load(JSONDecoder obj) {
    Game inst = new Game();
    obj.keySwitch!(
      "name", "url", "type"
    )(
      { inst.name = obj.read!string; },
      { inst.url = obj.read!string; },
      { inst.type = cast(GameType)obj.read!ushort; },
    );
    return inst;
  }

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

  override void load(JSONDecoder obj) {
    obj.keySwitch!(
      "user", "game", "status"
    )(
      { this.user = new User(this.client, obj); },
      {
        if (obj.peek != VibeJSON.Type.null_) {
          this.game = Game.load(obj);
        } else {
          obj.skipValue;
        }
      },
      { this.status = cast(UserStatus)obj.read!string; },
    );
  }
}

class User : IModel {
  mixin Model;

  Snowflake  id;
  string     username;
  string     discriminator;
  string     avatar;
  bool       verified;
  string     email;

  override void load(JSONDecoder obj) {
    obj.keySwitch!(
      "id", "username", "discriminator", "avatar",
      "verified", "email"
    )(
      { this.id = readSnowflake(obj); },
      { this.username = obj.read!string; },
      { this.discriminator = obj.read!string; },
      { this.avatar = obj.read!string; },
      { this.verified = obj.read!bool; },
      { this.email = obj.read!string; },
    );
  }

  override string toString() {
    return format("<User %s#%s (%s)>", this.username, this.discriminator, this.id);
  }
}
