module state;

import std.functional,
       std.stdio;

import client,
       api.client,
       gateway.client,
       gateway.events,
       gateway.packets,
       types.base,
       types.user,
       types.guild,
       types.channel;

class State {
  // Client
  Client         client;
  APIClient      api;
  GatewayClient  gw;

  // Storage
  User        me;
  GuildMap    guilds;
  ChannelMap  channels;
  UserMap     users;

  private {
    ushort onReadyGuildCount;
  }

  // Callbacks
  void delegate()  onStartupComplete;

  this(Client client) {
    this.client = client;
    this.api = client.api;
    this.gw = client.gw;

    this.guilds = new GuildMap((id) {
      return new Guild(this.client, this.api.guild(id));
    });

    this.channels = new ChannelMap;
    this.users = new UserMap;

    this.bindEvents();
  }

  void bindEvents() {
    this.gw.onEvent!Ready(toDelegate(&this.onReady));

    // Guilds
    this.gw.onEvent!GuildCreate(toDelegate(&this.onGuildCreate));
    this.gw.onEvent!GuildUpdate(toDelegate(&this.onGuildUpdate));
    this.gw.onEvent!GuildDelete(toDelegate(&this.onGuildDelete));

    // Channels
    this.gw.onEvent!ChannelCreate(toDelegate(&this.onChannelCreate));
    this.gw.onEvent!ChannelUpdate(toDelegate(&this.onChannelUpdate));
    this.gw.onEvent!ChannelDelete(toDelegate(&this.onChannelDelete));
  }

  void onReady(Ready r) {
    this.me = r.me;
    this.onReadyGuildCount = cast(ushort)r.guilds.length;
  }

  void onGuildCreate(GuildCreate c) {
    this.guilds[c.guild.id] = c.guild;
    if (!c.isNew) {
      this.onReadyGuildCount -= 1;

      if (this.onReadyGuildCount == 0 && this.onStartupComplete) {
        this.onStartupComplete();
      }
    }
  }

  void onGuildUpdate(GuildUpdate c) {
    this.guilds[c.guild.id].load(c.payload);
  }

  void onGuildDelete(GuildDelete c) {
    if (!this.guilds.has(c.guild_id)) return;

    destroy(this.guilds[c.guild_id]);
    this.guilds.del(c.guild_id);
  }

  void onChannelCreate(ChannelCreate c) {
    this.channels[c.channel.id] = c.channel;
  }

  void onChannelUpdate(ChannelUpdate c) {
    this.channels[c.channel.id] = c.channel;
  }

  void onChannelDelete(ChannelDelete c) {
    destroy(this.channels[c.channel.id]);
    this.channels.del(c.channel.id);
  }

  Guild guild(Snowflake id) {
    return this.guilds[id];
  }
}


