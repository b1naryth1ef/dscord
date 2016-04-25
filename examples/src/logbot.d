module main;

import std.stdio,
       std.functional;

import vibe.core.core;
import vibe.http.client;

import dscord.client,
       dscord.gateway.events;

import core.sys.posix.signal;
import etc.linux.memoryerror;

extern (C) {
  void handleSigInt(int value) {
    exitEventLoop();
  }
}

void main(string[] args) {
  sigset(SIGINT, &handleSigInt);
  static if (is(typeof(registerMemoryErrorHandler)))
      registerMemoryErrorHandler();

  if (args.length <= 1) {
    writefln("Usage: %s <token>", args[0]);
    return;
  }

  // Get a new APIClient with our token
  auto client = new Client(args[1]);
  // this.eventEmitter.listen!Ready(toDelegate(&this.handleReadyEvent));

  client.state.events.on("StateStartupComplete", {
    writefln("Startup Complete");

    client.events.listen!MessageCreate((MessageCreate c) {
      writefln("[%s] (%s | %s)\n    %s: %s\n",
        c.message.timestamp,
        c.message.channel_id,
        c.message.author.id,
        c.message.author.username,
        c.message.content);
    });
  });

  client.events.listen!Ready((Ready r) {
    writeln("Ready Complete");
  });

  client.gw.start();
  runEventLoop();
  return;
}
