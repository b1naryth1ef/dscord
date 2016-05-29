module dscord.bot.bot;

import std.algorithm,
       std.array,
       std.experimental.logger,
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

  this(this T)(BotConfig bc, LogLevel lvl=LogLevel.all) {
    this.config = bc;
    this.client = new Client(this.config.token, lvl);
    this.log = this.client.log;

    if (this.feature(BotFeatures.COMMANDS)) {
      this.client.events.listen!MessageCreate(&this.onMessageCreate);
    }

    this.loadCommands!T([]);
  }

  void addPlugin(Plugin p) {
    this.plugins ~= p;
    p.log = this.log;
    this.inheritCommands(p);
  }

  bool feature(BotFeatures[] features...) {
    return (this.config.features & reduce!((a, b) => a & b)(features)) > 0;
  }

  void tryHandleCommand(CommandEvent event) {
    // If we require a mention, make sure we got it
    if (this.config.cmdRequireMention) {
      if (!event.msg.mentions.length) {
        return;
      } else if (!event.msg.mentions.has(this.client.state.me.id)) {
        return;
      }
    }

    string contents = strip(event.msg.withoutMentions);

    if (!contents.startsWith(this.config.cmdPrefix)) {
      return;
    }

    // Iterate over commands and find a matcher
    // TODO: in the future this could be a btree
    CommandObj *obj;
    string cmdPrefix;
    foreach (ref k, v; this.commands) {
      if (contents.startsWith(k)) {
        cmdPrefix = k;
        obj = v;
        break;
      }
    }

    // If no command was found, skip
    if (!obj) {
      return;
    }

    // Extract some stuff for the CommandEvent
    event.contents = contents[(this.config.cmdPrefix.length + cmdPrefix.length)..contents.length];
    event.args = event.contents.split(" ");

    if (event.args.length && event.args[0] == "") {
      event.args = event.args[1..event.args.length];
    }

    // Check permissions
    if (this.config.lvlEnabled) {
      if (this.config.lvlGetter(event.msg.author) < obj.level) {
        return;
      }
    }

    obj.f(event);
  }

  void onMessageCreate(MessageCreate event) {
    if (this.feature(BotFeatures.COMMANDS)) {
      this.tryHandleCommand(new CommandEvent(event));
    }
  }

  void run() {
    client.gw.start();
  }
};
