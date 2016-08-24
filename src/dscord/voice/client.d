/**
  Manages Discord voice connections.
*/
module dscord.voice.client;

import core.time,
       core.stdc.time,
       std.stdio,
       std.zlib,
       std.array,
       std.stdio,
       std.bitmanip,
       std.outbuffer,
       std.string,
       std.algorithm.comparison;

import vibe.core.core,
       vibe.core.net,
       vibe.inet.url,
       vibe.http.websockets;

import dcad.types : DCAFile;


import dscord.types,
       dscord.voice,
       dscord.client,
       dscord.gateway,
       dscord.util.emitter,
       dscord.util.ticker;

/// VoiceClient connection states
enum VoiceState {
  DISCONNECTED = 0,
  CONNECTING = 1,
  CONNECTED = 2,
  READY = 3,
}

/// RTPHeader used for sending RTP data
struct RTPHeader {
  /// Sequence number of the current frame
  ushort  seq;

  /// Timestamp of the current frame
  uint    ts;

  /// Source ID of the current sender
  uint    ssrc;

  this(ushort seq, uint ts, uint ssrc) {
    this.seq = seq;
    this.ts = ts;
    this.ssrc = ssrc;
  }

  /// Returns a packed (in bytes) version of this header
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

/// UDP Connection wrapper for the VoiceClient
class UDPVoiceClient {
  /// Parent VoiceClient reference
  VoiceClient    vc;

  // UDP Connection
  UDPConnection  conn;

  private {
    // Local connection info
    string  ip;
    ushort  port;

    // Running state
    bool  running;
  }

  this(VoiceClient vc) {
    this.vc = vc;
  }

  void run() {
    this.running = true;

    while (this.running) {
      auto data = this.conn.recv();
    }
  }

  void close() {
    this.running = false;

    try {
      this.conn.close();
    } catch (Error e) {}
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
    runTask(&this.run);
    return true;
  }
}

class VoiceClient {
  /// Global client which owns this VoiceClient
  Client     client;

  /// The channel this VoiceClient is attached to
  Channel    channel;

  /// Packet emitter
  Emitter  packetEmitter;

  /// UDP Client connection
  UDPVoiceClient  udp;

  // Current voice connection state
  VoiceState state = VoiceState.DISCONNECTED;

  // Currently playing item + player task
  Playable  playable;

  private {
    // Logger reference
    Logger  log;

    // Event triggered when connection is complete
    ManualEvent  waitForConnected;

    // Player task
    Task  playerTask;

    // Voice websocket
    WebSocket  sock;

    // Heartbeater task
    Task  heartbeater;

    // Various connection attributes
    string  token;
    URL     endpoint;
    ushort  ssrc;
    ushort  port;

    // Track mute/deaf states
    bool    mute, deaf;

    // Track the current speaking state
    bool    speaking = false;

    // Used to track VoiceServerUpdates
    EventListener  updateListener;

    // Used to control pausing state
    ManualEvent pauseEvent;
  }

  this(Channel c, bool mute=false, bool deaf=false) {
    this.channel = c;
    this.client = c.client;
    this.log = this.client.log;

    this.mute = mute;
    this.deaf = deaf;

    this.packetEmitter = new Emitter;
    this.packetEmitter.listen!VoiceReadyPacket(&this.handleVoiceReadyPacket);
    this.packetEmitter.listen!VoiceSessionDescriptionPacket(
      &this.handleVoiceSessionDescription);
  }

  /// Set the speaking state
  void setSpeaking(bool value) {
    if (this.speaking == value) return;

    this.speaking = value;
    this.send(new VoiceSpeakingPacket(value, 0));
  }

  private void handleVoiceReadyPacket(VoiceReadyPacket p) {
    this.ssrc = p.ssrc;
    this.port = p.port;

    // Spawn the heartbeater
    this.heartbeater = runTask(&this.heartbeat, p.heartbeatInterval);

    // If we don't have a UDP connection open (e.g. not reconnecting), open one
    //  now.
    if (!this.udp) {
      this.udp = new UDPVoiceClient(this);
    }

    // Then actually connect and perform IP discovery
    if (!this.udp.connect(this.endpoint.host, this.port)) {
      this.log.warning("VoiceClient failed to connect over UDP and perform IP discovery");
      this.disconnect(false);
      return;
    }

    // Select the protocol
    //  TODO: encryption/xsalsa
    this.send(new VoiceSelectProtocolPacket("udp", "plain", this.udp.ip, this.udp.port));
  }

