module main;

import std.stdio,
       std.functional;

import vibe.core.core;
import vibe.http.client;

import client,
       gateway.events;

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
  client.gw.start();

  client.state.onStartupComplete = {
    writefln("Startup Complete");

    client.gw.onEvent!MessageCreate((MessageCreate c) {
      writefln("[%s] (%s | %s)\n    %s: %s\n",
        c.message.timestamp,
        c.message.channel.id,
        c.message.author.id,
        c.message.author.username,
        c.message.content);
    });
  };

  client.gw.onEvent!Ready((Ready r) {
    writeln("Ready Complete");
  });

  runEventLoop();
  return;
}
