/**
  Utilties for building user-controlled commands with the dscord bot interface
*/

module dscord.bot.command;

import std.regex,
       std.algorithm;

import dscord.gateway.events,
       dscord.types.all;

/**
  A UDA that can be used to flag a function as a command handler.
*/
struct Command {
  string  trigger;
  string  description = "";
  string  group = "";
  bool    regex = false;
  uint    level = 0;
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
CommandObjectUpdate CommandLevel(uint level) {
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
  /** The command "trigger" or name */
  string  trigger;

  /** The description / help text for the command */
  string  description;

  /** The permissions level required for the command */
  uint    level;

  /** Whether this command is enabled */
  bool  enabled = true;

  /** The function handler for this command */
  CommandHandler  func;

  private {
    // Compiled matching regex
    Regex!char  rgx;

    string      group;
    bool        useRegex;
  }

  this(Command cmd, CommandHandler func) {
    this.func = func;
    this.trigger = cmd.trigger;
    this.description = cmd.description;
    this.level = cmd.level;
    this.setGroup(cmd.group);
    this.setRegex(cmd.regex);
  }

  /**
    Sets this commands group.
  */
  void setGroup(string group) {
    this.group = group;
    this.rebuild();
  }

  /**
    Sets whether this command uses regex matching.
  */
  void setRegex(bool rgx) {
    this.useRegex = rgx;
    this.rebuild();
  }

  /**
    Rebuilds the locally cached regex.
  */
  void rebuild() {
    if (this.useRegex) {
      this.rgx = regex(this.trigger);
    } else {
      // Append space to grouping
      group = (this.group != "" ? this.group ~ " " : "");
      this.rgx = regex("^" ~ group ~ this.trigger);
    }
  }

  /**
    Returns a Regex capture group matched against the commands regex.
  */
  Captures!string match(string msg) {
    return msg.matchFirst(this.rgx);
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

  bool has(ushort index) {
    return (index < this.args.length);
  }

  string arg(ushort index) {
    return this.args[index];
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
        static if (is(typeof(attr) == Command)) {
          obj = this.registerCommand(new CommandObject(attr, mixin("&(cast(T)this)." ~ mem)));
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
    this.commands[obj.trigger] = obj;
    return obj;
  }
}
