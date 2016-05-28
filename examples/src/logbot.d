module main;

import std.stdio,
       std.functional,
       std.algorithm,
       std.string,
       std.format,
       std.conv,
       std.array,
       core.time;

import vibe.core.core;
import vibe.http.client;
import dcad.types : DCAFile;


import dscord.core;

import core.sys.posix.signal;
import etc.linux.memoryerror;

extern (C) {
  void handleSigInt(int value) {
    exitEventLoop();
  }
}

class LogBot : Bot {
  this(string token) {
    BotConfig bc;
    bc.token = token;
    super(bc);
  }

  @Command("test")
  void onTestCommand(MessageCreate event) {
    event.message.reply("IT WORKS!");
  }

  Channel userVoiceChannel(Guild guild, User user) {
    auto states = guild.voiceStates.filter(s => s.user_id == user.id).array;
    if (!states.length) return null;
    return states[0].channel;
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

  (new LogBot(args[1])).run();
  runEventLoop();
  return;
}
