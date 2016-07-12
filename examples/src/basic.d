module main;

import std.stdio,
       std.functional,
       std.algorithm,
       std.string,
       std.format,
       std.conv,
       std.array,
       core.time;

import std.experimental.logger;

import vibe.core.core;
import vibe.http.client;
import dcad.types : DCAFile;


import dscord.core;

import core.sys.posix.signal;
import etc.linux.memoryerror;

class BasicPlugin : Plugin {
  this() {
    super();
  }

  @Command("test")
  void onTestCommand(CommandEvent event) {
    event.msg.reply("IT WORKS!");
  }

  @Command("whereami")
  void onWhereAmI(CommandEvent event) {
    auto chan = this.userVoiceChannel(event.msg.guild, event.msg.author);
    if (chan) {
      event.msg.reply(format("Your in channel `%s`", chan.name));
    } else {
      event.msg.reply("You are not in a voice channel!");
    }
  }

  @Listener!MessageCreate()
  void onMessageCreate(MessageCreate event) {
    this.log.infof("Got message: %s", event.message.mentioned);
  }

  Channel userVoiceChannel(Guild guild, User user) {
    auto state = guild.voiceStates.pick(s => s.userID == user.id);
    if (!state) return null;
    return state.channel;
  }
}


void main(string[] args) {
  static if (is(typeof(registerMemoryErrorHandler)))
      registerMemoryErrorHandler();

  if (args.length <= 1) {
    writefln("Usage: %s <token>", args[0]);
    return;
  }

  BotConfig config;
  config.token = args[1];
  Bot bot = new Bot(config, LogLevel.trace);
  bot.loadPlugin(new BasicPlugin);
  bot.run();
  runEventLoop();
  return;
}
