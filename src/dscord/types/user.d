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

class Game {
  string name;
  string url;
  GameType type;

  this(string name, string url="", GameType type=GameType.DEFAULT) {
    this.name = name;
    this.url = url;
    this.type = type;
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

  Snowflake getID() {
    return this.id;
  }
}
