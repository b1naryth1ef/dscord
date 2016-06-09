module dscord.gateway.events;

import std.algorithm,
       std.string,
       std.stdio,
       std.datetime,
       std.array,
       std.conv;

import dscord.gateway.client,
       dscord.gateway.packets,
       dscord.types.all;

interface BaseEvent {
  void load(DispatchPacket);
}

mixin template Event() {
  Client client;

  this(Client c, ref JSON obj) {
    debug {
      auto sw = StopWatch(AutoStart.yes);
    }

    this.client = c;
    this.load(obj);

    debug {
      this.client.log.tracef("Create event for %s took %sms", this.toString,
        sw.peek().to!("msecs", real));
    }
  }
}

class Ready {
  mixin Event;

  ushort     ver;
  uint       heartbeatInterval;
  string     sessionID;
  User       me;
  Guild[]    guilds;
  Channel[]  dms;

  void load(ref JSON obj) {
    obj.keySwitch!("v", "heartbeat_interval", "session_id", "user", "guilds")(
      { this.ver = obj.read!ushort; },
      { this.heartbeatInterval = obj.read!uint; },
      { this.sessionID = obj.read!string; },
      { this.me = new User(this.client, obj); },
      { loadMany!Guild(this.client, obj, (g) { this.guilds ~= g; }); },
    );
  }
}

class Resumed {
  mixin Event;

  void load(ref JSON obj) {}
}

class ChannelCreate {
  mixin Event;

  Channel  channel;

  void load(ref JSON obj) {
    this.channel = new Channel(this.client, obj);
  }
}

class ChannelUpdate {
  mixin Event;

  Channel  channel;

  void load(ref JSON obj) {
    this.channel = new Channel(this.client, obj);
  }
}

class ChannelDelete {
  mixin Event;

  Channel  channel;

  void load(ref JSON obj) {
    this.channel = new Channel(this.client, obj);
  }
}

class GuildCreate {
  mixin Event;

  Guild  guild;

  void load(ref JSON obj) {
    this.guild = new Guild(this.client, obj);
  }
}

class GuildUpdate {
  mixin Event;

  Guild  guild;

  void load(ref JSON obj) {
    this.guild = new Guild(this.client, obj);
  }
}

class GuildDelete {
  mixin Event;

  Snowflake  guildID;
  bool       unavailable;

  void load(ref JSON obj) {
    obj.keySwitch!("guild_id", "unavailable")(
      { this.guildID = readSnowflake(obj); },
      { this.unavailable = obj.read!bool; },
    );
  }
}

class GuildBanAdd {
  mixin Event;

  User  user;

  void load(ref JSON obj) {
    this.user = new User(this.client, obj);
  }
}

class GuildBanRemove {
  mixin Event;

  User  user;

  void load(ref JSON obj) {
    this.user = new User(this.client, obj);
  }
}

class GuildEmojisUpdate {
  mixin Event;

  void load(ref JSON obj) {}
}

class GuildIntegrationsUpdate {
  mixin Event;

  void load(ref JSON obj) {}
}

class GuildMemberAdd {
  mixin Event;

  GuildMember  member;

  void load(ref JSON obj) {
    this.member = new GuildMember(this.client, obj);
  }
}

class GuildMemberRemove {
  mixin Event;

  Snowflake  guildID;
  User       user;

  void load(ref JSON obj) {
    obj.keySwitch!("guild_id", "user")(
      { this.guildID = readSnowflake(obj); },
      { this.user = new User(this.client, obj); },
    );
  }
}

class GuildMemberUpdate {
  mixin Event;

  Snowflake  guildID;
  User       user;
  Role[]     roles;

  void load(ref JSON obj) {
    obj.keySwitch!("guild_id", "user", "roles")(
      { this.guildID = readSnowflake(obj); },
      { this.user = new User(this.client, obj); },
      { loadMany!Role(this.client, obj, (r) { this.roles ~= r; }); },
    );

    // Update guild roles TODO: make this safe
    auto guild = this.client.state.guilds.get(this.guildID);
    foreach (role; this.roles) {
      role.guild = guild;
    }
  }
}

class GuildRoleCreate {
  mixin Event;

  Snowflake  guildID;
  Role       role;

  void load(ref JSON obj) {
    obj.keySwitch!("guild_id", "role")(
      { this.guildID = readSnowflake(obj); },
      { this.role = new Role(this.client, obj); },
    );
  }
}

class GuildRoleUpdate {
  mixin Event;

  Snowflake  guildID;
  Role       role;

  void load(ref JSON obj) {
    obj.keySwitch!("guild_id", "role")(
      { this.guildID = readSnowflake(obj); },
      { this.role = new Role(this.client, obj); },
    );
  }
}

class GuildRoleDelete {
  mixin Event;

  Snowflake  guildID;
  Role       role;

  void load(ref JSON obj) {
    obj.keySwitch!("guild_id", "role")(
      { this.guildID = readSnowflake(obj); },
      { this.role = new Role(this.client, obj); },
    );
  }
}

class MessageCreate {
  mixin Event;

  Message  message;

  void load(ref JSON obj) {
    this.message = new Message(this.client, obj);
  }
}

class MessageUpdate {
  mixin Event;

  Message  message;

  void load(ref JSON obj) {
    this.message = new Message(this.client, obj);
  }
}

class MessageDelete {
  mixin Event;

  Snowflake  id;
  Snowflake  channelID;

  void load(ref JSON obj) {
    obj.keySwitch!("id", "channel_id")(
      { this.id = readSnowflake(obj); },
      { this.channelID = readSnowflake(obj); },
    );
  }
}

class PresenceUpdate {
  mixin Event;

  User         user;
  Snowflake    guildID;
  Snowflake[]  roles;
  string       game;
  string       status;

  void load(ref JSON obj) {
    obj.keySwitch!("user", "guild_id", "roles", "game", "status")(
      { this.user = new User(this.client, obj); },
      { this.guildID = readSnowflake(obj); },
      { this.roles = obj.read!(string[]).map!((c) => c.to!Snowflake).array; },
      { this.game = obj.read!string; },
      { this.status = obj.read!string; },
    );
  }
}

class TypingStart {
  mixin Event;

  Snowflake  channelID;
  Snowflake  userID;
  ulong      timestamp;

  void load(ref JSON obj) {
    obj.keySwitch!("channel_id", "user_id", "timestamp")(
      { this.channelID = readSnowflake(obj); },
      { this.userID = readSnowflake(obj); },
      { this.timestamp = obj.read!ulong; },
    );
  }
}

class UserSettingsUpdate {
  mixin Event;

  void load(ref JSON obj) {};
}

class UserUpdate {
  mixin Event;

  void load(ref JSON obj) {};
}

class VoiceStateUpdate {
  mixin Event;

  VoiceState  state;

  void load(ref JSON obj) {
    this.state = new VoiceState(this.client, obj);
  }
}

class VoiceServerUpdate {
  mixin Event;

  string     token;
  string     endpoint;
  Snowflake  guildID;

  void load(ref JSON obj) {
    obj.keySwitch!("token", "endpoint", "guild_id")(
      { this.token = obj.read!string; },
      { this.endpoint = obj.read!string; },
      { this.guildID = readSnowflake(obj); },
    );
  }
}
