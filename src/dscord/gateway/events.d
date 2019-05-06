/**
  Implementations of Discord events.
*/

module dscord.gateway.events;

import std.algorithm,
       std.string,
       std.stdio,
       std.datetime,
       std.array,
       std.conv;

import dscord.types,
       dscord.gateway,
       dscord.bot.command;

/**
  A wrapper type for delegates that can be attached to an event, and run after
  all listeners are executed. This can be used to ensure an event has fully passed
  through all listeners, or to avoid having function/stack pointers within plugin
  code (which allows for dynamically reloading the plugin).
*/
alias EventDeferredFunc = void delegate();

/**
  Base template for events from discord. Handles basic initilization, and some
  deferred-function code.
*/
mixin template Event() {
  @JSONIgnore
  Client client;

  @JSONIgnore
  VibeJSON raw;

  /**
    Array of functions to be ran when this event has completed its pass through
    the any listeners, and is ready to be destroyed.
  */
  @JSONIgnore
  EventDeferredFunc[] deferred;

  this(Client c, VibeJSON obj) {
    version (TIMING) {
      auto sw = StopWatch(AutoStart.yes);
      c.log.tracef("Starting create event for %s", this.toString);
    }

    this.raw = obj;
    this.client = c;
    this.deserializeFromJSON(obj);

    version (TIMING) {
      this.client.log.tracef("Create event for %s took %sms", this.toString,
        sw.peek().to!("msecs", real));
    }
  }

  /**
    Used to defer a functions execution until after this event has passed through
    all listeners, and is ready to be destroyed.
  */
  void defer(EventDeferredFunc f) {
    this.deferred ~= f;
  }

  /**
    Calls all deferred functions.
  */
  void resolveDeferreds() {
    foreach (ref f; this.deferred) {
      f();
    }
  }
}

/**
  Sent when we initially connect, contains base state and connection information.
*/
class Ready {
  mixin Event;

  ushort     ver;
  string     sessionID;

  @JSONSource("user")
  User       me;

  Guild[]    guilds;
  Channel[]  dms;
}

/**
  Sent when we've completed a reconnect/resume sequence.
*/
class Resumed {
  mixin Event;
}

/**
  Sent when a channel is created.
*/
class ChannelCreate {
  mixin Event;

  @JSONFlat
  Channel  channel;
}

/**
  Sent when a channel is updated.
*/
class ChannelUpdate {
  mixin Event;

  @JSONFlat
  Channel  channel;
}

/**
  Sent when a channel is deleted.
*/
class ChannelDelete {
  mixin Event;

  @JSONFlat
  Channel  channel;
}

/**
  Sent when a guild is created (often on startup).
*/
class GuildCreate {
  mixin Event;

  @JSONFlat
  Guild  guild;

  bool unavailable;
}

/**
  Sent when a guild is updated
*/
class GuildUpdate {
  mixin Event;

  @JSONFlat
  Guild  guild;
}

/**
  Sent when a guild is deleted (or becomes unavailable)
*/
class GuildDelete {
  mixin Event;

  Snowflake  guildID;
  bool       unavailable;
}

/**
  Sent when a guild ban is added.
*/
class GuildBanAdd {
  mixin Event;

  Snowflake guildID;
  User  user;
}

/**
  Sent when a guild ban is removed.
*/
class GuildBanRemove {
  mixin Event;

  Snowflake guildID;
  User  user;
}

/**
  Sent when a guilds emojis are updated.
*/
class GuildEmojisUpdate {
  mixin Event;
}

/**
  Sent when a guilds integrations are updated.
*/
class GuildIntegrationsUpdate {
  mixin Event;
}

/**
  Sent in response to RequestGuildMembers.
*/

class GuildMembersChunk {
  mixin Event;

  Snowflake guildID;
  GuildMember[] members;

/+
  void load(JSONDecoder obj) {
    obj.keySwitch!("guild_id", "members")(
      { this.guildID = readSnowflake(obj); },
      { loadMany!GuildMember(this.client, obj, (m) { this.members ~= m; }); },
    );

    auto guild = this.client.state.guilds.get(this.guildID);
    foreach (member; this.members) {
      member.guild = guild;
    }
  }
+/
}

/**
  Sent when a member is added to a guild.
*/
class GuildMemberAdd {
  mixin Event;

  @JSONFlat
  GuildMember  member;
}

/**
  Sent when a member is removed from a guild.
*/
class GuildMemberRemove {
  mixin Event;

  Snowflake  guildID;
  User       user;
}

/**
  Sent when a guild member is updated.
*/
class GuildMemberUpdate {
  mixin Event;

  @JSONFlat
  GuildMember  member;
}

/**
  Sent when a guild role is created.
*/
class GuildRoleCreate {
  mixin Event;

  Snowflake  guildID;
  Role       role;
}

/**
  Sent when a guild role is updated.
*/
class GuildRoleUpdate {
  mixin Event;

  Snowflake  guildID;
  Role       role;
}

/**
  Sent when a guild role is deleted.
*/
class GuildRoleDelete {
  mixin Event;

  Snowflake  guildID;
  Role       role;
}

/**
  Sent when a message is created.
*/
class MessageCreate {
  mixin Event;

  @JSONFlat
  Message  message;

  // Reference to the command event
  @JSONIgnore
  CommandEvent commandEvent;
}

/**
  Sent when a message is updated.
*/
class MessageUpdate {
  mixin Event;

  @JSONFlat
  Message  message;
}

/**
  Sent when a message is deleted.
*/
class MessageDelete {
  mixin Event;

  Snowflake  id;
  Snowflake  channelID;
}

/**
  Sent when a users presence is updated.
*/
class PresenceUpdate {
  mixin Event;

  @JSONFlat
  Presence presence;
}

/**
  Sent when a user starts typing.
*/
class TypingStart {
  mixin Event;

  Snowflake  channelID;
  Snowflake  userID;
  ulong      timestamp;
}

/**
  Sent when this users settings are updated.
*/
class UserSettingsUpdate {
  mixin Event;
}

/**
  Sent when this user is updated.
*/
class UserUpdate {
  mixin Event;
}

/**
  Sent when a voice state is updated.
*/
class VoiceStateUpdate {
  mixin Event;

  @JSONFlat
  VoiceState  state;
}

/**
  Sent when a voice server is updated.
*/
class VoiceServerUpdate {
  mixin Event;

  string     token;
  string     endpoint;
  Snowflake  guildID;
}

/**
  Sent when a channels pins are updated.
*/
class ChannelPinsUpdate {
  mixin Event;

  Snowflake  channelID;
  string     lastPinTimestamp;
}

/**
  Sent when a bulk set of messages gets deleted from a channel.
*/
class MessageDeleteBulk {
  mixin Event;

  Snowflake channelID;
  Snowflake[] ids;
}
