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

alias CommandObjectUpdate = void delegate(CommandObject);

CommandObjectUpdate CommandDescription(string desc) {
  return (c) {c.description = desc; };
}

CommandObjectUpdate CommandGroup(string group) {
  return (c) {c.group = group;};
}

CommandObjectUpdate CommandRegex(bool rgx) {
  return (c) {c.setRegex(rgx);};
}

CommandObjectUpdate CommandLevel(uint level) {
  return (c) {c.level = level;};
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
  private {
    Regex!char  rgx;
  }

  this(Command cmd, CommandHandler func) {
    this.func = func;
    this.trigger = cmd.trigger;
    this.description = cmd.description;
    this.group = (cmd.group != "" ? cmd.group ~ " " : "");
    this.level = cmd.level;
    this.setRegex(cmd.regex);
  }

  void setRegex(bool rgx) {
    if (rgx) {
      this.rgx = regex(this.trigger);
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
  CommandObject  cmd;
  MessageCreate  event;
  Message        msg;

  // Contents
  string    contents;
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

/*
  The CommandHandler class is a base-class virtual implementation of UDA-constructed command handlers.
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

  CommandObject registerCommand(CommandObject obj) {
    this.commands[obj.trigger] = obj;
    return obj;
  }
}
