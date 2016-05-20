module dscord.types.voice;

import std.stdio;

import dscord.client,
       dscord.types.all;


alias VoiceStateMap = ModelMap!(string, VoiceState);

class VoiceState : Model {
  Snowflake  guild_id;
  Snowflake  channel_id;
  Snowflake  user_id;
  string     session_id;
  bool       deaf;
  bool       mute;
  bool       self_deaf;
  bool       self_mute;
  bool       suppress;

  this(Client client, JSONObject obj) {
    super(client, obj);
  }

  override void load(JSONObject obj) {
    this.guild_id = obj.maybeGet!Snowflake("guild_id", 0);

    if (!obj.isNull("channel_id")) {
      this.channel_id = obj.get!Snowflake("channel_id");
    }

    this.user_id = obj.get!Snowflake("user_id");
    this.session_id = obj.get!string("session_id");
    this.deaf = obj.get!bool("deaf");
    this.mute = obj.get!bool("mute");
    this.self_deaf = obj.get!bool("self_deaf");
    this.self_mute = obj.get!bool("self_mute");
    this.suppress = obj.get!bool("suppress");
  }

  @property Guild guild() {
    return this.client.state.guilds(this.guild_id);
  }

  @property Channel channel() {
    return this.client.state.channels(this.channel_id);
  }
}
