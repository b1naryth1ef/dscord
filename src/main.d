module main;

import std.stdio;

import vibe.core.core;
import vibe.inet.url;
import vibe.http.websockets;
import vibe.http.client;

import api.client,
       types.base;

void main() {
  runTask(() {
    auto client = new APIClient(":D");
    auto me = client.me();
    writefln("id: %s", me.id);
    writefln("username: %s", me.username);

    foreach (ref guild; me.guilds) {
      writefln("guild: %s", guild.id);
    }

    writefln("guild: %s", me.guildCache.get());
    writefln("guild: %s", me.guild(Snowflake(157733188964188160)));
    writefln("guild: %s", me.getGuild(Snowflake(157733188964188160)));
  });

  runEventLoop();
  return;
  /* auto ws = connectWebSocket(URL("ws://echo.websocket.org")); */
  /*  */
  /* ws.send("test"); */
  /*  */
  /* while (ws.waitForData()) { */
  /*   writefln("%s", ws.receiveText()); */
  /*   break; */
  /* } */
  /*  */
  /* writefln("%s", ws.connected); */
}
