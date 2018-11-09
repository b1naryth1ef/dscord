module dscord.state;

import std.functional,
       std.stdio,
       std.algorithm.iteration,
       std.experimental.logger;

import vibe.core.sync : createManualEvent, LocalManualEvent;
import std.algorithm.searching : canFind, countUntil;
import std.algorithm.mutation : remove;

import dscord.api,
       dscord.types,
       dscord.client,
       dscord.gateway,
       dscord.util.emitter;

/**
  The State class is used to track and maintain client state.
*/
class State : Emitter {
  // Client
  Client         client;
  APIClient      api;
  GatewayClient  gw;

  /// Currently logged in user, recieved from READY payload.
  User        me;

  /*
    TODO: all of these should contain weakrefs too the objects.
  */

  /// All users we've seen
  UserMap        users;

  /// All currently loaded guilds
  GuildMap       guilds;

  /// All currently loaded DMs
  ChannelMap     directMessages;

  /// All currently loaded channels
  ChannelMap     channels;

  /// All voice states
  VoiceStateMap  voiceStates;

  /// Event triggered when all guilds are synced
  LocalManualEvent  ready;

  bool requestOfflineMembers = true;

  private {
    Snowflake[] awaitingCreate;

    Logger  log;
    EventListenerArray  listeners;
  }

  this(Client client) {
    this.client = client;
    this.log = client.log;
    this.api = client.api;
    this.gw = client.gw;

    this.users = new UserMap;
    this.guilds = new GuildMap;
    this.directMessages = new ChannelMap;
    this.channels = new ChannelMap;
    this.voiceStates = new VoiceStateMap;

    this.ready = createManualEvent();

    // Finally bind all events we want
    this.bindListeners();
  }

  private void listen(Ty...)() {
    foreach (T; Ty) {
      this.listeners ~= this.client.events.listen!T(mixin("&this.on" ~ T.stringof));
    }
  }

  private void bindListeners() {
    // Unbind all listeners
    this.listeners.each!((l) => l.unbind());

    // Always listen for ready payload
    this.listen!(
      Ready, GuildCreate, GuildUpdate, GuildDelete, GuildMemberAdd, GuildMemberRemove,
      GuildMemberUpdate, GuildMembersChunk, GuildRoleCreate, GuildRoleUpdate, GuildRoleDelete,
      GuildEmojisUpdate, ChannelCreate, ChannelUpdate, ChannelDelete, VoiceStateUpdate, MessageCreate,
      PresenceUpdate
    );
  }

  private void onReady(Ready r) {
    this.me = r.me;

    foreach (guild; r.guilds) {
      this.awaitingCreate ~= guild.id;
    }

    foreach (dm; r.dms) {
      this.directMessages[dm.id] = dm;
    }
  }

  private void onGuildCreate(GuildCreate c) {
    // If this guild is "coming online" and we're awaiting its creation, clear that state here
    if (!c.unavailable && this.awaitingCreate.canFind(c.guild.id)) {
      this.awaitingCreate.remove(this.awaitingCreate.countUntil(c.guild.id));

      // If no other guilds are awaiting, emit the event
      if (this.awaitingCreate.length == 0) {
        this.ready.emit();
      }
    }

    this.guilds[c.guild.id] = c.guild;

    c.guild.channels.each((c) {
      this.channels[c.id] = c;
    });

    c.guild.members.each((m) {
      this.users[m.user.id] = m.user;
    });

    c.guild.voiceStates.each((v) {
      this.voiceStates[v.sessionID] = v;
    });

    if (this.requestOfflineMembers) {
      c.guild.requestOfflineMembers();
    }
  }

  private void onGuildUpdate(GuildUpdate c) {
    if (!this.guilds.has(c.guild.id)) return;
    // TODO: handle updates, iterate over raw data
    // this.guilds[c.guild.id].fromUpdate(c);
  }

  private void onGuildDelete(GuildDelete c) {
    if (!this.guilds.has(c.guildID)) return;

    /*
      this._guilds[c.guildID].channels.each((c) {
        destroy(c.id);
        this._channels.remove(c.id);
      });
    */

    this.guilds.remove(c.guildID);
  }

  private void onGuildMemberAdd(GuildMemberAdd c) {
    if (this.users.has(c.member.user.id)) {
      this.users[c.member.user.id] = c.member.user;
    }

    if (this.guilds.has(c.member.guild.id)) {
      this.guilds[c.member.guild.id].members[c.member.user.id] = c.member;
    }
  }

  private void onGuildMemberRemove(GuildMemberRemove c) {
    if (!this.guilds.has(c.guildID)) return;
    if (!this.guilds[c.guildID].members.has(c.user.id)) return;
    this.guilds[c.guildID].members.remove(c.user.id);
  }

  private void onGuildMemberUpdate(GuildMemberUpdate c) {
    if (!this.guilds.has(c.member.guildID)) return;
    if (!this.guilds[c.member.guildID].members.has(c.member.user.id)) return;
    // TODO: handle updates
    // this._guilds[c.guildID].members[c.user.id].fromUpdate(c);
  }

  private void onGuildRoleCreate(GuildRoleCreate c) {
    if (!this.guilds.has(c.guildID)) return;
    this.guilds[c.guildID].roles[c.role.id] = c.role;
  }

  private void onGuildRoleDelete(GuildRoleDelete c) {
    if (!this.guilds.has(c.guildID)) return;
    if (!this.guilds[c.guildID].roles.has(c.role.id)) return;
    this.guilds[c.guildID].roles.remove(c.role.id);
  }

  private void onGuildRoleUpdate(GuildRoleUpdate c) {
    if (!this.guilds.has(c.guildID)) return;
    if (!this.guilds[c.guildID].roles.has(c.role.id)) return;
    this.guilds[c.guildID].roles[c.role.id] = c.role;
  }

  private void onChannelCreate(ChannelCreate c) {
    this.channels[c.channel.id] = c.channel;
  }

  private void onChannelUpdate(ChannelUpdate c) {
    this.channels[c.channel.id] = c.channel;
  }

  private void onChannelDelete(ChannelDelete c) {
    if (this.channels.has(c.channel.id)) {
      this.channels.remove(c.channel.id);
    }
  }

  private void onVoiceStateUpdate(VoiceStateUpdate u) {
    // TODO: shallow tracking, don't require guilds
    auto guild = this.guilds.get(u.state.guildID);
    if (!guild) return;

    if (!u.state.channelID) {
      this.voiceStates.remove(u.state.sessionID);
      guild.voiceStates.remove(u.state.sessionID);
    } else {
      this.voiceStates[u.state.sessionID] = u.state;
      guild.voiceStates[u.state.sessionID] = u.state;
    }
  }

  private void onGuildMembersChunk(GuildMembersChunk c) {
    // TODO
  }

  private void onGuildEmojisUpdate(GuildEmojisUpdate c) {
    // TODO
  }

  private void onMessageCreate(MessageCreate mc) {
    // TODO
  }

  private void onPresenceUpdate(PresenceUpdate p) {
    // TODO
  }
}
