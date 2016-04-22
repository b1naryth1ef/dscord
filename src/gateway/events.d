module gateway.events;

import std.variant,
       std.stdio,
       std.algorithm,
       std.string;

import client,
       gateway.client,
       gateway.packets,
       types.base,
       types.guild,
       types.channel,
       types.user,
       util.json;

class Event {
  Client c;

  this(Client c) {
    this.c = c;
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
    super(c);

    this.ver = d.data.get!ushort("v");
    this.heartbeat_interval = d.data.get!uint("heartbeat_interval");
    this.session_id = d.data.get!string("session_id");
    this.me = new User(this.c, d.data.get!JSONObject("user"));

    foreach (Variant gobj; d.data.getRaw("guilds")) {
      this.guilds ~= new Guild(this.c, new JSONObject(variantToJSON(gobj)));
    }

    // TODO: dms
  }
}

class ChannelCreate : Event {
  Channel  chan;

  this(Client c, Dispatch d) {
    super(c);
    this.chan = new Channel(this.c, d.data);
  }
}

class ChannelUpdate : Event {
  Channel  chan;

  this(Client c, Dispatch d) {
    super(c);
    this.chan = new Channel(this.c, d.data);
  }
}

class ChannelDelete : Event {
  Channel  chan;

  this(Client c, Dispatch d) {
    super(c);
    this.chan = new Channel(this.c, d.data);
  }
}

class GuildCreate : Event {
  Guild  guild;
  bool   isNew;
  bool   unavailable;

  this(Client c, Dispatch d) {
    super(c);
    this.guild = new Guild(this.c, d.data);

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
    super(c);
    this.guild = new Guild(this.c, d.data);
  }
}

class GuildDelete : Event {
  Snowflake  guild_id;
  bool       unavailable;

  this (Client c, Dispatch d) {
    super(c);
    this.guild_id = d.data.get!Snowflake("id");
    if (d.data.has("unavailable")) {
      this.unavailable = d.data.get!bool("unavailable");
    }
  }
}

class GuildMemberAdd : Event {
  GuildMember  member;

  this (Client c, Dispatch d) {
    super(c);
    this.member = new GuildMember(this.c, d.data);
  }
}
