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
};

interface Serializable {
  JSONValue serialize();
}

class BasePacket {
  OPCode      op;
  JSONValue  data;
  JSONValue  raw;

  JSONValue serialize(ushort op, JSONValue data) {
    JSONValue res;
    res["op"] = JSONValue(op);
    res["d"] = data;
    return res;
  }
}

class HeartbeatPacket : BasePacket, Serializable {
  uint seq;

  this(uint seq) {
    this.seq = seq;
  }

  override JSONValue serialize() {
    return super.serialize(OPCode.HEARTBEAT, JSONValue(this.seq));
  }
}

class ResumePacket : BasePacket, Serializable {
  string  token;
  string  session_id;
  uint    seq;

  this(string token, string session_id, uint seq) {
    this.token = token;
    this.session_id = session_id;
    this.seq = seq;
  }

  override JSONValue serialize() {
    JSONValue obj;
    obj["token"] = JSONValue(token);
    obj["session_id"] = JSONValue(session_id);
    obj["seq"] = JSONValue(seq);
    return super.serialize(OPCode.RESUME, obj);
  }
}

/* class StatusUpdate : BasePacket, Deserializable {} */
/* class VoiceServerPing : BasePacket, Deserializable {} */
/* class Resume : BasePacket, Deserializable {} */
/* class Reconnect : BasePacket, Deserializable {} */
/* class RequestGuildMembers : BasePacket, Deserializable {} */
/* class InvalidSession : BasePacket, Deserializable {} */

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

  override JSONValue serialize() {
    JSONValue res;
    res["self_mute"] = JSONValue(this.self_mute);
    res["self_deaf"] = JSONValue(this.self_deaf);
    res["guild_id"] = this.guildID ? JSONValue(this.guildID) : JSONValue(null);
    res["channel_id"] = this.channelID ? JSONValue(this.channelID) : JSONValue(null);
    return super.serialize(OPCode.VOICE_STATE_UPDATE, res);
  }
}

class IdentifyPacket : BasePacket, Serializable {
  string token;
  bool compress = true;
  ushort large_threshold = 250;
  ushort[2] shard;

  this(string token, ushort shard = 0, ushort numShards = 1) {
    this.token = token;
    this.shard = [shard, numShards];
  }

  @property JSONValue properties() {
    JSONValue prop;
    prop["$os"] = "linux";
    prop["$browser"] = "dscord";
    prop["$device"] = "dscord";
    prop["$referrer"] = "";
    prop["$browser"] = "";
    return prop;
  }

  override JSONValue serialize() {
    JSONValue res;
    res["token"] = JSONValue(this.token);
    res["properties"] = this.properties;
    res["compress"] = JSONValue(this.compress);
    res["large_threshold"] = JSONValue(this.large_threshold);
    res["shard"] = JSONValue(this.shard);
    return super.serialize(OPCode.IDENTIFY, res);
  }
}

