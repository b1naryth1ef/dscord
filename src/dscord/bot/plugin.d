module dscord.bot.plugin;

import std.experimental.logger;

import dscord.bot.command,
       dscord.bot.bot;

struct PluginConfig {}

class Plugin : Commandable {
  Bot     bot;
  Logger  log;

  // Config for the plugin
  PluginConfig cfg;

  this(this T)(PluginConfig cfg) {
    this.cfg = cfg;
    this.loadCommands!T();
  }

  void load(Bot bot) {
    this.bot = bot;
  }

  void unload() {

  }

  string name() {
    return typeof(this).toString;
  }
}
