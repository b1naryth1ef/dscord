module dscord.bot.command;

import std.regex,
       std.algorithm;

import dscord.gateway.events,
       dscord.types.all;

// Only used for the UDA constructor
struct Command {
  string  trigger;
  string  description = "";
  string  group = "";
  bool    regex = false;
  uint    level = 0;
}

// Command handler represents a function called when a command is triggered
alias CommandHandler = void delegate(CommandEvent);

// CommandObject is the in-memory representation of commands (built from the Command struct)
class CommandObject {
  string  trigger;
  string  description;
  string  group;
  uint    level;

  // Hidden stuff
  bool  enabled = true;

  CommandHandler  func;

  // Compiled regex match
  Regex!char  rgx;

  this(Command cmd, CommandHandler func) {
    this.func = func;
    this.trigger = cmd.trigger;
    this.description = cmd.description;
    this.group = (cmd.group != "" ? cmd.group ~ " " : "");
    this.level = cmd.level;

    if (cmd.regex) {
      this.rgx = regex(cmd.trigger);
    } else {
      this.rgx = regex("^" ~ this.group ~ this.trigger);
    }
  }

  Captures!string match(string msg) {
    return msg.matchFirst(this.rgx);
  }
}

// Command event is a special event encapsulating MessageCreate's that has util methods for bots
class CommandEvent {
  // MessageCreate  event;
  Message        msg;

  // Contents
  string    contents;
  string[]  args;

  /*
  this(MessageCreate event) {
    this.event = event;
    this.msg = event.message;
  }
  */

  bool has(ushort index) {
    return (index < this.args.length);
  }

  string arg(ushort index) {
    return this.args[index];
  }
}

/*
  The CommandHandler class is a base-class virtual implementation of UDA-constructed command handlers.
*/
mixin template Commandable() {
  CommandObject[string]  commands;

  void loadCommands(T)() {
    foreach (mem; __traits(allMembers, T)) {
      foreach(attr; __traits(getAttributes, __traits(getMember, T, mem))) {
        static if (is(typeof(attr) == Command)) {
          this.registerCommand(new CommandObject(attr, mixin("&(cast(T)this)." ~ mem)));
        }
      }
    }
  }

  void registerCommand(CommandObject obj) {
    this.commands[obj.trigger] = obj;
  }
}
