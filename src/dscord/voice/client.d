module dscord.voice.client;

import core.time,
       core.stdc.time,
       std.stdio,
       std.zlib,
       std.functional,
       std.array;

import vibe.core.core,
       vibe.inet.url,
       vibe.http.websockets;

import dscord.client,
       dscord.gateway.packets,
       dscord.gateway.events,
       dscord.voice.packets,
       dscord.types.all,
       dscord.util.emitter,
       dscord.util.json;

// TODO: timeout if we didn't get a VOICE_SERVER_UPDATE

class VoiceClient {
  // Global client
  Client     client;

  // Voice channel we're for
  Channel    channel;

  // Packet emitter
  Emitter  packetEmitter;

  private {
    Logger  log;

    // Voice websocket
    WebSocket  sock;

    // Heartbeater task
    Task  heartbeater;

    // Listener for VOICE_SERVER_UPDATE events
    Listener  l;

    // Various connection attributes
    string  token;
    URL     endpoint;
    bool    connected = false;
    ushort  ssrc;
    ushort  port;
    ushort  heartbeat_interval;
    bool    mute;
    bool    deaf;
  }

  this(Channel c, bool mute=false, bool deaf=false) {
    this.channel = c;
    this.client = c.client;
    this.log = this.client.log;
    this.mute = mute;
    this.deaf = deaf;

    this.packetEmitter = new Emitter;
    this.packetEmitter.listen!VoiceReadyPacket(toDelegate(&this.handleVoiceReadyPacket));
  }

  void handleVoiceReadyPacket(VoiceReadyPacket p) {
    this.log.trace("Got VoiceReadyPacket");
    this.ssrc = p.ssrc;
    this.port = p.port;
    this.heartbeat_interval = p.heartbeat_interval;
    this.heartbeater = runTask(toDelegate(&this.heartbeat));
    // TODO: udp connect
  }

  void heartbeat() {
    while (this.connected) {
      time_t unixTime = core.stdc.time.time(null);
      this.send(new VoiceHeartbeatPacket(cast(uint)(unixTime * 1000)));
      sleep(this.heartbeat_interval.msecs);
    }
  }

  void dispatch(JSONObject obj) {
    this.log.trace("voice-dispatch: %s", obj.get!VoiceOPCode("op"));

    switch (obj.get!VoiceOPCode("op")) {
      case VoiceOPCode.VOICE_READY:
        this.packetEmitter.emit!VoiceReadyPacket(new VoiceReadyPacket(obj));
        break;
      default:
        break;
    }
  }

  void send(Serializable p) {
    JSONObject data = p.serialize();
    this.log.trace("voice-send: %s", data.dumps());
    this.sock.send(data.dumps());
  }

  void run() {
    string data;

    while (this.sock.waitForData()) {
      // Not possible to recv compressed data on the voice ws right now, but lets future guard
      try {
        ubyte[] rawdata = this.sock.receiveBinary();
        data = cast(string)uncompress(rawdata);
      } catch (Exception e) {
        data = this.sock.receiveText();
      }

      if (data == "") {
        continue;
      }

      try {
        this.dispatch(new JSONObject(data));
      } catch (Exception e) {
        this.log.warning("failed to handle voice dispatch: %s (%s)", e, data);
      }
    }
  }

  void onVoiceServerUpdate(VoiceServerUpdate event) {
    if (this.channel.guild_id != event.guild_id) {
      return;
    }

    // TODO: handle server moving
    this.token = event.token;
    this.connected = true;

    // Grab endpoint and create a proper URL out of it
    this.endpoint = URL("wss", event.endpoint.split(":")[0], 0, Path());
    this.sock = connectWebSocket(this.endpoint);
    runTask(toDelegate(&this.run));

    // Send identify
    this.send(new VoiceIdentifyPacket(
      this.channel.guild_id,
      this.client.state.me.id,
      this.client.gw.session_id,
      this.token
    ));
  }

  void connect() {
    this.l = this.client.gw.eventEmitter.listen!VoiceServerUpdate(toDelegate(
      &this.onVoiceServerUpdate));

    this.client.gw.send(new VoiceStateUpdatePacket(
      this.channel.guild_id,
      this.channel.id,
      this.mute,
      this.deaf
   ));
  }

  void disconnect() {
    this.l.unbind();
    this.client.gw.send(new VoiceStateUpdatePacket(
      this.channel.guild_id,
      0, // TODO
      this.mute,
      this.deaf
    ));
  }
}
