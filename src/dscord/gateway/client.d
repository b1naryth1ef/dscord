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
       dscord.util.json;

const ubyte MAX_RECONNECTS = 6;

alias GatewayPacketHandler = void delegate (BasePacket);


class GatewayClient {
  Logger     log;
  Client     client;
  WebSocket  sock;

  string  session_id;
  uint    seq;
  uint    hb_interval;
  bool    connected;
  ubyte   reconnects;
  Task    heartbeater;

  Emitter  eventEmitter;

  this(Client client) {
    this.client = client;
    this.log = this.client.log;

    this.eventEmitter = new Emitter;
    this.eventEmitter.listen!Ready(toDelegate(&this.handleReadyEvent));
    // this.eventEmitter.listen!Resumed(toDelegate(&this.handleResumedEvent));

    // Copy emitters to client for easier API access
    client.events = this.eventEmitter;
  }

  void start() {
    if (this.sock && this.sock.connected) this.sock.close();

    // Start the main task
    this.log.info("Starting connection to Gateway WebSocket");
    this.sock = connectWebSocket(URL(client.api.gateway()));
    runTask(toDelegate(&this.run));
  }

  void send(Serializable p) {
    JSONValue data = p.serialize();
    this.log.tracef("2");
    this.log.tracef("%s", data);
    this.log.tracef("gateway-send: %s", data.toString);
    this.sock.send(data.toString);
  }

  void handleReadyEvent(Ready  r) {
    this.log.infof("Recieved READY payload, starting heartbeater");
    this.hb_interval = r.heartbeatInterval;
    this.session_id = r.sessionID;
    this.heartbeater = runTask(toDelegate(&this.heartbeat));
    this.reconnects = 0;
  }

  /*void handleResumedEvent(Resumed r) {
    this.heartbeater = runTask(toDelegate(&this.heartbeat));
  }*/

  void emitDispatchEvent(T)(ref JSON obj) {
    this.eventEmitter.emit!T(new T(this.client, obj));
  }

  void handleDispatchPacket(uint seq, string type, ref JSON obj) {
    // Update sequence number if it's larger than what we have
    if (seq > this.seq) {
      this.seq = seq;
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
      default:
        this.log.warningf("Unhandled dispatch event: %s", type);
        break;
    }
  }

  void parse(string rawData) {
    auto json = parseTrustedJSON(rawData);

    uint seq;
    string type;
    OPCode op;

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

  void heartbeat() {
    while (this.connected) {
      this.send(new HeartbeatPacket(this.seq));
      sleep(this.hb_interval.msecs);
    }
  }

  void run() {
    string data;

    // If we already have a sequence number, attempt to resume
    if (this.session_id && this.seq) {
      this.send(new ResumePacket(this.client.token, this.session_id, this.seq));
    } else {
      // On startup, send the identify payload
      this.send(new IdentifyPacket(this.client.token));
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
        // this.log.tracef("gateway-recv: %s", data);
        this.parse(data);
        // this.dispatch(new JSONObject(data));
      } catch (Exception e) {
        this.log.warning("failed to handle %s (%s)", e, data);
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
      this.session_id = null;
      this.seq = 0;
      this.log.warning("Waiting 5 seconds before reconnecting...");
      sleep(5.seconds);
    }

    this.log.info("Attempting reconnection...");
    return this.start();
  }
}
