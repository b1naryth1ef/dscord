module dscord.bot.command;

import std.stdio;

import dscord.gateway.events;

CommandObj Command(string trigger, string desc = "", uint level = 0) {
  return CommandObj(trigger, desc, level);
}

CommandObj Command(string trigger, uint level) {
  return CommandObj(trigger, "", level);
}

struct CommandObj {
  string  trigger;
  string  description = "";
  uint    level = 0;

  void delegate(MessageCreate) f;
}

class CommandHandler {
  CommandObj[string]  commands;

  void loadCommands(T)() {
    foreach (mem; __traits(allMembers, T)) {
      foreach(attr; __traits(getAttributes, __traits(getMember, T, mem))) {
        static if (is(typeof(attr) == CommandObj)) {
          this.registerCommand(attr, mixin("&(cast(T)this)." ~ mem));
        }
      }
    }
  }

  void registerCommand(CommandObj cobj, void delegate(MessageCreate) f) {
    cobj.f = f;
    writefln("REG: %s", cobj.trigger);
    this.registerCommand(cobj);
  }

  void registerCommand(CommandObj cobj) {
    assert(cobj.f);
    this.commands[cobj.trigger] = cobj;
  }

  void inheritCommands(CommandHandler h) {
    foreach (v; h.commands.values) {
      this.registerCommand(v);
    }
  }
}
