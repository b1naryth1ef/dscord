/**
  Utilties for building user-controlled commands with the dscord bot interface
*/

module dscord.bot.command;

import std.regex,
       std.array,
       std.functional,
       std.algorithm;

import dscord.types,
       dscord.gateway;

static struct CommandDefinition {
  string[]  triggers;
}

/// A UDA that can be used to flag a function as a command handler.
CommandDefinition Command(string[] args...) {
  return CommandDefinition(args.dup);
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
  A delegate type which can be used in UDA's to adjust a CommandObjects settings
  or behavior.
*/
alias CommandObjectUpdate = void delegate(CommandObject);

/**
  Sets a commands description.
*/
CommandObjectUpdate CommandDescription(string desc) {
  return (c) {c.description = desc; };
}

/**
  Sets a commands group.
*/
CommandObjectUpdate CommandGroup(string group) {
  return (c) {c.setGroup(group);};
}

/**
  Sets whether a command uses regex matching
*/
CommandObjectUpdate CommandRegex(bool rgx) {
  return (c) {c.setRegex(rgx);};
}

/**
  Sets a commands permission level.
*/
CommandObjectUpdate CommandLevel(int level) {
  return (c) {c.level = level;};
}

/**
  A delegate type which represents a function used for handling commands.
*/
alias CommandHandler = void delegate(CommandEvent);

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

  this(string[] triggers, CommandHandler func) {
    this.func = func;
    this.triggers = triggers;
    this.level = 0;
    this.setGroup("");
    this.setRegex(false);
  }

  /// Sets this commands triggers
  void setTriggers(string[] triggers) {
    this.triggers = triggers;
    this.rebuild();
  }

  /// Adds a trigger for this command
  void addTrigger(string trigger) {
    this.triggers ~= trigger;
    this.rebuild();
  }

  /// Sets this commands group
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
      this.rgx = regex(this.triggers.map!((x) => "^" ~ group ~ x).join("|"));
    }
  }

  /// Returns a Regex capture group matched against the commands regex.
  Captures!string match(string msg) {
    return msg.matchFirst(this.rgx);
  }

  /// Returns the command name (always the first trigger in the list).
  @property string name() {
    return this.triggers[0];
  }
}

/**
  Special event encapsulating MessageCreate's, containing specific Bot utilties
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

  @deprecated bool has(ushort index) {
    return (index < this.args.length);
  }

  @deprecated string arg(ushort index) {
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
    CommandObject obj;
    foreach (mem; __traits(allMembers, T)) {
      foreach(attr; __traits(getAttributes, __traits(getMember, T, mem))) {
        static if (is(typeof(attr) == CommandDefinition)) {
          obj = this.registerCommand(new CommandObject(attr.triggers, mixin("&(cast(T)this)." ~ mem)));
        }
        static if (is(typeof(attr) == CommandObjectUpdate)) {
          attr(obj);
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
