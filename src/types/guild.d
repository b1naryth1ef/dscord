module types.guild;

import std.stdio,
       std.variant;

import types.base,
       util.json;

alias GuildMap = ModelMap!(Snowflake, Guild);

class Role {
  Snowflake id;
  string name;
  uint color;
  bool hoist;
  uint position;
  Permission permission;
  bool managed;
}

class Emoji {
  Snowflake id;
  string name;
  Role[] roles;
  bool require_colons;
  bool managed;
}

class Guild : Model {
  Snowflake id;
  Snowflake owner_id;
  Snowflake afk_channel_id;
  Snowflake embed_channel_id;

  wstring name;
  string icon;
  string splash;
  string region;
  uint afk_timeout;
  bool embed_enabled;
  uint verification_level;
  Role[] roles;
  Emoji[] emoji;
  string[] features;

  this(JSONObject obj) {
    super(obj);
  }

  override void load(JSONObject obj) {
    this.id = obj.get!Snowflake("id");
  }
}
