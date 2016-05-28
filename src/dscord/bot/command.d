module dscord.bot.command;

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

  void loadCommands(T)(string[] prefixes) {
    foreach (mem; __traits(allMembers, T)) {
      foreach(attr; __traits(getAttributes, __traits(getMember, T, mem))) {
        static if (is(typeof(attr) == CommandObj)) {
          this.registerCommand(attr, mixin("&(cast(T)this)." ~ mem), prefixes);
        }
      }
    }
  }

  void registerCommand(CommandObj cobj, void delegate(MessageCreate) f, string[] prefixes) {
    cobj.f = f;
    this.registerCommand(cobj, prefixes);
  }

  void registerCommand(CommandObj cobj, string[] prefixes) {
    assert(cobj.f);

    if (prefixes.length) {
      foreach (pref; prefixes) {
        this.commands[pref ~ " " ~ cobj.trigger] = cobj;
      }
    } else {
      this.commands[cobj.trigger] = cobj;
    }
  }

  void inheritCommands(CommandHandler h) {
    foreach (k, v; h.commands) {
      this.commands[k] = v;
    }
  }
}
