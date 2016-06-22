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

enum BotFeatures {
  COMMANDS = 1 << 1,
}

struct BotConfig {
  string  token;
  uint    features = BotFeatures.COMMANDS;

  string  cmdPrefix = "!";
  bool    cmdRequireMention = true;

  // Used to grab the level for a user
  uint delegate(User)  lvlGetter;

  // Props and stuff
  @property lvlEnabled() {
    return this.lvlGetter != null;
  }
}

class Bot {
  Client     client;
  BotConfig  config;
  Logger  log;

  Plugin[string]  plugins;

  this(this T)(BotConfig bc, LogLevel lvl=LogLevel.all) {
    this.config = bc;
    this.client = new Client(this.config.token, lvl);
    this.log = this.client.log;

    if (this.feature(BotFeatures.COMMANDS)) {
      this.client.events.listen!MessageCreate(&this.onMessageCreate);
    }
  }

  void loadPlugin(Plugin p) {
    p.load(this);
    this.plugins[p.name] = p;

    // Bind listeners
    foreach (ref listener; p.listeners) {
      this.log.infof("Registering listener for event %s", listener.clsName);
      listener.listener = this.client.events.listenRaw(listener.clsName, toDelegate(listener.func));
    }
  }

  // Dynamic library plugin loading (linux only currently)
  version (linux) {
    void dynamicLoadPlugin(string path) {

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
      this.loadPlugin(p);

      // Track the DLL handle so we can close it when unloading
      p.dynamicLibrary = lh;
    }
  } else {
    void dynamicLoadPlugin(string path) {
      throw new BaseError("Dynamic plugin loading is only supported on linux");
    }
  }

  void unloadPlugin(Plugin p) {
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

  void unloadPlugin(string name) {
    this.unloadPlugin(this.plugins[name]);
  }

  bool feature(BotFeatures[] features...) {
    return (this.config.features & reduce!((a, b) => a & b)(features)) > 0;
  }

  void tryHandleCommand(CommandEvent event) {
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
    CommandObject obj;
    foreach (ref plugin; this.plugins.values) {
      foreach (ref command; plugin.commands) {
        if (!command.enabled) continue;

        auto c = command.match(contents);
        if (c.length) {
          obj = command;
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

    // Check permissions
    if (this.config.lvlEnabled) {
      if (this.config.lvlGetter(event.msg.author) < obj.level) {
        return;
      }
    }

    obj.func(event);
  }

  void onMessageCreate(MessageCreate event) {
    if (this.feature(BotFeatures.COMMANDS)) {
      this.tryHandleCommand(new CommandEvent(event));
    }
  }

  void run() {
    client.gw.start();
  }
};
