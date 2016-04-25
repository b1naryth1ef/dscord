module dscord.gateway.packets;

import dscord.types.user,
       dscord.util.json;

enum OPCode {
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
  JSONObject serialize();
}

interface Deserializable {
  void deserialize(JSONObject);
}

class BasePacket : Deserializable {
  OPCode      op;
  JSONObject  data;
  JSONObject  raw;

  JSONObject serialize(OPCode op, JSONValue data) {
    return new JSONObject()
      .set!ushort("op", cast(ushort)op)
      .setRaw("d", data);
  }

  void deserialize(JSONObject obj) {
    this.raw = obj;
    this.op = obj.get!OPCode("op");
    this.data = obj.get!JSONObject("d");
  }
}

class Heartbeat : BasePacket, Serializable {
  uint seq;

  this(uint seq) {
    this.seq = seq;
  }

  override JSONObject serialize() {
    return super.serialize(OPCode.HEARTBEAT, JSONValue(this.seq));
  }
}

/* class StatusUpdate : BasePacket, Deserializable {} */
/* class VoiceStateUpdate : BasePacket, Deserializable {} */
/* class VoiceServerPing : BasePacket, Deserializable {} */
/* class Resume : BasePacket, Deserializable {} */
/* class Reconnect : BasePacket, Deserializable {} */
/* class RequestGuildMembers : BasePacket, Deserializable {} */
/* class InvalidSession : BasePacket, Deserializable {} */

class Dispatch : BasePacket, Deserializable {
  int         seq;
  string      event;

  this(JSONObject obj) {
    this.deserialize(obj);
  }

  override void deserialize(JSONObject obj) {
    super.deserialize(obj);
    this.seq = obj.get!int("s");
    this.event = obj.get!string("t");
  }

  T castEvent(T)() {
    return new T(this);
  }
}

class Identify : BasePacket, Serializable {
  string token;
  bool compress = true;
  ushort large_threshold = 250;

  this(string token) {
    this.token = token;
  }

  @property JSONObject properties() {
    return new JSONObject()
      .set!string("$os", "linux")
      .set!string("$browser", "d-scord")
      .set!string("$device", "d-scord")
      .set!string("$referrer", "")
      .set!string("$referring_domain", "");
  }

  override JSONObject serialize() {
    auto result = new JSONObject()
      .set!string("token", this.token)
      .set!JSONObject("properties", this.properties)
      .set!bool("compress", this.compress)
      .set!ushort("large_threshold", this.large_threshold);
    return super.serialize(OPCode.IDENTIFY, result.asJSON);
  }
}

