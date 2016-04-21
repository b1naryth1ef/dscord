module gateway.packets;

import types.user,
       util.json;

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

class BasePacket {
  JSONObject createDispatch(OPCode op, JSONObject data) {
    return new JSONObject()
      .set!ushort("op", cast(ushort)op)
      .set!JSONObject("d", data);
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

  JSONObject serialize() {
    auto result = new JSONObject()
      .set!string("token", this.token)
      .set!JSONObject("properties", this.properties)
      .set!bool("compress", this.compress)
      .set!ushort("large_threshold", this.large_threshold);
    return super.createDispatch(OPCode.IDENTIFY, result);
  }
}


