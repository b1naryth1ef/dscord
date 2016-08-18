/**
  A simple but extendable Discord bot implementation.
*/

module dscord.bot.bot;

import std.algorithm,
       std.array,
       std.experimental.logger,
       std.regex,
       std.functional,
       std.string : strip, toStringz, fromStringz;

import dscord.client,
       dscord.bot.command,
       dscord.bot.plugin,
       dscord.types.all,
       dscord.gateway.events,
       dscord.util.errors;

version (linux) {
  import core.stdc.stdio;
  import core.stdc.stdlib;
  import core.sys.posix.dlfcn;
}

/**
  Feature flags that can be used to toggle behavior of the Bot interface.
*/
enum BotFeatures {
  /** This bot will parse/dispatch commands */
  COMMANDS = 1 << 1,
}

/**
  Configuration that can be used to control the behavior of the Bot.
*/
struct BotConfig {
  /** API Authentication Token */
  string  token;

  /** This bot instances shard number */
  ushort shard = 0;

  /** The total number of shards */
  ushort numShards = 1;

  /** Bitwise flags from `BotFeatures` */
  uint    features = BotFeatures.COMMANDS;

  /** Command prefix (can be empty for none) */
  string  cmdPrefix = "!";

  /** Whether the bot requires mentioning to respond */
  bool    cmdRequireMention = true;

  /** Whether the bot should use permission levels */
  bool    levelsEnabled = false;

  @property ShardInfo* shardInfo() {
    return new ShardInfo(this.shard, this.numShards);
  }
}

/**
  The Bot class is an extensible, fully-featured base for building Bots with the
  dscord library. It was meant to serve as a base class that can be extended in
  seperate projects.
*/
class Bot {
  Client     client;
  BotConfig  config;
  Logger  log;

  Plugin[string]  plugins;

  this(this T)(BotConfig bc, LogLevel lvl=LogLevel.all) {
    this.config = bc;
    this.client = new Client(this.config.token, lvl, this.config.shardInfo);
    this.log = this.client.log;

    if (this.feature(BotFeatures.COMMANDS)) {
      this.client.events.listen!MessageCreate(&this.onMessageCreate);
    }
  }

  /**
    Loads a plugin into the bot, optionally restoring previous plugin state.
  */
  void loadPlugin(Plugin p, PluginState state = null) {
    p.load(this, state);
    this.plugins[p.name] = p;

    // Bind listeners
    foreach (ref listener; p.listeners) {
      this.log.infof("Registering listener for event %s", listener.clsName);
      listener.listener = this.client.events.listenRaw(listener.clsName, toDelegate(listener.func));
    }
  }

  // Dynamic library plugin loading (linux only currently)
  version (linux) {
    /**
      Loads a plugin from a dynamic library, optionally restoring previous plugin
      state.
    */
    Plugin dynamicLoadPlugin(string path, PluginState state) {
      // Attempt to load the dynamic library from a given path
      void* lh = dlopen(toStringz(path), RTLD_NOW);
      if (!lh) {
        throw new BaseError("Failed to dynamically load plugin: %s", fromStringz(dlerror()));
      }

      // Try to grab the create function (which should return a new plugin instance)
      Plugin function() fn = cast(Plugin function())dlsym(lh, "create");
      char* error = dlerror();
      if (error) {
        throw new BaseError("Failed to dynamically load plugin create function: %s", fromStringz(error));
      }

      // Finally create the plugin instance and register it.
      Plugin p = fn();
      this.loadPlugin(p, state);

      // Track the DLL handle so we can close it when unloading
      p.dynamicLibrary = lh;
      p.dynamicLibraryPath = path;
      return p;
    }

    /**
      Reloads a plugin which was previously loaded as a dynamic library. This
      function restores previous plugin state.
    */
    Plugin dynamicReloadPlugin(Plugin p) {
      string path = p.dynamicLibraryPath;
      PluginState state = p.state;
      this.unloadPlugin(p);
      return this.dynamicLoadPlugin(path, state);
    }

    // not linux
    } else {

    Plugin dynamicLoadPlugin(string path, PluginState state) {
      throw new BaseError("Dynamic plugins are only supported on linux");
    }

    Plugin dynamicReloadPlugin(Plugin p) {
      throw new BaseError("Dynamic plugins are only supported on linux");
    }
  }

  /**
    Unloads a plugin from the bot, unbinding all listeners and commands.
  */
  void unloadPlugin(Plugin p) {
    p.unload(this);
    this.plugins.remove(p.name);

    foreach (ref listener; p.listeners) {
      listener.listener.unbind();
    }

    // Loaded dynamically, close the DLL
    version (linux) {
      if (p.dynamicLibrary) {
        void* lh = p.dynamicLibrary;
        p.destroy();
        dlclose(lh);
      }
    }
  }

  /**
    Unloads a plugin from the bot by name.
  */
  void unloadPlugin(string name) {
    this.unloadPlugin(this.plugins[name]);
  }

  /**
    Returns true if the current bot instance/configuration supports all of the
    passed BotFeature flags.
  */
  bool feature(BotFeatures[] features...) {
    return (this.config.features & reduce!((a, b) => a & b)(features)) > 0;
  }

  private void tryHandleCommand(CommandEvent event) {
    // If we require a mention, make sure we got it
    if (this.config.cmdRequireMention) {
      if (!event.msg.mentions.length) {
        return;
      } else if (!event.msg.mentions.has(this.client.state.me.id)) {
        return;
      }
    }

    // Strip all mentions and spaces from the message
    string contents = strip(event.msg.withoutMentions);

    // If the message doesn't start with the command prefix, break
    if (this.config.cmdPrefix.length) {
      if (!contents.startsWith(this.config.cmdPrefix)) {
        return;
      }

      // Replace the command prefix from the string
      contents = contents[this.config.cmdPrefix.length..contents.length];
    }

    // Iterate over all plugins and check for command matches
    Captures!string capture;
    foreach (ref plugin; this.plugins.values) {
      foreach (ref command; plugin.commands) {
        if (!command.enabled) continue;

        auto c = command.match(contents);
        if (c.length) {
          event.cmd = command;
          capture = c;
          break;
        }
      }
    }

    // If we didn't match any CommandObject, carry on our merry way
    if (!capture) {
      return;
    }

    // Extract some stuff for the CommandEvent
    event.contents = strip(capture.post());
    event.args = event.contents.split(" ");

    if (event.args.length && event.args[0] == "") {
      event.args = event.args[1..event.args.length];
    }

    // Check permissions (if enabled)
    if (this.config.levelsEnabled) {
      if (this.getLevel(event) < event.cmd.level) {
        return;
      }
    }

    event.cmd.func(event);
  }

  private void onMessageCreate(MessageCreate event) {
    if (this.feature(BotFeatures.COMMANDS)) {
      this.tryHandleCommand(new CommandEvent(event));
    }
  }

  /**
    Starts the bot.
  */
  void run() {
    client.gw.start();
  }

  /// Base implementation for getting a level from a user. Override this.
  int getLevel(User user) {
    return 0;
  }

  /// Override implementation for getting a level from a user (for command handling)
  int getLevel(CommandEvent event) {
    return this.getLevel(event.msg.author);
  }
};
