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
       dscord.util.emitter;

enum VoiceState {
  DISCONNECTED = 0,
  CONNECTING = 1,
  CONNECTED = 2,
  READY = 3,
}

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

  private {
    // Local connection info
    string  ip;
    ushort  port;

    // Voice audio info
    ushort  seq;
    uint    ts;

    // Running state
    bool         running;
    bool         playing;

    TaskMutex    playLock;
    ManualEvent  pauseEvent;
  }

  this(VoiceClient vc) {
    this.vc = vc;

    this.playLock = new TaskMutex;
  }

  void run() {
    this.running = true;

    while (this.running) {
      auto data = this.conn.recv();
    }
  }

  void close() {
    this.running = false;
    this.playLock.lock();
    try {
      this.conn.close();
    } catch (Error e) {}
  }

  @property bool paused() {
    return (this.pauseEvent !is null);
  }

  bool pause(bool wait=false) {
    if (this.pauseEvent) {
      if (!wait) return false;
      this.pauseEvent.wait();
    }

    this.pauseEvent = createManualEvent();
    return true;
  }

  bool unpause() {
    if (!this.pauseEvent) {
      return false;
    }

    // Avoid a race here by nullifying before emit
    auto e = this.pauseEvent;
    this.pauseEvent = null;
    e.emit();
    return true;
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

    // Finally actually start running the task
    runTask(toDelegate(&this.run));
    return true;
  }

  /**
    Plays a DCAFile on the voice connection.
  */
  bool playDCA(DCAFile obj) {
    // Take out the playing lock, and mark as playing
    this.playLock.lock();
    this.playing = true;

    // Iterate over each frame and send it
    foreach (frame; obj.frames) {
      // If we're not running, we can't play audio
      if (!this.running) {
        this.vc.log.warning("UDPVoiceClient lost connection while playing audio");
        this.playLock.unlock();
        this.playing = false;
        return false;
      }

      // If we're paused, wait for the event to trigger
      if (this.pauseEvent) {
        this.vc.log.tracef("UDPVoiceClient has been paused");
        this.pauseEvent.wait();
        this.vc.log.tracef("UDPVoiceClient has been unpaused");
      }

      RTPHeader header;
      header.seq = this.seq++;
      header.ts = this.ts;
      header.ssrc = this.vc.ssrc;
      ubyte[] raw = header.pack() ~ frame.data;
      this.conn.send(raw);

      // TODO: don't hardcode this
      this.ts += 960;
      sleep(1.msecs * (960 / (48000 / 1000)));
    }

    this.playLock.unlock();
    this.playing = false;
    return true;
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

  // Current voice connection state
  VoiceState state = VoiceState.DISCONNECTED;

  private {
    Logger       log;
    ManualEvent  waitForConnected;

    // Voice websocket
    WebSocket  sock;

    // Heartbeater task
    Task  heartbeater;

    // Various connection attributes
    string  token;
    URL     endpoint;
    // bool    connected = false;
    ushort  ssrc;
    ushort  port;
    ushort  heartbeatInterval;
    bool    mute;
    bool    deaf;
    bool    speaking = false;
    EventListener  updateListener;
  }

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

  private void handleVoiceReadyPacket(VoiceReadyPacket p) {
    this.ssrc = p.ssrc;
    this.port = p.port;
    this.heartbeatInterval = p.heartbeatInterval;

    // Spawn the heartbeater
    this.heartbeater = runTask(toDelegate(&this.heartbeat));

    // If we don't have a UDP connection open (e.g. not reconnecting), open one
    //  now.
    if (!this.udp) {
      this.udp = new UDPVoiceClient(this);
    }

    // Then actually connect and perform IP discovery
    assert(this.udp.connect(this.endpoint.host, this.port), "Failed to UDPVoiceClient connect/discover");

    // Select the protocol
    //  TODO: encryption/xsalsa
    this.send(new VoiceSelectProtocolPacket("udp", "plain", this.udp.ip, this.udp.port));
  }

  private void handleVoiceSessionDescription(VoiceSessionDescriptionPacket p) {
    this.log.tracef("Recieved VoiceSessionDescription, finished connection sequence.");

    // Toggle our voice speaking state so everyone learns our SSRC
    this.send(new VoiceSpeakingPacket(true, 0));
    this.send(new VoiceSpeakingPacket(false, 0));

    // Set the state to READY, we can now send voice data
    this.state = VoiceState.READY;

    // Emit the connected event
    this.waitForConnected.emit();

    // If we where paused (e.g. in the process of reconnecting), unpause now
    if (this.udp.paused) {
      // For whatever reason, if we don't sleep here sometimes clients won't accept our audio
      sleep(1.seconds);
      this.udp.unpause();
    }
  }

  /**
    Plays a DCAFile on the connection.
  */
  void playDCAFile(DCAFile f) {
    assert(this.state == VoiceState.READY, "Must be connected to play audio");
    this.udp.playDCA(f);
  }

  private void heartbeat() {
    while (this.state >= VoiceState.CONNECTED) {
      uint unixTime = cast(uint)core.stdc.time.time(null);
      this.send(new VoiceHeartbeatPacket(unixTime * 1000));
      sleep(this.heartbeatInterval.msecs);
    }
  }

  private void dispatchVoicePacket(T)(ref JSON obj) {
    T packet = new T;
    packet.deserialize(obj);
    this.packetEmitter.emit!T(packet);
  }

  private void parse(string rawData) {
    auto json = parseTrustedJSON(rawData);

    VoiceOPCode op;

    foreach (key; json.byKey) {
      switch (key) {
        case "op":
          op = cast(VoiceOPCode)json.read!ushort;
          break;
        case "d":
          switch (op) {
            case VoiceOPCode.VOICE_READY:
              this.dispatchVoicePacket!VoiceReadyPacket(json);
              break;
            case VoiceOPCode.VOICE_SESSION_DESCRIPTION:
              this.dispatchVoicePacket!VoiceSessionDescriptionPacket(json);
              break;
            case VoiceOPCode.VOICE_HEARTBEAT:
              // We ignore these
              break;
            default:
              this.log.warningf("Unhandled voice packet: %s", op);
              break;
          }
          break;
        default:
          this.log.warningf("Got unexpected key for voice OP: %s: %s (%s)", op, key, json.peek);
          break;
      }
    }
  }

  void send(Serializable p) {
    string data = p.serialize().toString;
    this.sock.send(data);
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
        this.parse(data);
      } catch (Exception e) {
        this.log.warningf("failed to handle %s (%s)", e, data);
      } catch (Error e) {
        this.log.warningf("failed to handle %s (%s)", e, data);
      }
    }

    this.log.warningf("Lost voice websocket connection in state %s", this.state);

    // If we where in state READY, reconnect fully
    if (this.state == VoiceState.READY) {
      this.log.warning("Attempting reconnection of voice connection");
      this.disconnect();
      this.connect();
    }
  }

  private void onVoiceServerUpdate(VoiceServerUpdate event) {
    if (this.channel.guild.id != event.guildID) {
      return;
    }

    if (this.token && event.token != this.token) {
      return;
    } else {
      this.token = event.token;
    }

    // If we're currently connected to voice, pause the UDP connection...
    if (this.udp && !this.udp.paused) {
      this.udp.pause();
    }

    // If we're connected (e.g. have a WS open), close it so we can reconnect
    //  to the new voice endpoint.
    if (this.state >= VoiceState.CONNECTED) {
      // Set state before we close so we don't attempt to reconnect
      this.state = VoiceState.CONNECTED;
      this.sock.close();
    }

    // Make sure our state is now CONNECTED
    this.state = VoiceState.CONNECTED;

    // Grab endpoint and create a proper URL out of it
    this.endpoint = URL("ws", event.endpoint.split(":")[0], 0, Path());
    this.sock = connectWebSocket(this.endpoint);
    runTask(toDelegate(&this.run));

    // Send identify
    this.send(new VoiceIdentifyPacket(
      this.channel.guild.id,
      this.client.state.me.id,
      this.client.gw.sessionID,
      this.token
    ));
  }

  /**
    Attempt a connection to the voice channel this VoiceClient is attached to.
  */
  bool connect(Duration timeout=5.seconds) {
    this.state = VoiceState.CONNECTING;
    this.waitForConnected = createManualEvent();

    // Start listening for VoiceServerUpdates
    this.updateListener = this.client.gw.eventEmitter.listen!VoiceServerUpdate(
      toDelegate(&this.onVoiceServerUpdate)
    );

    // Send our VoiceStateUpdate
    this.client.gw.send(new VoiceStateUpdatePacket(
      this.channel.guild.id,
      this.channel.id,
      this.mute,
      this.deaf
   ));

    // Wait for connection event to be emitted (or timeout and disconnect)
    if (this.waitForConnected.wait(timeout, 0)) {
      return true;
    } else {
      this.disconnect();
      return false;
    }
  }

  void disconnect() {
    // Send gateway update if we requested it
    this.client.gw.send(new VoiceStateUpdatePacket(
      this.channel.guild.id,
      0,
      this.mute,
      this.deaf
    ));

    // Always make sure our updateListener is unbound
    this.updateListener.unbind();

    // If we're actually connected, close the voice socket
    if (this.state >= VoiceState.CONNECTING) {
      this.state = VoiceState.DISCONNECTED;
      this.sock.close();
    }

    // If we have a UDP connection, close it
    if (this.udp) {
      this.udp.close();
      this.udp.destroy();
      this.udp = null;
    }

    // Finally set state to disconnected
    this.state = VoiceState.DISCONNECTED;
  }
}
