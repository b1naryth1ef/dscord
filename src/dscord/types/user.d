module dscord.types.user;

import std.stdio;

import dscord.client,
       dscord.types.all;

alias UserMap = ModelMap!(Snowflake, User);

class User : IModel {
  mixin Model;

  Snowflake  id;
  string     username;
  string     discriminator;
  string     avatar;
  bool       verified;
  string     email;

  override void load(ref JSON obj) {
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

  Snowflake getID() {
    return this.id;
  }
}
