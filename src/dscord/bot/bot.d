module dscord.bot.bot;

import std.algorithm,
       std.string : strip;

import dscord.client,
       dscord.bot.command,
       dscord.bot.plugin,
       dscord.types.all,
       dscord.gateway.events;

enum BotFeatures {
  COMMANDS = 1 << 1,
}

struct BotConfig {
  string  token;
  uint    features = BotFeatures.COMMANDS;

  string  cmdPrefix = "!";
  bool    cmdRequireMention = true;

  // Used to grab the level for a user
  uint delegate(User)  lvlGetter;

  // Props and stuff
  @property lvlEnabled() {
    return this.lvlGetter != null;
  }
}

class Bot : CommandHandler {
  Client     client;
  BotConfig  config;
  Logger  log;

  Plugin[]  plugins;

  this(this T)(BotConfig bc) {
    this.config = bc;
    this.client = new Client(this.config.token);
    this.log = this.client.log;

    if (this.feature(BotFeatures.COMMANDS)) {
      this.client.events.listen!MessageCreate(&this.onMessageCreate);
    }

    this.loadCommands!T([]);
  }

  void addPlugin(Plugin p) {
    this.plugins ~= p;
    this.inheritCommands(p);
  }

  bool feature(BotFeatures[] features...) {
    return (this.config.features & reduce!((a, b) => a & b)(features)) > 0;
  }

  void tryHandleCommand(MessageCreate event) {
    auto msg = event.message;

    // If we require a mention, make sure we got it
    if (this.config.cmdRequireMention) {
      if (!msg.mentions.length) {
        return;
      } else if (!msg.mentions.has(this.client.state.me.id)) {
        return;
      }
    }

    string contents = strip(msg.withoutMentions);

    if (!contents.startsWith(this.config.cmdPrefix)) {
      return;
    }

    string cmdName = contents[this.config.cmdPrefix.length..contents.length];
    if ((cmdName in this.commands) == null) {
      return;
    }

    auto cmdObj = this.commands[cmdName];
    if (this.config.lvlEnabled) {
      if (this.config.lvlGetter(msg.author) < cmdObj.level) {
        return;
      }
    }

    cmdObj.f(event);
  }

  void onMessageCreate(MessageCreate event) {
    if (this.feature(BotFeatures.COMMANDS)) {
      this.tryHandleCommand(event);
    }
  }

  void run() {
    client.gw.start();
  }
};
