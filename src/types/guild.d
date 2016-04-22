module types.guild;

import std.stdio,
       std.variant,
       std.conv;

import client,
       types.base,
       types.channel,
       util.json;

alias GuildMap = ModelMap!(Snowflake, Guild);

/*
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
*/

class Guild : Model {
  Snowflake  id;
  Snowflake  owner_id;
  Snowflake  afk_channel_id;
  Snowflake  embed_channel_id;
  wstring    name;
  string     icon;
  string     splash;
  string     region;
  uint       afk_timeout;
  bool       embed_enabled;
  ushort     verification_level;
  string[]   features;

  // Mappings
  ChannelMap  channels;

  // Role[] roles;
  // Emoji[] emoji;
  // Channel[]  channels;

  this(Client client, JSONObject obj) {
    this.channels = new ChannelMap(
      &client.state.channels.get,
      &client.state.channels.set);

    super(client, obj);
  }

  override void load(JSONObject obj) {
    this.id = obj.get!Snowflake("id");

    if (obj.has("unavailable") && obj.get!bool("unavailable")) {
      return;
    }

    this.owner_id = obj.get!string("owner_id").to!Snowflake;
    this.name = obj.get!wstring("name");
    this.icon = obj.get!string("icon");
    this.region = obj.get!string("region");
    this.verification_level = obj.get!ushort("verification_level");
    this.afk_channel_id = obj.maybeGet!Snowflake("afk_channel_id", 0);
    this.splash = obj.maybeGet!string("splash", null);
    this.afk_timeout = obj.maybeGet!uint("afk_timeout", 0);

    foreach (Variant obj; obj.getRaw("channels")) {
      auto channel = new Channel(this.client, new JSONObject(variantToJSON(obj)));
      channel.guild_id = this.id;
      this.channels[channel.id] = channel;
    }

    // this.features = obj.get!string[]("features");
  }
}
