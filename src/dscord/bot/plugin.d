module dscord.bot.plugin;

import dscord.bot.command;

struct PluginConfig {
  string[]  cmdPrefixes = [];
}

class Plugin : CommandHandler {
  PluginConfig cfg;

  this(this T)(PluginConfig cfg) {
    this.cfg = cfg;
    this.loadCommands!T(cfg.cmdPrefixes);
  }
}

