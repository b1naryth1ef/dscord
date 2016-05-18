module dscord.bot;

import std.algorithm;

import dscord.client,
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
}

class Bot {
  Client     client;
  BotConfig  config;

  private {
    Logger  log;
  }

  this(BotConfig bc) {
    this.config = bc;
    this.client = new Client(this.config.token);
    this.log = this.client.log;

    if (this.feature(BotFeatures.COMMANDS)) {
      this.client.events.listen!MessageCreate(&this.onMessageCreate);
    }
  }

  bool feature(BotFeatures[] features...) {
    return (this.config.features & reduce!((a, b) => a & b)(features)) > 0;
  }

  void tryHandleCommand(Message msg) {
    // If we require a mention, make sure we got it
    if (this.config.cmdRequireMention) {
      if (!msg.mentions.length) {
        return;
      } else if (!msg.mentions.has(this.client.state.me)) {
        return;
      }
    }
  }

  void onMessageCreate(MessageCreate event) {
    auto msg = event.message;

    if (this.feature(BotFeatures.COMMANDS)) {
      this.tryHandleCommand(msg);
    }
  }

  void run() {
    client.gw.start();
  }
};
