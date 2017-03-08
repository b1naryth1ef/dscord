module main;

import std.stdio,
       std.algorithm,
       std.string,
       std.format,
       std.conv,
       std.array,
       std.json,
       std.traits,
       std.process,
       core.time;

import vibe.core.core;
import vibe.http.client;
import dcad.types : DCAFile;


import dscord.core,
       dscord.util.process,
       dscord.util.emitter,
       dscord.voice.youtubedl;

import core.sys.posix.signal;
import etc.linux.memoryerror;

import dscord.util.string : camelCaseToUnderscores;

class BasicPlugin : Plugin {
  DCAFile sound;

  this() {
    super();
  }

  @Listener!(MessageCreate, EmitterOrder.AFTER)
  void onMessageCreate(MessageCreate event) {
    this.log.infof("MessageCreate: %s", event.message.content);
  }

  @Command("ping")
  void onPing(CommandEvent event) {
    event.msg.reply(format("Pong: %s", event.msg.author.serializeToJSON));
  }

  //An example command that clears messages in the channel
  @Command("clear")
  void onClearMessages(CommandEvent event) {
    uint limit = 100;

    //This command can take an integer argument.
    if(event.args.length > 0){
      try {
        limit = event.args[0].to!int;
      }
      catch(Exception e){
        event.msg.reply("You must supply a number of messages to clear (100 max).\n```" ~
        this.bot.config.cmdPrefix ~ "clear <number>```");
        return;
      }
    }

    //Delete the command message itself
    event.msg.del();

    try {
      Message[] messages = this.client.getMessages(event.msg.channelID, limit, event.msg.id);

      if(messages.length > 0){
        this.client.deleteMessages(event.msg.channelID, messages);

        event.msg.replyf("I deleted %s messages for you.", messages.length).after(3.seconds).del();
      }
    }
    catch(Exception e){
      event.msg.replyf("%s", e.msg);
      return;
    }

  }

  @Command("sound")
  void onSound(CommandEvent event) {
    auto chan = this.userVoiceChannel(event.msg.guild, event.msg.author);

    if (!chan) {
      event.msg.reply("You are not in a voice channel!");
      return;
    }

    if (!this.sound) {
      this.sound = new DCAFile(File("test.dca", "r"));
    }

    auto playable = new DCAPlayable(this.sound);

    auto vc = chan.joinVoice();

    if (vc.connect()) {
        vc.play(playable).disconnect();
    } else {
      event.msg.reply("Failed :(");
    }

  }

  @Command("whereami")
  void onWhereAmI(CommandEvent event) {
    auto chan = this.userVoiceChannel(event.msg.guild, event.msg.author);
    if (chan) {
      event.msg.reply(format("You're in channel `%s`", chan.name));
    } else {
      event.msg.reply("You are not in a voice channel!");
    }
  }

  @Command("spam")
  void spam(CommandEvent event) {
    for (int i = 0; i < 30; i++) {
      this.client.updateStatus(0, new Game(format("Test #%s", i)));
      sleep(250.msecs);
      this.log.infof("%s", i);
    }
  }

  Channel userVoiceChannel(Guild guild, User user) {
    this.log.infof("k: %s", guild.voiceStates.keys);
    this.log.infof("v: %s", guild.voiceStates.values);

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
  config.cmdPrefix = "";
  Bot bot = new Bot(config, LogLevel.trace);
  bot.loadPlugin(new BasicPlugin);
  bot.run();
  runEventLoop();
  return;
}
