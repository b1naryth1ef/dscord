/**
  Implementations of packets sent over the Gateway websocket.
*/
module dscord.gateway.packets;

import std.stdio;

import dscord.types.all;

enum OPCode : ushort {
  DISPATCH = 0,
  HEARTBEAT = 1,
  IDENTIFY = 2,
  STATUS_UPDATE = 3,
  VOICE_STATE_UPDATE = 4,
  VOICE_SERVER_PING = 5,
  RESUME = 6,
  RECONNECT = 7,
  REQUEST_GUILD_MEMBERS = 8,
  INVALID_SESSION = 9,
  HELLO = 10,
  HEARTBEAT_ACK = 11,
  GUILD_SYNC = 12,
};

interface Serializable {
  VibeJSON serialize();
}

interface Deserializable {
  void deserialize(ref JSON);
}

class BasePacket {
  OPCode      op;
  VibeJSON    data;
  VibeJSON    raw;

  VibeJSON serialize(ushort op, VibeJSON data) {
    return VibeJSON([
      "op": VibeJSON(op),
      "d": data,
    ]);
  }
}

class HeartbeatPacket : BasePacket, Serializable {
  uint seq;

  this(uint seq) {
    this.seq = seq;
  }

  override VibeJSON serialize() {
    return super.serialize(OPCode.HEARTBEAT, VibeJSON(this.seq));
  }
}

class ResumePacket : BasePacket, Serializable {
  string  token;
  string  sessionID;
  uint    seq;

  this(string token, string sessionID, uint seq) {
    this.token = token;
    this.sessionID = sessionID;
    this.seq = seq;
  }

  override VibeJSON serialize() {
    return super.serialize(OPCode.RESUME, VibeJSON([
      "token": VibeJSON(this.token),
      "session_id": VibeJSON(this.sessionID),
      "seq": VibeJSON(this.seq),
    ]));
  }
}

class VoiceStateUpdatePacket : BasePacket, Serializable {
  Snowflake  guildID;
  Snowflake  channelID;
  bool       self_mute;
  bool       self_deaf;

  this(Snowflake guild_id, Snowflake channel_id, bool self_mute, bool self_deaf) {
    this.guildID = guild_id;
    this.channelID = channel_id;
    this.self_mute = self_mute;
    this.self_deaf = self_deaf;
  }

  override VibeJSON serialize() {
    return super.serialize(OPCode.VOICE_STATE_UPDATE, VibeJSON([
      "self_mute": VibeJSON(this.self_mute),
      "self_deaf": VibeJSON(this.self_deaf),
      "guild_id": this.guildID ? VibeJSON(this.guildID) : VibeJSON(null),
      "channel_id": this.channelID ? VibeJSON(this.channelID) : VibeJSON(null),
    ]));
  }
}

class IdentifyPacket : BasePacket, Serializable {
  string token;
  bool compress = true;
  ushort largeThreshold = 250;
  ushort[2] shard;

  this(string token, ushort shard = 0, ushort numShards = 1) {
    this.token = token;
    this.shard = [shard, numShards];
  }

  @property VibeJSON properties() {
    return VibeJSON([
      "$os": VibeJSON("linux"),
      "$browser": VibeJSON("dscord"),
      "$device": VibeJSON("dscord"),
      "$referrer": VibeJSON(""),
    ]);
  }

  override VibeJSON serialize() {
    return super.serialize(OPCode.IDENTIFY, VibeJSON([
      "token": VibeJSON(this.token),
      "properties": this.properties,
      "compress": VibeJSON(this.compress),
      "large_threshold": VibeJSON(this.largeThreshold),
      "shard": VibeJSON([VibeJSON(this.shard[0]), VibeJSON(this.shard[1])]),
    ]));
  }
}
