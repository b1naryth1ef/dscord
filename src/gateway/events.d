module gateway.events;

import std.variant,
       std.stdio,
       std.algorithm;

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

