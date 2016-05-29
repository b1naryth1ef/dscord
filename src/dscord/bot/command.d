module dscord.bot.command;

import dscord.gateway.events,
       dscord.types.all;

CommandObj* Command(string trigger, string desc = "", uint level = 0) {
  return new CommandObj(trigger, desc, level);
}

CommandObj* Command(string trigger, uint level) {
  return new CommandObj(trigger, "", level);
}

struct CommandObj {
  string  trigger;
  string  description = "";
  uint    level = 0;

  void delegate(CommandEvent) f;
}

class CommandEvent {
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

class CommandHandler {
  CommandObj*[string]  commands;

  void loadCommands(T)(string[] prefixes) {
    foreach (mem; __traits(allMembers, T)) {
      foreach(attr; __traits(getAttributes, __traits(getMember, T, mem))) {
        static if (is(typeof(attr) == CommandObj*)) {
          this.registerCommand(attr, mixin("&(cast(T)this)." ~ mem), prefixes);
        }
      }
    }
  }

  void registerCommand(CommandObj* cobj, void delegate(CommandEvent) f, string[] prefixes) {
    cobj.f = f;
    this.registerCommand(cobj, prefixes);
  }

  void registerCommand(CommandObj* cobj, string[] prefixes) {
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
