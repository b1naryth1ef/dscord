/**
  Implementations of packets sent over the Voice websocket.
*/
module dscord.voice.packets;

import std.stdio;

import dscord.types,
       dscord.gateway;

enum VoiceOPCode {
  VOICE_IDENTIFY = 0,
  VOICE_SELECT_PROTOCOL = 1,
  VOICE_READY = 2,
  VOICE_HEARTBEAT = 3,
  VOICE_SESSION_DESCRIPTION = 4,
  VOICE_SPEAKING = 5,
}

class VoiceIdentifyPacket : BasePacket, Serializable {
  Snowflake  serverID;
  Snowflake  userID;
  string     sessionID;
  string     token;

  this(Snowflake server, Snowflake user, string session, string token) {
    this.serverID = server;
    this.userID = user;
    this.sessionID = session;
    this.token = token;
  }

  override VibeJSON serialize() {
    return super.serialize(VoiceOPCode.VOICE_IDENTIFY, VibeJSON([
      "server_id": VibeJSON(this.serverID),
      "user_id": VibeJSON(this.userID),
      "session_id": VibeJSON(this.sessionID),
      "token": VibeJSON(this.token),
    ]));
  }
}

class VoiceReadyPacket : BasePacket, Deserializable {
  ushort    ssrc;
  ushort    port;
  string[]  modes;
  ushort    heartbeatInterval;

  void deserialize(ref JSON obj) {
    obj.keySwitch!("ssrc", "port", "modes", "heartbeat_interval")(
      { this.ssrc = obj.read!ushort; },
      { this.port = obj.read!ushort; },
      { this.modes = obj.read!(string[]); },
      { this.heartbeatInterval = obj.read!ushort; },
    );
  }
}

class VoiceSelectProtocolPacket : BasePacket, Serializable {
  string  protocol;
  string  mode;
  string  ip;
  ushort  port;

  this(string protocol, string mode, string ip, ushort port) {
    this.protocol = protocol;
    this.mode = mode;
    this.ip = ip;
    this.port = port;
  }

  override VibeJSON serialize() {
    auto data = VibeJSON([
      "port": VibeJSON(this.port),
      "address": VibeJSON(this.ip),
      "mode": VibeJSON(this.mode),
    ]);

    return super.serialize(VoiceOPCode.VOICE_SELECT_PROTOCOL, VibeJSON([
      "protocol": VibeJSON(this.protocol),
      "data": data,
    ]));
  }
}

class VoiceHeartbeatPacket : BasePacket, Serializable {
  uint  ts;

  this(uint ts) {
    this.ts = ts;
  }

  override VibeJSON serialize() {
    return super.serialize(VoiceOPCode.VOICE_HEARTBEAT, VibeJSON(this.ts));
  }
}

class VoiceSpeakingPacket : BasePacket, Serializable {
  bool  speaking;
  uint  delay;

  this(bool speaking, uint delay) {
    this.speaking = speaking;
    this.delay = delay;
  }

  override VibeJSON serialize() {
    return super.serialize(VoiceOPCode.VOICE_SPEAKING, VibeJSON([
      "speaking": VibeJSON(this.speaking),
      "delay": VibeJSON(this.delay),
    ]));
  }
}

class VoiceSessionDescriptionPacket : BasePacket, Deserializable {
  string  secretKey;

  void deserialize(ref JSON obj) {
    obj.keySwitch!("secret_key")(
      { this.secretKey = obj.read!string; }
    );
  }
}
