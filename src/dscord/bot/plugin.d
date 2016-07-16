module dscord.bot.plugin;

import std.path;

import std.experimental.logger,
       vibe.d : runTask;

import dscord.client,
       dscord.bot.command,
       dscord.bot.listener,
       dscord.bot.bot,
       dscord.util.storage;

class PluginOptions {
  bool useConfig = true;
  bool useStorage = true;

  void loadFromConfig(Storage cfg) {
    // TODO: load from 'plugin' object on config
  }
}

class PluginState {
  Storage        storage;
  Storage        config;
  PluginOptions  options;

  this(Plugin plugin, PluginOptions opts) {
    this.options = opts ? opts : new PluginOptions;
    this.storage = new Storage(plugin.storagePath);
    this.config = new Storage(plugin.configPath);
  }
}

class Plugin {
  Bot     bot;
  Logger  log;

  // State
  PluginState  state;

  mixin Listenable;
  mixin Commandable;

  // Store the path to the DLL for this plugin
  string dynamicLibraryPath;

  // Used to store the void-pointer to the dynamic library (if one exists)
  void* dynamicLibrary;

  // Options constructor for initial load
  this(this T)(PluginOptions opts = null) {
    this.state = new PluginState(this, opts);

    this.loadCommands!T();
    this.loadListeners!T();
  }

  void load(Bot bot, PluginState state = null) {
    this.bot = bot;
    this.log = this.bot.log;

    // If we got state, assume this was a plugin reload and replace
    if (state) {
      this.state = state;
    }

    // If plugin uses storage, load the storage from disk
    if (this.options.useStorage) {
      this.storage.load();
    }

    // If plugin uses config, load the config from disk
    if (this.options.useConfig) {
      this.config.load();
    }
  }

  void unload(Bot bot) {
    if (this.options.useStorage) {
      this.storage.save();
    }

    if (this.options.useConfig) {
      this.config.save();
    }
  }

  @property string storagePath() {
    return "storage" ~ dirSeparator ~ this.name ~ ".json";
  }

  @property string configPath() {
    return "config" ~ dirSeparator ~ this.name ~ ".json";
  }

  @property Storage storage() {
    return this.state.storage;
  }

  @property Storage config() {
    return this.state.config;
  }

  @property PluginOptions options() {
    return this.state.options;
  }

  @property Client client() {
    return this.bot.client;
  }

  string name() {
    return typeof(this).toString;
  }
}
