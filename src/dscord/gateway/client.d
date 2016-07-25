module dscord.gateway.client;

import std.stdio,
       std.uni,
       std.functional,
       std.zlib,
       std.datetime,
       std.variant;

import vibe.core.core,
       vibe.inet.url,
       vibe.http.websockets;

import dscord.client,
       dscord.gateway.packets,
       dscord.gateway.events,
       dscord.util.emitter,
       dscord.util.json,
       dscord.util.counter;

/** Maximum reconnects the GatewayClient will try before resetting session state */
const ubyte MAX_RECONNECTS = 6;

/**
  GatewayClient is the base abstraction for connecting to, and interacting with
  the Discord Websocket (gateway) API.
*/
class GatewayClient {
  /** Client instance for this gateway connection */
  Client     client;

  /** WebSocket connection for this gateway connection */
  WebSocket  sock;

  /** Gateway SessionID, used for resuming. */
  string  sessionID;

  /** Gateway sequence number, used for resuming */
  uint    seq;

  /** Heartbeat interval */
  uint    hb_interval;

  /** Whether this GatewayClient is currently connected */
  bool    connected;

  /** Number of reconnects attempted */
  ubyte   reconnects;

  /** The heartbeater task */
  Task    heartbeater;

  /** Event emitter for Gateway Packets */
  Emitter  eventEmitter;

  private {
    /** Cached gateway URL from the API */
    string  cachedGatewayURL;
    Counter!string eventCounter;
    bool eventTracking;
  }

  /**
    Params:
      eventTracking = if true, log information about events recieved
  */
  this(Client client, bool eventTracking = false) {
    this.client = client;
    this.eventTracking = eventTracking;

    // Create the event emitter and listen to some required gateway events.
    this.eventEmitter = new Emitter;
    this.eventEmitter.listen!Ready(toDelegate(&this.handleReadyEvent));
    this.eventEmitter.listen!Resumed(toDelegate(&this.handleResumedEvent));

    // Copy emitters to client for easier API access
    client.events = this.eventEmitter;

    if (this.eventTracking) {
      this.eventCounter = new Counter!string;
    }
  }

  /**
    Logger for this GatewayClient.
  */
  @property Logger log() {
    return this.client.log;
  }

  /**
    Starts a connection to the gateway. Also called for resuming/reconnecting.
  */
  void start() {
    if (this.sock && this.sock.connected) this.sock.close();

    // If this is our first connection, get a gateway WS URL
    if (!this.cachedGatewayURL) {
      this.cachedGatewayURL = client.api.gateway();
    }

    // Start the main task
    this.log.infof("Starting connection to Gateway WebSocket (%s)", this.cachedGatewayURL);
    this.sock = connectWebSocket(URL(this.cachedGatewayURL));
    runTask(toDelegate(&this.run));
  }

  /**
    Send a gateway payload.
  */
  void send(Serializable p) {
    JSONValue data = p.serialize();
    this.log.tracef("gateway-send: %s", data.toString);
    this.sock.send(data.toString);
  }

  private void debugEventCounts() {
    while (true) {
      this.eventCounter.resetAll();
      sleep(5.seconds);
      this.log.infof("%s total events", this.eventCounter.total);

      foreach (ref event; this.eventCounter.mostCommon(5)) {
        this.log.infof("  %s: %s", event, this.eventCounter.get(event));
      }
    }
  }

  private void handleReadyEvent(Ready  r) {
    this.log.infof("Recieved READY payload, starting heartbeater");
    this.hb_interval = r.heartbeatInterval;
    this.sessionID = r.sessionID;
    this.heartbeater = runTask(toDelegate(&this.heartbeat));
    this.reconnects = 0;

    if (this.eventTracking) {
      runTask(toDelegate(&this.debugEventCounts));
    }
  }

  private void handleResumedEvent(Resumed r) {
    this.heartbeater = runTask(toDelegate(&this.heartbeat));
  }

  private void emitDispatchEvent(T)(ref JSON obj) {
    T v = new T(this.client, obj);
    this.eventEmitter.emit!T(v);
    v.resolveDeferreds();
    v.destroy();
  }

