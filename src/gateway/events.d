module gateway.events;

import std.variant,
       std.stdio,
       std.algorithm,
       std.string;

import gateway.client,
       gateway.packets,
       types.guild,
       types.channel,
       types.user,
       util.json;

class Event {
  GatewayClient gc;

  this(GatewayClient gc) {
    this.gc = gc;
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

  this(GatewayClient gc, Dispatch d) {
    super(gc);

    this.ver = d.data.get!ushort("v");
    this.heartbeat_interval = d.data.get!uint("heartbeat_interval");
    this.session_id = d.data.get!string("session_id");
    this.me = new User(d.data.get!JSONObject("user"));

    foreach (Variant gobj; d.data.getRaw("guilds")) {
      this.guilds ~= new Guild(new JSONObject(variantToJSON(gobj)));
    }

    // TODO: dms
  }
}

class ChannelCreate : Event {
  Channel  chan;

  this(GatewayClient gc, Dispatch d) {
    super(gc);
    this.chan = new Channel(d.data);
  }
}

class ChannelUpdate : Event {
  Channel  chan;

  this(GatewayClient gc, Dispatch d) {
    super(gc);
    this.chan = new Channel(d.data);
  }
}

class ChannelDelete : Event {
  Channel  chan;

  this(GatewayClient gc, Dispatch d) {
    super(gc);
    this.chan = new Channel(d.data);
  }
}

class GuildCreate : Event {
  Guild  guild;
  bool   isNew;
  bool   unavailable;

  this(GatewayClient gc, Dispatch d) {
    super(gc);
    this.guild = new Guild(d.data);

    if (d.data.has("unavailable")) {
      this.unavailable = d.data.get!bool("unavailable");
    } else {
      this.isNew = true;
    }
  }
}
