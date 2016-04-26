module main;

import std.stdio,
       std.functional,
       std.algorithm,
       std.string,
       std.format,
       std.conv;

import vibe.core.core;
import vibe.http.client;

import dscord.client,
       dscord.gateway.events,
       dscord.util.counter;

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

  Counter!string counter = new Counter!string();

  // Get a new APIClient with our token
  auto client = new Client(args[1]);
  // this.eventEmitter.listen!Ready(toDelegate(&this.handleReadyEvent));

  client.events.listenAll((name, value) {
    counter.tick(name);
    // writefln("EVENT %s", name);
  });

  client.events.listen!MessageCreate((event) {
    if (event.message.mentions.length) {
      if (event.message.mentions.has(client.state.me.id)) {
        writefln("%s", event.message.content);
        if (event.message.content.endsWith(".events")) {
          auto top5 = counter.mostCommon(5);

          string[] parts;
          foreach (e; counter.mostCommon(5)) {
            parts ~= format("%s: %s", e, counter.storage[e]);
          }
          event.message.reply(format("```%s```", parts.join("\n")).to!wstring);
        } else if (event.message.content.endsWith(".stats")) {
          string[] parts;

          parts ~= format("Users: %s", client.state.users.length);
          parts ~= format("Guilds: %s", client.state.guilds.length);
          event.message.reply(format("```%s```", parts.join("\n")).to!wstring);
        }
      }
    }
  });

  client.state.on("StateStartupComplete", {
    writefln("Startup Complete");

    /*
    client.events.listen!MessageCreate((MessageCreate c) {
      writefln("[%s] (%s | %s)\n    %s: %s\n",
        c.message.timestamp,
        c.message.channel_id,
        c.message.author.id,
        c.message.author.username,
        c.message.content);
    });
    */
  });

  client.events.listen!Ready((Ready r) {
    writeln("Ready Complete");
  });

  client.gw.start();
  runEventLoop();
  return;
}