  private void handleDispatchPacket(uint seq, string type, ref JSON obj) {
    // Update sequence number if it's larger than what we have
    if (seq > this.seq) {
      this.seq = seq;
    }

    if (this.eventTracking) {
      this.eventCounter.tick(type);
    }

    switch (type) {
      case "READY":
        this.emitDispatchEvent!Ready(obj);
        break;
      case "RESUMED":
        this.emitDispatchEvent!Resumed(obj);
        break;
      case "CHANNEL_CREATE":
        this.emitDispatchEvent!ChannelCreate(obj);
        break;
      case "CHANNEL_UPDATE":
        this.emitDispatchEvent!ChannelUpdate(obj);
        break;
      case "CHANNEL_DELETE":
        this.emitDispatchEvent!ChannelDelete(obj);
        break;
      case "GUILD_BAN_ADD":
        this.emitDispatchEvent!GuildBanAdd(obj);
        break;
      case "GUILD_BAN_REMOVE":
        this.emitDispatchEvent!GuildBanRemove(obj);
        break;
      case "GUILD_CREATE":
        this.emitDispatchEvent!GuildCreate(obj);
        break;
      case "GUILD_UPDATE":
        this.emitDispatchEvent!GuildUpdate(obj);
        break;
      case "GUILD_DELETE":
        this.emitDispatchEvent!GuildDelete(obj);
        break;
      case "GUILD_EMOJIS_UPDATE":
        this.emitDispatchEvent!GuildEmojisUpdate(obj);
        break;
      case "GUILD_INTEGRATIONS_UPDATE":
        this.emitDispatchEvent!GuildIntegrationsUpdate(obj);
        break;
      case "GUILD_MEMBER_ADD":
        this.emitDispatchEvent!GuildMemberAdd(obj);
        break;
      case "GUILD_MEMBER_UPDATE":
        this.emitDispatchEvent!GuildMemberUpdate(obj);
        break;
      case "GUILD_MEMBER_REMOVE":
        this.emitDispatchEvent!GuildMemberRemove(obj);
        break;
      case "GUILD_ROLE_CREATE":
        this.emitDispatchEvent!GuildRoleCreate(obj);
        break;
      case "GUILD_ROLE_UPDATE":
        this.emitDispatchEvent!GuildRoleUpdate(obj);
        break;
      case "GUILD_ROLE_DELETE":
        this.emitDispatchEvent!GuildRoleDelete(obj);
        break;
      case "MESSAGE_CREATE":
        this.emitDispatchEvent!MessageCreate(obj);
        break;
      case "MESSAGE_UPDATE":
        this.emitDispatchEvent!MessageUpdate(obj);
        break;
      case "MESSAGE_DELETE":
        this.emitDispatchEvent!MessageDelete(obj);
        break;
      case "PRESENCE_UPDATE":
        this.emitDispatchEvent!PresenceUpdate(obj);
        break;
      case "TYPING_START":
        this.emitDispatchEvent!TypingStart(obj);
        break;
      case "USER_SETTINGS_UPDATE":
        this.emitDispatchEvent!UserSettingsUpdate(obj);
        break;
      case "USER_UPDATE":
        this.emitDispatchEvent!UserUpdate(obj);
        break;
      case "VOICE_STATE_UPDATE":
        this.emitDispatchEvent!VoiceStateUpdate(obj);
        break;
      case "VOICE_SERVER_UPDATE":
        this.emitDispatchEvent!VoiceServerUpdate(obj);
        break;
      case "CHANNEL_PIN_UPDATE":
        this.emitDispatchEvent!ChannelPinUpdate(obj);
        break;
      default:
        this.log.warningf("Unhandled dispatch event: %s", type);
        break;
    }
  }

  private void parse(string rawData) {
    auto json = parseTrustedJSON(rawData);

    uint seq;
    string type;
    OPCode op;

    // Scan over each key, store any extra information until we hit the data payload
    foreach (key; json.byKey) {
      switch (key) {
        case "op":
          op = cast(OPCode)json.read!ushort;
          break;
        case "t":
          type = json.read!string;
          break;
        case "s":
          seq = json.read!uint;
          break;
        case "d":
          if (type == "READY") {
            this.log.infof("READY payload size: %s", rawData.length);
          }

          switch (op) {
            case OPCode.DISPATCH:
              this.handleDispatchPacket(seq, type, json);
              break;
            default:
              this.log.warningf("Unhandled gateway packet: %s", op);
              break;
          }
          break;
        default:
          this.log.tracef("K: %s", key);
          break;
      }
    }
  }

  private void heartbeat() {
    while (this.connected) {
      this.send(new HeartbeatPacket(this.seq));
      sleep(this.hb_interval.msecs);
    }
  }

  /**
    Runs the GatewayClient until completion.
  */
  void run() {
    string data;

    // If we already have a sequence number, attempt to resume
    if (this.sessionID && this.seq) {
      this.log.infof("Sending Resume Payload (we where %s at %s)", this.sessionID, this.seq);
      this.send(new ResumePacket(this.client.token, this.sessionID, this.seq));
    } else {
      // On startup, send the identify payload
      this.log.info("Sending Identify Payload");
      this.send(new IdentifyPacket(
          this.client.token,
          this.client.shardInfo.shard,
          this.client.shardInfo.numShards));
    }

    this.log.info("Connected to Gateway");
    this.connected = true;

    while (this.sock.waitForData()) {
      if (!this.connected) break;

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

    this.log.critical("Gateway websocket closed");
    this.connected = false;
    this.reconnects++;

    if (this.reconnects > MAX_RECONNECTS) {
      this.log.errorf("Max Gateway WS reconnects (%s) hit, aborting...", this.reconnects);
      return;
    }

    if (this.reconnects > 1) {
      this.sessionID = null;
      this.seq = 0;
      this.log.warning("Waiting 5 seconds before reconnecting...");
      sleep(5.seconds);
    }

    this.log.info("Attempting reconnection...");
    return this.start();
  }
}
