module dscord.gateway.client;

import std.stdio,
       std.uni,
       std.functional,
       std.zlib,
       std.datetime;

import vibe.core.core,
       vibe.inet.url,
       vibe.http.websockets;

import dscord.client,
       dscord.gateway.packets,
       dscord.gateway.events,
       dscord.util.json;

alias GatewayPacketHandler = void delegate (BasePacket);
alias GatewayEventHandler = void delegate (Dispatch);

class GatewayClient {
  Client     client;
  WebSocket  sock;

  private {
    uint seq;
    uint hb_interval;
  }

  GatewayPacketHandler[][OPCode] gatewayPacketHandlers;
  GatewayEventHandler[][string] gatewayEventHandlers;

  this(Client client) {
    this.client = client;
    this.sock = connectWebSocket(URL(client.api.gateway()));

    // Handle DISPATCH events
    this.onPacket!Dispatch(OPCode.DISPATCH, toDelegate(&this.handleDispatchPacket));
    this.onEvent!Ready(toDelegate(&this.handleReadyEvent));
  }

  void start() {
    // Start the main task
    runTask(toDelegate(&this.run));
  }

  void onPacket(T)(OPCode code, void delegate (T o) cb) {
    this.gatewayPacketHandlers[code] ~= (BasePacket p) {
      auto inner = new T;
      inner.deserialize(p.raw);
      cb(inner);
    };
  }

  void send(Serializable p) {
    JSONObject data = p.serialize();
    this.sock.send(data.dumps());
  }

  void onEvent(T)(void delegate (T o) cb) {
    this.gatewayEventHandlers[eventName(T.stringof)] ~= (Dispatch d) {
      cb(new T(this.client, d));
    };
  }

  void handleReadyEvent(Ready r) {
    this.hb_interval = r.heartbeat_interval;
    runTask(toDelegate(&this.heartbeat));
  }

  void handleDispatchPacket(Dispatch d) {
    // Update sequence number if it's larger than what we have
    if (d.seq > this.seq) {
      this.seq = d.seq;
    }

    if (!(d.event in this.gatewayEventHandlers)) {
      return;
    }

    // Handle callbacks for the event
    foreach (cb; this.gatewayEventHandlers[d.event]) {
      cb(d);
    }
  }

  void dispatch(JSONObject obj) {
    BasePacket base = new BasePacket();
    base.deserialize(obj);

    foreach (cb; this.gatewayPacketHandlers[base.op]) {
      cb(base);
    }
  }

  void heartbeat() {
    while (true) {
      this.send(new Heartbeat(this.seq));
      sleep(this.hb_interval.msecs);
      writeln("HEARTBEAT");
    }
  }

  void run() {
    string data;

    // On startup, send the identify payload
    this.send(new Identify(this.client.token));

    while (this.sock.waitForData()) {
      try {
        ubyte[] rawdata = this.sock.receiveBinary();
        data = cast(string)uncompress(rawdata);
      } catch (Exception e) {
        data = this.sock.receiveText();
      }

      if (data == "") {
        continue;
      }

      // writefln("RECV: %s", data);

      try {
        this.dispatch(new JSONObject(data));
      } catch (Exception e) {
        writefln("Failed to handle: %s (%s)", e, data);
      }
    }
  }
}
