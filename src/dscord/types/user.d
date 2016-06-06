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
  byte[]     avatar;
  bool       verified;
  string     email;

  override void load(ref JSON obj) {
    /*
    this.id = obj.get!Snowflake("id");
    this.username = obj.get!string("username");
    this.discriminator = obj.get!string("discriminator");
    this.avatar = cast(byte[])obj.get!string("avatar");
    this.verified = obj.get!bool("verified", false);
    this.email = obj.get!string("email", "");
    */
  }

  Snowflake getID() {
    return this.id;
  }

}
