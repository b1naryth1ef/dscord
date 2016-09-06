/**
  Base class for creating plugins the Bot can load/unload.
*/

module dscord.bot.plugin;

import std.path,
       std.file,
       std.variant;

import std.experimental.logger,
       vibe.d : runTask;

import dscord.bot,
       dscord.types,
       dscord.client,
       dscord.util.dynlib,
       dscord.util.storage;

/**
  Sentinel for @Synced attributes
  TODO: this is messy. Better way to achieve a sentinel?
*/
struct SyncedAttribute {
  string syncedAttributeSentinel;
};

/**
  UDA which tells StateSyncable that a member attribute should be synced into
  the state on plugin load/unload.
*/
SyncedAttribute Synced() {
  return SyncedAttribute();
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

  /** PluginOptions struct */
  PluginOptions  options;

  /** Custom state data stored by the plugin */
  Variant[string] custom;

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
  The StateSyncable template is an implementation which handles the syncing of
  member attributes into are PluginState.custom store during plugin load/unload.
  This allows plugin developers to simply attach the @Synced UDA to any attributes
  they wish to be stored, and then call stateLoad and stateUnload in the plugin
  load/unload functions.
*/
mixin template StateSyncable() {
  /// Loads all custom attribute state from a PluginState.
  void stateLoad(T)(PluginState state) {
    foreach (mem; __traits(allMembers, T)) {
      foreach (attr; __traits(getAttributes, __traits(getMember, T, mem))) {
        static if(__traits(hasMember, attr, "syncedAttributeSentinel")) {
          if (mem in state.custom && state.custom[mem].hasValue()) {
            mixin("(cast(T)this)." ~ mem ~ " = " ~ "state.custom[\"" ~ mem ~ "\"].get!(typeof(__traits(getMember, T, mem)));");
          }
        }
      }
    }
  }

  /// Unloads all custom attributes into a PluginState.
  void stateUnload(T)(PluginState state) {
    foreach (mem; __traits(allMembers, T)) {
      foreach (attr; __traits(getAttributes, __traits(getMember, T, mem))) {
        static if(__traits(hasMember, attr, "syncedAttributeSentinel")) {
          mixin("state.custom[\"" ~ mem ~ "\"] = " ~  "Variant((cast(T)this)." ~ mem ~ ");");
        }
      }
    }
  }
}

/**
  PluginOptions is a class that can be used to configure the base functionality
  and utilties in use by a plugin.
*/
class PluginOptions {
  /** Does this plugin load/require a configuration file? */
  bool useConfig = false;

  /** Does this plugin load/require a JSON storage file? */
  bool useStorage = false;

  /** Does this plugin auto-load level/command overrides from its config? */
  bool useOverrides = false;

  /** Default command group to use */
  string commandGroup = "";
}

/**
  A Plugin represents a modular, extendable class that encapsulates certain
  Bot functionality into a logical slice. Plugins usually have a set of commands
  and listeners attached to them, and are built to be dynamically loaded/reloaded
  into a Bot.
*/
class Plugin {
  /// Bot instance for this plugin. Should always be set
  Bot     bot;

  /// Current runtime state for this plugin
  PluginState  state;

  mixin Listenable;
  mixin Commandable;
  mixin StateSyncable;

  /**
    The path to the dynamic library this plugin was loaded from. If set, this
    signals this Plugin was loaded from a dynamic library, and can be reloaded
    from the given path.
  */
  string dynamicLibraryPath;

  /// Pointer to the dynamic library, used for cleaning up on shutdown.
  DynamicLibrary dynamicLibrary;

  /// Constructor for initial load. Usually called from the inherited constructor.
  this(this T)(PluginOptions opts = null) {
    this.state = new PluginState(this, opts);

    this.loadCommands!T();
    this.loadListeners!T();
  }

  /// Plugin log instance.
  @property Logger log() {
    return this.bot.log;
  }

  /// Used to load the Plugin, initially loading state if requred.
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
        this.storage.save();
      }

      // If plugin uses config, load the config from disk
      if (this.options.useConfig) {
        this.config.load();
        this.config.save();
      }
    }

    if (this.options.useOverrides) {
      if (this.config.has("levels")) {
        auto levels = this.config.get!(VibeJSON[string])("levels");

        foreach (name, level; levels) {
          auto cmd = this.commands[name];
          cmd.level = level.get!int;
        }
      }

      string group = this.config.get!string("group", this.options.commandGroup);
      if (group != "") {
        foreach (command; this.commands.values) {
          command.setGroup(group);
        }
      }
    }
  }

  /// Used to unload the Plugin. Saves config/storage if required.
  void unload(Bot bot) {
    if (this.options.useStorage) {
      this.storage.save();
    }

    if (this.options.useConfig) {
      this.config.save();
    }
  }

  /// Returns path to this plugins storage directory.
  @property string storageDirectoryPath() {
    return "storage" ~ dirSeparator ~ this.name;
  }

  /// Returns path to this plugins storage file.
  @property string storagePath() {
    return this.storageDirectoryPath ~ dirSeparator ~ "storage.json";
  }

  /// Returns path to this plugins config file.
  @property string configPath() {
    return "config" ~ dirSeparator ~ this.name ~ ".json";
  }

  /// Storage instance for this plugin.
  @property Storage storage() {
    return this.state.storage;
  }

  /// Config instance for this plugin
  @property Storage config() {
    return this.state.config;
  }

  /// PluginOptions for this plugin
  @property PluginOptions options() {
    return this.state.options;
  }

  /// Client instance for the Bot running this plugin
  @property Client client() {
    return this.bot.client;
  }

  /// User instance for the account this bot is running under
  @property User me() {
    return this.client.state.me;
  }

  /// Returns the name of this plugin.
  string name() {
    return typeof(this).toString;
  }
}
