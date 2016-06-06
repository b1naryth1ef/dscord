module dscord.gateway.events;

import std.variant,
       std.algorithm,
       std.string,
       std.stdio,
       std.datetime;

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

class ReadyEvent {
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
      { obj.skipValue(); /* TODO */ },
      { obj.skipValue(); /* TODO */ },
    );
  }
}


mixin template NewEvent() {
  Client client;

  this(Client c, DispatchPacket d) {
    debug {
      auto sw = StopWatch(AutoStart.yes);
    }

    this.client = c;
    this.load(d);
    debug {
      this.client.log.tracef("Create event for %s took %sms", this.toString,
        sw.peek().to!("msecs", real));
    }
  }
}

class Ready : BaseEvent {
  mixin NewEvent;

  ushort      ver;
  uint        heartbeat_interval;
  string      session_id;
  User        me;
  Channel[]   dms;
  Guild[]     guilds;

  void load(DispatchPacket d) {
    this.ver = d.data.get!ushort("v");
    this.heartbeat_interval = d.data.get!uint("heartbeat_interval");
    this.session_id = d.data.get!string("session_id");
    this.me = new User(this.client, d.data.get!JSONObject("user"));

    foreach (Variant gobj; d.data.getRaw("guilds")) {
      this.guilds ~= new Guild(this.client, new JSONObject(variantToJSON(gobj)));
    }

    // TODO: dms
  }
}

class Resumed : BaseEvent {
  mixin NewEvent;

  void load(DispatchPacket d) {}
}

class ChannelCreate : BaseEvent {
  mixin NewEvent;

  Channel  channel;

  void load(DispatchPacket d) {
    this.channel = new Channel(this.client, d.data);
  }
}

class ChannelUpdate : BaseEvent {
  mixin NewEvent;

  Channel  channel;

  void load(DispatchPacket d) {
    this.channel = new Channel(this.client, d.data);
  }
}

class ChannelDelete : BaseEvent {
  mixin NewEvent;

  Channel  channel;

  void load(DispatchPacket d) {
    this.channel = new Channel(this.client, d.data);
  }
}

class GuildCreate : BaseEvent {
  mixin NewEvent;

  Guild  guild;
  bool   unavailable;
  bool   created;

  void load(DispatchPacket d) {
    this.guild = new Guild(this.client, d.data);

    if (d.data.has("unavailable")) {
      this.unavailable = d.data.get!bool("unavailable");
    } else {
      this.created = true;
    }
  }
}

class GuildUpdate : BaseEvent {
  mixin NewEvent;

  Guild  guild;

  void load(DispatchPacket d) {
    this.guild = new Guild(this.client, d.data);
  }
}

class GuildDelete : BaseEvent {
  mixin NewEvent;

  Snowflake  guild_id;
  bool       unavailable;

  void load(DispatchPacket d) {
    this.guild_id = d.data.get!Snowflake("id");
    if (d.data.has("unavailable")) {
      this.unavailable = d.data.get!bool("unavailable");
    }
  }
}

class GuildBanAdd : BaseEvent {
  mixin NewEvent;

  User  user;

  void load(DispatchPacket d) {
    // this.user = new User(this.client, d.data);
  }
}

class GuildBanRemove : BaseEvent {
  mixin NewEvent;

  User  user;

  void load(DispatchPacket d) {
    // this.user = new User(this.client, d.data);
  }
}

class GuildEmojisUpdate : BaseEvent {
  mixin NewEvent;

  void load(DispatchPacket d) {}
}

class GuildIntegrationsUpdate : BaseEvent {
  mixin NewEvent;

  void load(DispatchPacket d) {}
}

class GuildMemberAdd : BaseEvent {
  mixin NewEvent;

  GuildMember  member;

  void load(DispatchPacket d) {
    this.member = new GuildMember(this.client, d.data);
  }
}

class GuildMemberRemove : BaseEvent {
  mixin NewEvent;

  Snowflake  guild_id;
  User       user;

  void load(DispatchPacket d) {
    this.guild_id = d.data.get!Snowflake("guild_id");
    this.user = new User(this.client, d.data.get!JSONObject("user"));
  }
}

class GuildMemberUpdate : BaseEvent {
  mixin NewEvent;

  Snowflake  guild_id;
  User       user;
  Role[]     roles;

  void load(DispatchPacket d) {
    this.guild_id = d.data.get!Snowflake("guild_id");
    this.user = new User(this.client, d.data.get!JSONObject("user"));
    // TODO: roles
  }
}

class GuildRoleCreate : BaseEvent {
  mixin NewEvent;

  Snowflake  guild_id;
  Role       role;

  void load(DispatchPacket d) {
    this.guild_id = d.data.get!Snowflake("guild_id");
    auto guild = this.client.state.guilds.get(this.guild_id);
    this.role = new Role(guild, d.data.get!JSONObject("role"));
  }
}

class GuildRoleUpdate : BaseEvent {
  mixin NewEvent;

  Snowflake  guild_id;
  Role       role;

  void load(DispatchPacket d) {
    this.guild_id = d.data.get!Snowflake("guild_id");
    auto guild = this.client.state.guilds.get(this.guild_id);
    this.role = new Role(guild, d.data.get!JSONObject("role"));
  }
}

class GuildRoleDelete : BaseEvent {
  mixin NewEvent;

  Snowflake  guild_id;
  Role       role;

  void load(DispatchPacket d) {
    this.guild_id = d.data.get!Snowflake("guild_id");
    // this.role = new Role(this.client, d.data.get!JSONObject("role"));
  }
}

class MessageCreate : BaseEvent {
  mixin NewEvent;

  Message  message;

  void load(DispatchPacket d) {
    this.message = new Message(this.client, d.data);
  }
}

class MessageUpdate : BaseEvent {
  mixin NewEvent;

  Message message;

  void load(DispatchPacket d) {
    this.message = new Message(this.client, d.data);
  }
}

class MessageDelete : BaseEvent {
  mixin NewEvent;

  Snowflake  id;
  Snowflake  channel_id;

  void load(DispatchPacket d) {
    this.id = d.data.get!Snowflake("id");
    this.channel_id = d.data.get!Snowflake("channel_id");
  }
}

class PresenceUpdate : BaseEvent {
  mixin NewEvent;

  User         user;
  Snowflake    guild_id;
  Snowflake[]  roles;
  string       game;
  string       status;

  void load(DispatchPacket d) {}
}

class TypingStart : BaseEvent {
  mixin NewEvent;

  Snowflake  channel_id;
  Snowflake  user_id;
  string     timestamp;

  void load(DispatchPacket d) {
    this.channel_id = d.data.get!Snowflake("channel_id");
    this.user_id = d.data.get!Snowflake("user_id");
    this.timestamp = d.data.get!string("timestamp");
  }
}

class UserSettingsUpdate : BaseEvent {
  mixin NewEvent;

  void load(DispatchPacket d) {}
}

class UserUpdate : BaseEvent {
  mixin NewEvent;

  void load(DispatchPacket d) {}
}

class VoiceStateUpdate : BaseEvent {
  mixin NewEvent;

  VoiceState  state;

  void load(DispatchPacket d) {
    this.state = new VoiceState(this.client, d.data);
  }
}

class VoiceServerUpdate : BaseEvent {
  mixin NewEvent;

  string     token;
  string     endpoint;
  Snowflake  guild_id;

  void load(DispatchPacket d) {
    this.token = d.data.get!string("token");
    this.endpoint = d.data.get!string("endpoint");
    this.guild_id = d.data.get!Snowflake("guild_id");
  }
}
