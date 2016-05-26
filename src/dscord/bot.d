module dscord.bot;

import std.algorithm,
       std.string : strip;

import dscord.client,
       dscord.types.all,
       dscord.gateway.events;

enum BotFeatures {
  COMMANDS = 1 << 1,
}

CommandObj Command(string trigger, string desc = "", uint level = 0) {
  return CommandObj(trigger, desc, level);
}

CommandObj Command(string trigger, uint level) {
  return CommandObj(trigger, "", level);
}

struct CommandObj {
  string  trigger;
  string  description = "";
  uint    level = 0;

  void delegate(MessageCreate) f;
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

template Plugin(T) {
  override void loadCommands() {
    foreach (mem; __traits(allMembers, T)) {
      foreach(attr; __traits(getAttributes, __traits(getMember, T, mem))) {
        static if (is(typeof(attr) == CommandObj)) {
          this.log.tracef("Adding command %s", attr.trigger);
          this.registerCommand(attr, mixin("&" ~ mem));
        }
      }
    }
  }
}

class Bot {
  Client     client;
  BotConfig  config;
  Logger  log;

  CommandObj[string]  commands;

  this(BotConfig bc) {
    this.config = bc;
    this.client = new Client(this.config.token);
    this.log = this.client.log;

    if (this.feature(BotFeatures.COMMANDS)) {
      this.client.events.listen!MessageCreate(&this.onMessageCreate);
      this.loadCommands();
    }

  }

  void registerCommand(CommandObj c, void delegate(MessageCreate) f) {
    c.f = f;
    this.commands[c.trigger] = c;
  }

  void loadCommands() {}

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
