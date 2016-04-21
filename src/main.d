module main;

import std.stdio;

import vibe.core.core;
import vibe.http.client;

import api.client,
       gateway.client,
       types.base;

import etc.linux.memoryerror;

void main(string[] args) {
  static if (is(typeof(registerMemoryErrorHandler)))
      registerMemoryErrorHandler();

  if (args.length <= 1) {
    writefln("Usage: %s <token>", args[0]);
    return;
  }

  writeln(args[1]);

  auto client = new APIClient(args[1]);
  auto me = client.me();
  writefln("id: %s", me.id);
  writefln("username: %s", me.username);

  foreach (ref guild; me.guilds) {
    writefln("guild: %s", guild.id);
  }

  writefln("guild: %s", me.guildCache.get());
  writefln("guild: %s", me.guild(Snowflake(157733188964188160)));
  writefln("guild: %s", me.getGuild(Snowflake(157733188964188160)));

  auto gw = new GatewayClient(client.gateway(), args[1]);

  runEventLoop();
  return;
}
