module dscord.gateway.events;

import std.variant,
       std.stdio,
       std.algorithm,
       std.string;

import dscord.gateway.client,
       dscord.gateway.packets,
       dscord.types.all;

class Event {
  Client client;
  JSONObject payload;

  this(Client c, Dispatch d) {
    this.client = c;
    this.payload = d.data;
  }
}

// authors note: pretty sure I'm high as fuck right now
string eventName(string clsName) {
  string[] parts;

  string piece = "";
  foreach (chr; clsName) {
    if (chr == chr.toUpper && piece.length > 0) {
      parts ~= piece;
      piece = "";
      piece ~= chr;
    } else {
      piece ~= chr;
    }
  }

  parts ~= piece;
  return join(parts, "_").toUpper;
}

class Ready : Event {
  ushort      ver;
  uint        heartbeat_interval;
  string      session_id;
  User        me;
  Channel[]   dms;
  Guild[]     guilds;

  this(Client c, Dispatch d) {
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

class ChannelCreate : Event {
  Channel  channel;

  this(Client c, Dispatch d) {
    super(c, d);
    this.channel = new Channel(this.client, d.data);
  }
}

class ChannelUpdate : Event {
  Channel  channel;

  this(Client c, Dispatch d) {
    super(c, d);
    this.channel = new Channel(this.client, d.data);
  }
}

class ChannelDelete : Event {
  Channel  channel;

  this(Client c, Dispatch d) {
    super(c, d);
    this.channel = new Channel(this.client, d.data);
  }
}

class GuildCreate : Event {
  Guild  guild;
  bool   isNew;
  bool   unavailable;

  this(Client c, Dispatch d) {
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

  this(Client c, Dispatch d) {
    super(c, d);
    this.guild = new Guild(this.client, d.data);
  }
}

class GuildDelete : Event {
  Snowflake  guild_id;
  bool       unavailable;

  this (Client c, Dispatch d) {
    super(c, d);
    this.guild_id = d.data.get!Snowflake("id");
    if (d.data.has("unavailable")) {
      this.unavailable = d.data.get!bool("unavailable");
    }
  }
}

class GuildMemberAdd : Event {
  GuildMember  member;

  this (Client c, Dispatch d) {
    super(c, d);
    this.member = new GuildMember(this.client, d.data);
  }
}

class MessageCreate : Event {
  Message  message;

  this (Client c, Dispatch d) {
    super(c, d);
    this.message = new Message(this.client, d.data);
  }
}

class MessageUpdate : Event {
  Message message;

  this (Client c, Dispatch d) {
    super(c, d);
    this.message = new Message(this.client, d.data);
  }
}

class MessageDelete : Event {
  Snowflake  id;
  Snowflake  channel_id;

  this (Client c, Dispatch d) {
    super(c, d);
    this.id = d.data.get!Snowflake("id");
    this.channel_id = d.data.get!Snowflake("channel_id");
  }
}
