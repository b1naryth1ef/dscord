module state;

import std.functional;

import api.client,
       gateway.client,
       gateway.events,
       gateway.packets,
       types.base,
       types.user,
       types.guild,
       types.channel;

class State {
  // Client
  APIClient      api;
  GatewayClient  gw;

  // Storage
  User        me;
  GuildMap    guilds;
  ChannelMap  channels;

  this(APIClient api, GatewayClient gw) {
    this.api = api;
    this.gw = gw;

    this.bindEvents();
  }

  void bindEvents() {
    this.gw.onEvent!Ready(toDelegate(&this.onReady));
  }

  void onReady(Ready r) {
    this.me = me;
  }

  Guild guild(Snowflake id) {
    return this.guilds[id];
  }
}