  private void handleVoiceSessionDescription(VoiceSessionDescriptionPacket p) {
    this.log.tracef("Recieved VoiceSessionDescription, finished connection sequence.");

    // Toggle our voice speaking state so everyone learns our SSRC
    this.send(new VoiceSpeakingPacket(true, 0));
    this.send(new VoiceSpeakingPacket(false, 0));
    sleep(250.msecs);

    // Set the state to READY, we can now send voice data
    this.state = VoiceState.READY;

    // Emit the connected event
    this.waitForConnected.emit();

    // If we where paused (e.g. in the process of reconnecting), unpause now
    if (this.paused) {
      // For whatever reason, if we don't sleep here sometimes clients won't accept our audio
      sleep(1.seconds);
      this.resume();
    }
  }

  /// Whether the player is currently paused
  @property bool paused() {
    return (this.pauseEvent !is null);
  }

  /// Pause the player
  bool pause(bool wait=false) {
    if (this.pauseEvent) {
      if (!wait) return false;
      this.pauseEvent.wait();
    }

    this.pauseEvent = createManualEvent();
    return true;
  }

  /// Resume the player
  bool resume() {
    if (!this.paused) {
      return false;
    }

    // Avoid race conditions by copying
    auto e = this.pauseEvent;
    this.pauseEvent = null;
    e.emit();
    return true;
  }

  private void runPlayer() {
    this.playable.start();

    if (!this.playable.hasMoreFrames()) {
      this.log.warning("Playable ran out of frames before playing");
      return;
    }

    this.setSpeaking(true);

    // Create a new timing ticker at the frame duration interval
    StaticTicker ticker = new StaticTicker(this.playable.getFrameDuration().msecs, true);

    RTPHeader header;
    header.ssrc = this.ssrc;

    ubyte[] frame;

    while (this.playable.hasMoreFrames()) {
      // If the UDP connection isnt running, this is pointless
      if (!this.udp || !this.udp.running) {
        this.log.warning("UDPVoiceClient lost connection while playing audio");
        this.setSpeaking(false);
        return;
      }

      // If we're paused, wait until we unpause to continue playing. Make sure
      //  to set speaking here in case users connect during this period.
      if (this.paused) {
        this.setSpeaking(false);
        this.pauseEvent.wait();
        this.setSpeaking(true);

        // Reset the ticker so we don't fast forward it to catch up
        ticker.reset();
      }

      // Get the next frame from the playable, and send it
      frame = this.playable.nextFrame();
      header.seq++;
      this.udp.conn.send(header.pack() ~ frame);
      header.ts += this.playable.getFrameSize();

      // Wait until its time to play the next frame
      ticker.sleep();
    }

    this.setSpeaking(false);
  }

  /// Whether the player is currently active
  @property bool playing() {
    return (this.playerTask && this.playerTask.running);
  }

  /// Plays a Playable
  VoiceClient play(Playable p) {
    assert(this.state == VoiceState.READY, "Must be connected to play audio");

    // If we are currently playing something, kill it
    if (this.playerTask && this.playerTask.running) {
      this.playerTask.terminate();
    }

    this.playable = p;
    this.playerTask = runTask(&this.runPlayer);
    return this;
  }

  private void heartbeat(ushort heartbeatInterval) {
    while (this.state >= VoiceState.CONNECTED) {
      uint unixTime = cast(uint)core.stdc.time.time(null);
      this.send(new VoiceHeartbeatPacket(unixTime * 1000));
      sleep(heartbeatInterval.msecs);
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
            case VoiceOPCode.VOICE_SPEAKING:
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

  /// Sends a payload to the websocket
  void send(Serializable p) {
    string data = p.serialize().toString;
    this.sock.send(data);
  }

  // Runs this voice client
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
      this.disconnect(false);
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

    // Pause the player until we reconnect
    if (!this.paused) {
      this.pause();
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
    runTask(&this.run);

    // Send identify
    this.send(new VoiceIdentifyPacket(
      this.channel.guild.id,
      this.client.state.me.id,
      this.client.gw.sessionID,
      this.token
    ));
  }

  /// Attempt a connection to the voice channel this VoiceClient is attached to.
  bool connect(Duration timeout=5.seconds) {
    this.state = VoiceState.CONNECTING;
    this.waitForConnected = createManualEvent();

    // Start listening for VoiceServerUpdates
    this.updateListener = this.client.gw.eventEmitter.listen!VoiceServerUpdate(
      &this.onVoiceServerUpdate
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
      this.disconnect(false);
      return false;
    }
  }

  /// Disconnects from the voice channel. If clean is true, waits to finish playing.
  void disconnect(bool clean=true) {
    if (this.playing) {
      if (clean) {
        this.log.tracef("Requested CLEAN voice disconnect, waiting...");
        this.playerTask.join();
        this.log.tracef("Executing previously requested CLEAN voice disconnect");
      }
    }

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
