module dscord.client;

import dscord.state,
       dscord.api.client,
       dscord.gateway.client,
       dscord.voice.client,
       dscord.types.all,
       dscord.util.emitter;

class Client {
  // User auth token
  string  token;

  // Clients
  APIClient      api;
  GatewayClient  gw;

  // Voice connections
  VoiceClient[Snowflake]  voiceConns;

  // State
  State  state;

  // Emitters
  Emitter  events;
  Emitter  packets;

  this(string token) {
    this.token = token;

    this.api = new APIClient(this.token);
    this.gw = new GatewayClient(this);
    this.state = new State(this);
  }
}
