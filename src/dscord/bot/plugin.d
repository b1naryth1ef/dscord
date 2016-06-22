module dscord.bot.plugin;

import std.experimental.logger,
       vibe.d : runTask;

import dscord.bot.command,
       dscord.bot.listener,
       dscord.bot.bot;

struct PluginConfig {}

class Plugin {
  Bot     bot;
  Logger  log;

  mixin Listenable;
  mixin Commandable;

  // Store the path to the DLL for this plugin
  string dynamicLibraryPath;

  // Used to store the void-pointer to the dynamic library (if one exists)
  void* dynamicLibrary;

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
    this.bot.unloadPlugin(this);
  }

  string name() {
    return typeof(this).toString;
  }
}
