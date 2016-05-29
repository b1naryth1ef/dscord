module dscord.bot.plugin;

import std.experimental.logger;

import dscord.bot.command;

struct PluginConfig {
  string[]  cmdPrefixes = [];
}

class Plugin : CommandHandler {
  PluginConfig cfg;
  Logger  log;

  this(this T)(PluginConfig cfg) {
    this.cfg = cfg;
    this.loadCommands!T(cfg.cmdPrefixes);
  }
}

