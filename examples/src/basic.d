module main;

import std.stdio,
       std.algorithm,
       std.string,
       std.format,
       std.conv,
       std.array,
       std.process,
       core.time;

import std.experimental.logger;

import vibe.core.core;
import vibe.http.client;
import dcad.types : DCAFile;

import dscord.core;

import core.sys.posix.signal;
import etc.linux.memoryerror;

import dscord.util.process;

class BasicPlugin : Plugin {
  DCAFile sound;

  this() {
    super();

  }

  @Command("test")
  @CommandDescription("HI")
  void onTestCommand(CommandEvent event) {
    auto chan = this.userVoiceChannel(event.msg.guild, event.msg.author);

    if (!chan) {
      event.msg.reply("You are not in a voice channel!");
      return;
    }

    auto sound = new DCAFile(File("test.dca", "r"));
    auto vc = chan.joinVoice();

    if (vc.connect()) {
      event.msg.replyf("OK: %s", vc);
      vc.playDCAFile(sound);
      sleep(1.seconds);
      vc.disconnect();
    } else {
      event.msg.reply("it dont work");
    }
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

  @Command("play")
  @CommandDescription("Play audio from a URL")
  void onPlayCommand(CommandEvent event) {
    auto chan = this.userVoiceChannel(event.msg.guild, event.msg.author);

    if (!chan) {
      event.msg.reply("You are not in a voice channel!");
      return;
    }

    if (event.args.length < 1) {
      event.msg.reply("Usage: play <url>");
      return;
    }

    auto msg = event.msg.reply("Downloading and encoding link...");

    // Create a download -> encode process chain
    auto chain = new ProcessChain().
      run(["youtube-dl", "-v", "-f", "bestaudio", "-o", "-", event.args[0]]).
      run(["ffmpeg", "-i", "pipe:0", "-f", "s16le", "-ar", "48000", "-ac", "2", "pipe:1"]).
      run(["dca", "-raw", "-i", "pipe:0"]);

    // Create a DCAFile loader for the chain stream
    DCAFile result = DCAFile.fromRawDCA(chain.end);

    // Wait for the chain to complete
    if (chain.wait() != 0) {
      msg.edit("Failed to download... :crying_cat_face:");
      return;
    }

    msg.edit("OK! Playing jams...");

    auto vc = chan.joinVoice();
    if (vc.connect()) {
      sleep(1.seconds);
      vc.playDCAFile(result);
      sleep(1.seconds);
      vc.disconnect();
    }
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
  config.cmdPrefix = "";
  Bot bot = new Bot(config, LogLevel.trace);
  bot.loadPlugin(new BasicPlugin);
  bot.run();
  runEventLoop();
  return;
}
