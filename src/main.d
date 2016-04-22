module main;

import std.stdio,
       std.functional;

import vibe.core.core;
import vibe.http.client;

import client,
       gateway.events;

import etc.linux.memoryerror;

void main(string[] args) {
  static if (is(typeof(registerMemoryErrorHandler)))
      registerMemoryErrorHandler();

  if (args.length <= 1) {
    writefln("Usage: %s <token>", args[0]);
    return;
  }

  // Get a new APIClient with our token
  auto client = new Client(args[1]);
  client.gw.start();

  client.state.onStartupComplete = {
    writefln("Startup Complete");

    auto guild = client.state.guild(157733188964188160);
    guild.channels[171767883125358592].sendMessage("this is a test");
  };

  client.gw.onEvent!Ready((Ready r) {
    writeln("Ready Complete");
  });

  runEventLoop();
  return;
}
