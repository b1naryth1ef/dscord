module dscord.voice.client;

import core.time,
       core.stdc.time,
       std.stdio,
       std.zlib,
       std.functional,
       std.array,
       std.stdio,
       std.bitmanip,
       std.outbuffer,
       std.string;

import vibe.core.core,
       vibe.core.net,
       vibe.inet.url,
       vibe.http.websockets;

import dcad.types : DCAFile;

import dscord.client,
       dscord.gateway.packets,
       dscord.gateway.events,
       dscord.voice.packets,
       dscord.types.all,
       dscord.util.emitter,
       dscord.util.json;

struct RTPHeader {
  ushort  seq;
  uint    ts;
  uint    ssrc;

  this(ushort seq, uint ts, uint ssrc) {
    this.seq = seq;
    this.ts = ts;
    this.ssrc = ssrc;
  }

  ubyte[] pack() {
    OutBuffer b = new OutBuffer();
    b.write('\x80');
    b.write('\x78');
    b.write(nativeToBigEndian(this.seq));
    b.write(nativeToBigEndian(this.ts));
    b.write(nativeToBigEndian(this.ssrc));
    return b.toBytes;
  }
}

class UDPVoiceClient {
  VoiceClient    vc;
  UDPConnection  conn;

  // Local connection info
  string  ip;
  ushort  port;

  // Voice audio info
  ushort  seq;
  uint    ts;

  this(VoiceClient vc) {
    this.vc = vc;
  }

  void run() {
    while (true) {
      auto data = this.conn.recv();
      // this.vc.log.infof("got data %s", cast(string)data);
    }
  }

  bool connect(string hostname, ushort port, Duration timeout=5.seconds) {
    this.conn = listenUDP(0);
    this.conn.connect(hostname, port);

    // Send IP discovery payload
    OutBuffer b = new OutBuffer();
    b.write(nativeToBigEndian(this.vc.ssrc));
    b.fill0(70 - b.toBytes.length);
    this.conn.send(b.toBytes);

    // Wait for the IP discovery response, maybe timeout after a bit
    string data;
    try {
      data = cast(string)this.conn.recv(timeout);
    } catch (Exception e) {
      return false;
    }

    // Parse the IP discovery response
    this.ip = data[4..(data[4..data.length].indexOf(0x00) + 4)];
    ubyte[2] portBytes = cast(ubyte[])(data)[data.length - 2..data.length];
    this.port = littleEndianToNative!(ushort, 2)(portBytes);
    this.vc.log.tracef("voice hoststring is %s:%s", ip, port);

    // Finally actually start running the task
    runTask(toDelegate(&this.run));
    return true;
  }

  void playDCA(DCAFile obj) {
    foreach (frame; obj.frames) {
      RTPHeader header;
      header.seq = this.seq++;
      header.ts = (this.ts += frame.size);
      header.ssrc = this.vc.ssrc;
      this.vc.log.tracef("s %s, t %s, ss %s", header.seq, header.ts, header.ssrc);
      ubyte[] raw = header.pack() ~ frame.data;
      this.vc.log.tracef("sending frame (%s + %s)", header.pack().length, frame.data.length);
      this.conn.send(raw);
      sleep((1.seconds / 1000) * 30);
    }
  }
}

class VoiceClient {
  // Global client
  Client     client;

  // Voice channel we're for
  Channel    channel;

  // Packet emitter
  Emitter  packetEmitter;

  // UDP Client
  UDPVoiceClient  udp;

  private {
    Logger     log;
    TaskMutex      waitForConnectedMutex;
    TaskCondition  waitForConnected;

    // Voice websocket
    WebSocket  sock;

    // Heartbeater task
    Task  heartbeater;

    // Listener for VOICE_SERVER_UPDATE events
    EventListener  l;
  }

  // Various connection attributes
  string  token;
  URL     endpoint;
  bool    connected = false;
  ushort  ssrc;
  ushort  port;
  ushort  heartbeat_interval;
  bool    mute;
  bool    deaf;
  bool    speaking = false;

