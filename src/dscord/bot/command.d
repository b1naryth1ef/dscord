/**
  Utilities for building user-controlled commands with the dscord bot interface
*/

module dscord.bot.command;

import std.regex,
       std.array,
       std.algorithm,
       std.string;

import dscord.types,
       dscord.gateway;

/// Commands are members of Plugin class or classes which inherit from it. See: examples/src/basic.d
/// Example usage:
///
/// @Command("hello", "hello2")    //The command may respond to multiple triggers.
/// @Enabled(true)                 //false turns the command off. It may be re-enabled elsewhere in code at run-time.
/// @Description("A command that says 'hello' in channel.")    //A description of what the command does.
/// @Group("Leet")                 //The group this command can respond to.
/// @RegEx(true)                   //Defaults to true, but can disable RegEx handling for command triggers.
/// @CommandLevel(1)               //The power level that the command requires ( normal = 1, mod = 50, admin = 100,)
/// void onHello(CommandEvent event) {
///    event.msg.reply("Hello, world!");
/// }
//Easy aliases to use for UDAs
//A UDA that can be used to flag a function as a command handler in a Plugin.
alias Command = CommandConfig!TypeTriggers;
alias Enabled = CommandConfig!TypeEnabled;
alias Description = CommandConfig!TypeDescription;
alias Group = CommandConfig!TypeGroup;
alias RegEx = CommandConfig!TypeRegEx;
alias CommandLevel = CommandConfig!TypeLevel;

//Aliases for deprecated UDAs
alias CommandDescription = CommandConfig!TypeDescription;
alias CommandGroup = CommandConfig!TypeGroup;
alias CommandRegex = CommandConfig!TypeRegEx;

//Custom types to select which CommandConfig details we get.
//Note: The names *must* correspond to property names in CommandObject.
enum TypeEnabled = "enabled";
enum TypeTriggers = "triggers";
enum TypeDescription = "description";
enum TypeRegEx = "useRegex";
enum TypeGroup = "group";
enum TypeLevel = "level";

//Template overloads for implementations of each type of CommandConfig info
template CommandConfig(alias T) if(T==TypeTriggers){
  static struct CommandConfig {
    this(string[] args...){
      triggers = args.dup;
    }
    string[] triggers;
  }
}
template CommandConfig(alias T) if(T == TypeEnabled){
  static struct CommandConfig { bool enabled; }
}
template CommandConfig(alias T) if(T == TypeDescription){
  static struct CommandConfig { string description; }
}
template CommandConfig(alias T) if(T == TypeGroup){
  static struct CommandConfig { string group; }
}
template CommandConfig(alias T) if(T == TypeRegEx){
  static struct CommandConfig { bool regex; }
}
template CommandConfig(alias T) if(T == TypeLevel){
  static struct CommandConfig { int level; }
}

/**
  Base set of levels plugins can use.
*/
enum Level : int {
  NORMAL = 1,
  MOD = 50,
  ADMIN = 100,
}

/**
  A delegate type which can be used in UDAs to adjust a CommandObject's settings
  or behavior.
*/
alias CommandObjectUpdate = void delegate(CommandObject);

/// Sets a guild permission requirement.
CommandObjectUpdate CommandGuildPermission(Permission p) {
  return (c) {
    c.pre ~= (ce) {
      return (ce.msg.guild && ce.msg.guild.can(ce.msg.author, p));
    };
  };
}

/// Sets a channel permission requirement.
CommandObjectUpdate CommandChannelPermission(Permission p) {
  return (c) {
    c.pre ~= (ce) {
      return (ce.msg.channel.can(ce.msg.author, p));
    };
  };
}

/// A delegate type which represents a function used for handling commands.
alias CommandHandler = void delegate(CommandEvent);

/// A delegate type which represents a function used for filtering commands.
alias CommandHandlerWrapper = bool delegate(CommandEvent);

/**
  A CommandObject represents the configuration/state for  a single command.
*/
class CommandObject {
  /// The description / help text for the command
  string  description;

  /// The permissions level required for the command
  int     level;

  /// Whether this command is enabled
  bool  enabled = true;

  /// Function to run before main command handler.
  CommandHandlerWrapper[] pre;

  /// The function handler for this command
  CommandHandler  func;

  private {
    /// Triggers for this command
    string[]  triggers;

    // Compiled matching regex
    Regex!char  rgx;

    string      group;
    bool        useRegex;
  }

