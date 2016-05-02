module dscord.voice.packets;

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
  Snowflake  server_id;
  Snowflake  user_id;
  string     session_id;
  string     token;

  this(Snowflake server, Snowflake user, string session, string token) {
    this.server_id = server;
    this.user_id = user;
    this.session_id = session;
    this.token = token;
  }

  override JSONObject serialize() {
    return super.serialize(VoiceOPCode.VOICE_IDENTIFY, new JSONObject()
      .set!Snowflake("server_id", server_id)
      .set!Snowflake("user_id", user_id)
      .set!string("session_id", session_id)
      .set!string("token", token).asJSON());
  }
}

class VoiceReadyPacket : BasePacket, Deserializable {
  ushort    ssrc;
  ushort    port;
  string[]  modes;
  ushort    heartbeat_interval;

  this(JSONObject obj) {
    this.deserialize(obj);
  }

  override void deserialize(JSONObject obj) {
    super.deserialize(obj);
    this.ssrc = this.data.get!ushort("ssrc");
    this.port = this.data.get!ushort("port");
    this.heartbeat_interval = this.data.get!ushort("heartbeat_interval");
    // TODO: this.modes = obj.get!
  }
}


class VoiceHeartbeatPacket : BasePacket, Serializable {
  uint  ts;

  this(uint ts) {
    this.ts = ts;
  }

  override JSONObject serialize() {
    return super.serialize(VoiceOPCode.VOICE_HEARTBEAT, JSONValue(this.ts));
  }
}