  this(Channel c, bool mute=false, bool deaf=false) {
    this.channel = c;
    this.client = c.client;
    this.log = this.client.log;
    this.mute = mute;
    this.deaf = deaf;

    this.packetEmitter = new Emitter;
    this.packetEmitter.listen!VoiceReadyPacket(toDelegate(&this.handleVoiceReadyPacket));
    this.packetEmitter.listen!VoiceSessionDescriptionPacket(
        toDelegate(&this.handleVoiceSessionDescription));
  }

  void setSpeaking(bool value) {
    if (this.speaking == value) return;

    this.speaking = value;
    this.send(new VoiceSpeakingPacket(value, 0));
  }

  void handleVoiceReadyPacket(VoiceReadyPacket p) {
    this.log.tracef("Got VoiceReadyPacket");
    this.ssrc = p.ssrc;
    this.port = p.port;
    this.heartbeat_interval = p.heartbeat_interval;

    // Spawn the heartbeater
    this.heartbeater = runTask(toDelegate(&this.heartbeat));

    // Open up the UDP Connection and perform IP discovery
    this.udp = new UDPVoiceClient(this);
    assert(this.udp.connect(this.endpoint.host, this.port), "Failed to UDPVoiceClient connect/discover");

    // Select the protocol
    this.send(new VoiceSelectProtocolPacket("udp", "plain", this.udp.ip, this.udp.port));

  }

  void handleVoiceSessionDescription(VoiceSessionDescriptionPacket p) {
    // Notify the waitForConnected condition
    this.waitForConnected.notifyAll();
  }

  void playDCAFile(DCAFile f) {
    this.udp.playDCA(f);
  }

  void heartbeat() {
    while (this.connected) {
      uint unixTime = cast(uint)core.stdc.time.time(null);
      this.send(new VoiceHeartbeatPacket(unixTime * 1000));
      sleep(this.heartbeat_interval.msecs);
    }
  }

  void dispatch(JSONObject obj) {
    this.log.tracef("voice-dispatch: %s %s", obj.get!VoiceOPCode("op"), obj.dumps);

    switch (obj.get!VoiceOPCode("op")) {
      case VoiceOPCode.VOICE_READY:
        this.packetEmitter.emit!VoiceReadyPacket(new VoiceReadyPacket(obj));
        break;
      case VoiceOPCode.VOICE_SESSION_DESCRIPTION:
        this.packetEmitter.emit!VoiceSessionDescriptionPacket(
            new VoiceSessionDescriptionPacket(obj));
        break;
      default:
        break;
    }
  }

  void send(Serializable p) {
    JSONObject data = p.serialize();
    this.log.tracef("voice-send: %s", data.dumps());
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

    this.log.warning("voice websocket closed");
  }

  /*
  void onVoiceServerUpdate(VoiceServerUpdate event) {
    if (this.channel.guild_id != event.guild_id) {
      return;
    }

    // TODO: handle server moving
    this.token = event.token;
    this.connected = true;

    // Grab endpoint and create a proper URL out of it
    this.endpoint = URL("ws", event.endpoint.split(":")[0], 0, Path());
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
  */

  bool connect(Duration timeout=5.seconds) {
    this.waitForConnectedMutex = new TaskMutex;
    this.waitForConnected = new TaskCondition(this.waitForConnectedMutex);

    //this.l = this.client.gw.eventEmitter.listen!VoiceServerUpdate(toDelegate(
    //  &this.onVoiceServerUpdate));

    this.client.gw.send(new VoiceStateUpdatePacket(
      this.channel.guild.id,
      this.channel.id,
      this.mute,
      this.deaf
   ));

    // Wait for connection
    synchronized (this.waitForConnectedMutex) {
      if (this.waitForConnected.wait(timeout)) {
        return true;
      } else {
        this.disconnect();
        return false;
      }
    }
  }

  void disconnect() {
    this.connected = false;
    this.sock.close();
    this.l.unbind();
    this.client.gw.send(new VoiceStateUpdatePacket(
      this.channel.guild.id,
      0, // TODO
      this.mute,
      this.deaf
    ));
  }
}
