module dscord.types.user;

import std.stdio;

import dscord.client,
       dscord.types.all;

alias UserMap = IdentifiedModelMap!(User);

class User : Model, Identifiable {
  Snowflake  id;
  string     username;
  string     discriminator;
  byte[]     avatar;
  bool       verified;
  string     email;

  // Helpful storage items

  this(Client client, JSONObject obj) {
    super(client, obj);
  }

  Snowflake getID() {
    return this.id;
  }

  override void load(JSONObject obj) {
    this.id = obj.get!Snowflake("id");
    this.username = obj.get!string("username");
    this.discriminator = obj.get!string("discriminator");
    this.avatar = cast(byte[])obj.get!string("avatar");
    this.verified = obj.get!bool("verified", false);
    this.email = obj.get!string("email", "");
  }
}