  //Takes an aliasSeq of arguments from getUDAs, which automatically expands for as many UDAs as are given
  this(T...)(CommandHandler func, T t) {
    this.func = func;   //Assign the event handler.
    
    foreach(arg; t){
      //This will be our run-time variable
      auto argType = split(typeid(arg).toString, '"')[1];

      //Use the string passed by the enum (e.g. TypeTriggers) to assign parameters at run-time
      mixin("this." ~ split(typeof(arg).stringof, '"')[1] ~ " = " ~ "(arg.tupleof)[0];");
    }

    this.rebuild();
  }

  /// Sets this command's triggers
  void setTriggers(string[] triggers) {
    this.triggers = triggers;
    this.rebuild();
  }

  /// Adds a trigger for this command
  void addTrigger(string trigger) {
    this.triggers ~= trigger;
    this.rebuild();
  }

  /// Sets this command's group
  void setGroup(string group) {
    this.group = group;
    this.rebuild();
  }

  /// Sets whether this command uses regex matching
  void setRegex(bool rgx) {
    this.useRegex = rgx;
    this.rebuild();
  }

  /// Rebuilds the locally cached regex
  private void rebuild() {
    if (this.useRegex) {
      this.rgx = regex(this.triggers.join("|"));
    } else {
      // Append space to grouping
      group = (this.group != "" ? this.group ~ " " : "");
      this.rgx = regex(this.triggers.map!((x) => "^" ~ group ~ x).join("|") ~ "( (.*)$|$)", "s");
    }
  }

  /// Returns a Regex capture group matched against the command's regex.
  Captures!string match(string msg) {
    return msg.matchFirst(this.rgx);
  }

  /// Returns the command name (always the first trigger in the list).
  @property string name() {
    return this.triggers[0];
  }

  void call(CommandEvent e) {
    foreach (prefunc; this.pre) {
      if (!prefunc(e)) return;
    }

    this.func(e);
  }
}

/**
  Special event encapsulating MessageCreates, containing specific Bot utilties
  and functionality.
*/
class CommandEvent {
  CommandObject  cmd;
  MessageCreate  event;
  Message        msg;

  /** The message contents */
  string    contents;

  /** Array of arguments */
  string[]  args;

  this(MessageCreate event) {
    this.event = event;
    this.msg = event.message;
  }

  /// Returns arguments as a single string
  @property string cleanedContents() {
    return this.args.join(" ");
  }

  deprecated("use CommandEvent.args.length check")
  bool has(ushort index) {
    return (index < this.args.length);
  }

  deprecated("use CommandEvent.args[]")
  string arg(ushort index) {
    return this.args[index];
  }

  /// Returns mentions for this command, sans the bot
  @property UserMap mentions() {
    return this.msg.mentions.filter((k, v) => k != this.event.client.me.id);
  }
}

/**
  The Commandable template is a virtual implementation which handles the command
  UDAs, storing them within a local "commands" mapping.
*/
mixin template Commandable() {
  CommandObject[string]  commands;

  void loadCommands(T)() {
    import std.traits;

    //Find the function associated with each Command
    foreach (symbol; getSymbolsByUDA!(T, CommandConfig)) {
      static if (isFunction!symbol) {
        //Perform some sanity checks
        static assert(getUDAs!(symbol, Command).length == 1, "Each function must have one @Command UDA.");
        static assert(getUDAs!(symbol, Description).length <= 1, "Each function may have only one @Description UDA.");
        static assert(getUDAs!(symbol, RegEx).length <= 1, "Each function may have only one @RegEx UDA.");
        static assert(getUDAs!(symbol, Group).length <= 1, "Each function may have only one @Group UDA.");
        static assert(getUDAs!(symbol, CommandLevel).length <= 1, "Each function may have only one @CommandLevel UDA.");

        //Get the UDAs themselves for each Command
        foreach(uda; getUDAs!(symbol, Command)){
          //Display the commands and associated methods at build time
          pragma(msg, uda.stringof, "\t", __traits(identifier, symbol));

          //Cast the symbol to the child plugin type inheriting from Plugin
          auto _symbol = mixin("&(cast(T)this)." ~ __traits(identifier, symbol));

          //Register the function for its command triggers
          this.registerCommand(new CommandObject(_symbol, getUDAs!(symbol, CommandConfig)));
        }
      }
    }
  }

  /**
    Registers a command from a CommandObject
  */
  CommandObject registerCommand(CommandObject obj) {
    this.commands[obj.name] = obj;
    return obj;
  }
}
