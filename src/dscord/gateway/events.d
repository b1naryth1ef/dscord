module dscord.gateway.events;

import std.variant,
       std.algorithm,
       std.string,
       std.stdio;

import dscord.gateway.client,
       dscord.gateway.packets,
       dscord.types.all;

class Event {
  Client client;
  JSONObject payload;

  this(Client c, DispatchPacket d) {
    this.client = c;
    this.payload = d.data;
    this.client.log.tracef("Creating event %s with data: %s", this.toString, this.payload.dumps());
  }
}

class Ready : Event {
  ushort      ver;
  uint        heartbeat_interval;
  string      session_id;
  User        me;
  Channel[]   dms;
  Guild[]     guilds;

  this(Client c, DispatchPacket d) {
    super(c, d);

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

class Resumed : Event {
  this(Client c, DispatchPacket d) {
    super(c, d);
  }
}

class ChannelCreate : Event {
  Channel  channel;

  this(Client c, DispatchPacket d) {
    super(c, d);
    this.channel = new Channel(this.client, d.data);
  }
}

class ChannelUpdate : Event {
  Channel  channel;

  this(Client c, DispatchPacket d) {
    super(c, d);
    this.channel = new Channel(this.client, d.data);
  }
}

class ChannelDelete : Event {
  Channel  channel;

  this(Client c, DispatchPacket d) {
    super(c, d);
    this.channel = new Channel(this.client, d.data);
  }
}

class GuildCreate : Event {
  Guild  guild;
  bool   isNew;
  bool   unavailable;

  this(Client c, DispatchPacket d) {
    super(c, d);
    this.guild = new Guild(this.client, d.data);

    if (d.data.has("unavailable")) {
      this.unavailable = d.data.get!bool("unavailable");
    } else {
      this.isNew = true;
    }
  }
}

class GuildUpdate : Event {
  Guild  guild;

  this(Client c, DispatchPacket d) {
    super(c, d);
    this.guild = new Guild(this.client, d.data);
  }
}

class GuildDelete : Event {
  Snowflake  guild_id;
  bool       unavailable;

  this (Client c, DispatchPacket d) {
    super(c, d);
    this.guild_id = d.data.get!Snowflake("id");
    if (d.data.has("unavailable")) {
      this.unavailable = d.data.get!bool("unavailable");
    }
  }
}

class GuildBanAdd : Event {
  User  user;

  this(Client c, DispatchPacket d) {
    super(c, d);
    // this.user = new User(this.client, d.data);
  }
}

class GuildBanRemove : Event {
  User  user;

  this(Client c, DispatchPacket d) {
    super(c, d);
    // this.user = new User(this.client, d.data);
  }
}

class GuildEmojisUpdate : Event {
  // TODO
  this(Client c, DispatchPacket d) {
    super(c, d);
  }
}

class GuildIntegrationsUpdate : Event {
  // TODO
  this(Client c, DispatchPacket d) {
    super(c, d);
  }
}

class GuildMemberAdd : Event {
  GuildMember  member;

  this (Client c, DispatchPacket d) {
    super(c, d);
    this.member = new GuildMember(this.client, d.data);
  }
}

class GuildMemberRemove : Event {
  Snowflake  guild_id;
  User       user;

  this (Client c, DispatchPacket d) {
    super(c, d);
    this.guild_id = d.data.get!Snowflake("guild_id");
    this.user = new User(this.client, d.data.get!JSONObject("user"));
  }
}

class GuildMemberUpdate : Event {
  Snowflake  guild_id;
  User       user;
  Role[]     roles;

  this (Client c, DispatchPacket d) {
    super(c, d);
    this.guild_id = d.data.get!Snowflake("guild_id");
    this.user = new User(this.client, d.data.get!JSONObject("user"));
    // TODO: roles
  }
}

class GuildRoleCreate : Event {
  Snowflake  guild_id;
  Role       role;

  this (Client c, DispatchPacket d) {
    super(c, d);
    this.guild_id = d.data.get!Snowflake("guild_id");
    this.role = new Role(this.client, d.data.get!JSONObject("role"));
  }
}

class GuildRoleUpdate : Event {
  Snowflake  guild_id;
  Role       role;

  this (Client c, DispatchPacket d) {
    super(c, d);
    this.guild_id = d.data.get!Snowflake("guild_id");
    this.role = new Role(this.client, d.data.get!JSONObject("role"));
  }
}

class GuildRoleDelete : Event {
  Snowflake  guild_id;
  Role       role;

  this (Client c, DispatchPacket d) {
    super(c, d);
    this.guild_id = d.data.get!Snowflake("guild_id");
    // this.role = new Role(this.client, d.data.get!JSONObject("role"));
  }
}

class MessageCreate : Event {
  Message  message;

  this (Client c, DispatchPacket d) {
    super(c, d);
    this.message = new Message(this.client, d.data);
  }
}

class MessageUpdate : Event {
  Message message;

  this (Client c, DispatchPacket d) {
    super(c, d);
    this.message = new Message(this.client, d.data);
  }
}

class MessageDelete : Event {
  Snowflake  id;
  Snowflake  channel_id;

  this (Client c, DispatchPacket d) {
    super(c, d);
    this.id = d.data.get!Snowflake("id");
    this.channel_id = d.data.get!Snowflake("channel_id");
  }
}

class PresenceUpdate : Event {
  User         user;
  Snowflake    guild_id;
  Snowflake[]  roles;
  string       game;
  string       status;

  this (Client c, DispatchPacket d) {
    super(c, d);
    // TODO: this lol
  }
}

class TypingStart : Event {
  Snowflake  channel_id;
  Snowflake  user_id;
  string     timestamp;

  this(Client c, DispatchPacket d) {
    super(c, d);
    this.channel_id = d.data.get!Snowflake("channel_id");
    this.user_id = d.data.get!Snowflake("user_id");
    this.timestamp = d.data.get!string("timestamp");
  }
}

class UserSettingsUpdate : Event {
  this(Client c, DispatchPacket d) {
    // TODO
    super(c, d);
  }
}

class UserUpdate : Event {
  this(Client c, DispatchPacket d) {
    // TODO
    super(c, d);
  }
}

class VoiceStateUpdate : Event {
  VoiceState  state;

  this(Client c, DispatchPacket d) {
    super(c, d);
    this.state = new VoiceState(c, d.data);
  }
}

class VoiceServerUpdate : Event {
  string     token;
  string     endpoint;
  Snowflake  guild_id;

  this(Client c, DispatchPacket d) {
    super(c, d);
    this.token = d.data.get!string("token");
    this.endpoint = d.data.get!string("endpoint");
    this.guild_id = d.data.get!Snowflake("guild_id");
  }
}
