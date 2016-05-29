module dscord.bot.plugin;

import std.experimental.logger;

import dscord.bot.command,
       dscord.bot.listener,
       dscord.bot.bot;

struct PluginConfig {}

class Plugin {
  Bot     bot;
  Logger  log;

  mixin Listenable;
  mixin Commandable;

  // Config for the plugin
  PluginConfig cfg;

  this(this T)(PluginConfig cfg) {
    this.cfg = cfg;
    this.loadCommands!T();
    this.loadListeners!T();
  }

  void load(Bot bot) {
    this.bot = bot;
    this.log = this.bot.log;
  }

  void unload() {

  }

  string name() {
    return typeof(this).toString;
  }
}
