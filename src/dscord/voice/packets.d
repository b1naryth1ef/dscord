module dscord.voice.packets;

import std.stdio;

import dscord.types.all,
       dscord.gateway.packets;

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

  override JSONValue serialize() {
    JSONValue res;
    res["server_id"] = JSONValue(this.serverID);
    res["user_id"] = JSONValue(this.userID);
    res["session_id"] = JSONValue(this.sessionID);
    res["token"] = JSONValue(this.token);
    return super.serialize(VoiceOPCode.VOICE_IDENTIFY, res);
  }
}

class VoiceReadyPacket : BasePacket {
  ushort    ssrc;
  ushort    port;
  string[]  modes;
  ushort    heartbeat_interval;
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

  override JSONValue serialize() {
    JSONValue res;
    res["port"] = this.port;
    res["address"] = this.ip;
    res["mode"] = this.mode;
    return super.serialize(VoiceOPCode.VOICE_SELECT_PROTOCOL, res);
  }
}

class VoiceHeartbeatPacket : BasePacket, Serializable {
  uint  ts;

  this(uint ts) {
    this.ts = ts;
  }

  override JSONValue serialize() {
    return super.serialize(VoiceOPCode.VOICE_HEARTBEAT, JSONValue(this.ts));
  }
}

class VoiceSpeakingPacket : BasePacket, Serializable {
  bool  speaking;
  uint  delay;

  this(bool speaking, uint delay) {
    this.speaking = speaking;
    this.delay = delay;
  }

  override JSONValue serialize() {
    JSONValue res;
    res["speaking"] = this.speaking;
    res["delay"] = this.delay;
    return super.serialize(VoiceOPCode.VOICE_SPEAKING, res);
  }
}

class VoiceSessionDescriptionPacket : BasePacket {
  string  secretKey;
}

