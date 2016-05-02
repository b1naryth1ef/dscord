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
    ushort  onReadyGuildCount;
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
    this.client.events.listen!Ready(toDelegate(&this.onReady));

    // Guilds
    this.client.events.listen!GuildCreate(toDelegate(&this.onGuildCreate));
    this.client.events.listen!GuildUpdate(toDelegate(&this.onGuildUpdate));
    this.client.events.listen!GuildDelete(toDelegate(&this.onGuildDelete));

    // Channels
    this.client.events.listen!ChannelCreate(toDelegate(&this.onChannelCreate));
    this.client.events.listen!ChannelUpdate(toDelegate(&this.onChannelUpdate));
    this.client.events.listen!ChannelDelete(toDelegate(&this.onChannelDelete));

    // Voice State
    this.client.events.listen!VoiceStateUpdate(toDelegate(&this.onVoiceStateUpdate));
  }

  void onReady(Ready r) {
    this.me = r.me;
    this.onReadyGuildCount = cast(ushort)r.guilds.length;
  }

  void onGuildCreate(GuildCreate c) {
    this.guilds[c.guild.id] = c.guild;

    // Add channels
    c.guild.channels.each((c) {
      this.channels[c.id] = c;
    });

    if (!c.isNew) {
      this.onReadyGuildCount -= 1;

      if (this.onReadyGuildCount == 0) {
        this.emit!StateStartupComplete(new StateStartupComplete);
      }
    }
  }

  void onGuildUpdate(GuildUpdate c) {
    this.guilds[c.guild.id].load(c.payload);
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

  Guild guild(Snowflake id) {
    return this.guilds[id];
  }
}


