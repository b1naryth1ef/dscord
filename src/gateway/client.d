module gateway.client;

import std.stdio,
       std.functional,
       std.zlib;

import vibe.core.core,
       vibe.inet.url,
       vibe.http.websockets;

import gateway.packets,
       util.json;

class GatewayClient {
  WebSocket sock;
  string token;

  this(string gatewayURL, string token) {
    this.token = token;
    this.sock = connectWebSocket(URL(gatewayURL));

    runTask(toDelegate(&this.run));
  }

  void send(Serializable p) {
    JSONObject data = p.serialize();
    this.sock.send(data.dumps());
  }

  void run() {
    this.send(new Identify(this.token));

    string data;
    while (this.sock.waitForData()) {
      try {
        ubyte[] rawdata = this.sock.receiveBinary();
        data = cast(string)uncompress(rawdata);
      } catch (Exception e) {
        data = this.sock.receiveText();
      }
      writefln("%s", data);
    }
  }
}
