module dscord.state;

import std.functional,
       std.stdio,
       std.experimental.logger;

import dscord.client,
       dscord.api.client,
       dscord.gateway.client,
       dscord.gateway.events,
       dscord.gateway.packets,
       dscord.types.all,
       dscord.util.emitter;

class StateStartupComplete {};

class State : Emitter {
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
    Logger  log;
    ulong  onReadyGuildCount;
  }

  this(Client client) {
    this.log = client.log;

    this.client = client;
    this.api = client.api;
    this.gw = client.gw;

    this.guilds = new GuildMap;
    this.channels = new ChannelMap;
    this.users = new UserMap;

    this.bindEvents();
  }

  void bindEvents() {
    /*
    this.client.events.listen!Ready(&this.onReady);

    // Guilds
    this.client.events.listen!GuildCreate(&this.onGuildCreate);
    this.client.events.listen!GuildUpdate(&this.onGuildUpdate);
    this.client.events.listen!GuildDelete(&this.onGuildDelete);

    // Channels
    this.client.events.listen!ChannelCreate(&this.onChannelCreate);
    this.client.events.listen!ChannelUpdate(&this.onChannelUpdate);
    this.client.events.listen!ChannelDelete(&this.onChannelDelete);

    // Voice State
    this.client.events.listen!VoiceStateUpdate(&this.onVoiceStateUpdate);
    */
  }

  /*
  void onReady(Ready r) {
    this.me = r.me;
    this.onReadyGuildCount = r.guilds.length;
  }

  void onGuildCreate(GuildCreate c) {
    this.guilds[c.guild.id] = c.guild;

    // Add channels
    c.guild.channels.each((c) {
      this.channels[c.id] = c;
    });

    if (!c.created) {
      this.onReadyGuildCount -= 1;

      if (this.onReadyGuildCount == 0) {
        this.emit!StateStartupComplete(new StateStartupComplete);
      }
    }
  }

  void onGuildUpdate(GuildUpdate c) {
    this.log.warning("Hit onGuildUpdate leaving state stale");
    // TODO
    // this.guilds[c.guild.id].load(c.payload);
  }

  void onGuildDelete(GuildDelete c) {
    if (!this.guilds.has(c.guild_id)) return;

    destroy(this.guilds[c.guild_id]);
    this.guilds.remove(c.guild_id);
  }

  void onChannelCreate(ChannelCreate c) {
    this.channels[c.channel.id] = c.channel;
  }

  void onChannelUpdate(ChannelUpdate c) {
    this.channels[c.channel.id] = c.channel;
  }

  void onChannelDelete(ChannelDelete c) {
    if (this.channels.has(c.channel.id)) {
      destroy(this.channels[c.channel.id]);
      this.channels.remove(c.channel.id);
    }
  }

  void onVoiceStateUpdate(VoiceStateUpdate u) {
    auto guild = this.guilds.get(u.state.guild_id);

    if (!u.state.channel_id) {
      guild.voiceStates.remove(u.state.session_id);
    } else {
      guild.voiceStates[u.state.session_id] = u.state;
    }
  }
  */
}


