module dscord.bot.plugin;

import std.path,
       std.file;

import std.experimental.logger,
       vibe.d : runTask;

import dscord.client,
       dscord.bot.command,
       dscord.bot.listener,
       dscord.bot.bot,
       dscord.util.storage;

/**
  PluginOptions is a class that can be used to configure the base functionality
  and utilties in use by a plugin.
*/
class PluginOptions {
  /** Does this plugin load/require a configuration file? */
  bool useConfig = false;

  /** Does this plugin load/require a JSON storage file? */
  bool useStorage = false;
}

/**
  PluginState is a class the encapsulates all run-time state required for a
  plugin to exist. It's purpose is to allow for hot-reloading and replacing
  of plugin code, without destroy/rebuilding run-time data.
*/
class PluginState {
  /** Plugin JSON Storage file (for data) */
  Storage        storage;

  /** Plugin JSON Config file */
  Storage        config;

  /** PluginOptions struct **/
  PluginOptions  options;

  this(Plugin plugin, PluginOptions opts) {
    this.options = opts ? opts : new PluginOptions;

    if (this.options.useStorage) {
      this.storage = new Storage(plugin.storagePath);
    }

    if (this.options.useConfig) {
      this.config = new Storage(plugin.configPath);
    }
  }
}

/**
  A Plugin represents a modular, extendable class that encapsulates certain
  Bot functionality into a logical slice. Plugins usually have a set of commands
  and listeners attached to them, and are built to be dynamically loaded/reloaded
  into a Bot.
*/
class Plugin {
  /** Bot instance for this plugin. Should always be set */
  Bot     bot;

  /** Current runtime state for this plugin */
  PluginState  state;

  mixin Listenable;
  mixin Commandable;

  /**
    The path to the dynamic library this plugin was loaded from. If set, this
    signals this Plugin was loaded from a dynamic library, and can be reloaded
    from the given path.
  */
  string dynamicLibraryPath;

  /**
    Pointer to the dynamic library, used for cleaning up on shutdown.
  */
  void* dynamicLibrary;

  /**
    Constructor for initial load. Usually called from the inherited constructor.
  */
  this(this T)(PluginOptions opts = null) {
    this.state = new PluginState(this, opts);

    this.loadCommands!T();
    this.loadListeners!T();
  }

  /**
    Plugin log instance.
  */
  @property Logger log() {
    return this.bot.log;
  }

  /**
    Used to load the Plugin, initially loading state if requred.
  */
  void load(Bot bot, PluginState state = null) {
    this.bot = bot;

    // Make sure our storage directory exists
    if (this.options.useStorage && !exists(this.storageDirectoryPath)) {
      mkdirRecurse(this.storageDirectoryPath);
    }

    // If we got state, assume this was a plugin reload and replace
    if (state) {
      this.state = state;
    } else {
      // If plugin uses storage, load the storage from disk
      if (this.options.useStorage) {
        this.storage.load();
      }

      // If plugin uses config, load the config from disk
      if (this.options.useConfig) {
        this.config.load();
      }
    }
  }

  /**
    Used to unload the Plugin. Saves config/storage if required.
  */
  void unload(Bot bot) {
    if (this.options.useStorage) {
      this.storage.save();
    }

    if (this.options.useConfig) {
      this.config.save();
    }
  }

  /**
    Returns path to this plugins storage directory.
  */
  @property string storageDirectoryPath() {
    return "storage" ~ dirSeparator ~ this.name;
  }

  /**
    Returns path to this plugins storage file.
  */
  @property string storagePath() {
    return this.storageDirectoryPath ~ dirSeparator ~ "storage.json";
  }

  /**
    Returns path to this plugins config file.
  */
  @property string configPath() {
    return "config" ~ dirSeparator ~ this.name ~ ".json";
  }

  /**
   Storage instance for the plugin.
  */
  @property Storage storage() {
    return this.state.storage;
  }

  /**
    Config instance for the plugin.
   */
  @property Storage config() {
    return this.state.config;
  }

  /**
    PluginOptions instance for the plugin.
  */
  @property PluginOptions options() {
    return this.state.options;
  }

  /**
    Client instance for the plugin.
  */
  @property Client client() {
    return this.bot.client;
  }

  /**
    Returns the name of this plugin.
  */
  string name() {
    return typeof(this).toString;
  }
}
