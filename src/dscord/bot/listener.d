module dscord.bot.listener;

import std.variant,
       std.string,
       std.array;

import dscord.gateway.events,
       dscord.types.all,
       dscord.util.emitter;

ListenerDef!T Listener(T)() {
  return ListenerDef!(T)(T.stringof, (event, func) {
    func(event.get!(T));
  });
}

struct ListenerDef(T) {
  string clsName;
  void delegate(Variant, void delegate(T)) func;
}

class ListenerObject {
  string  clsName;

  // Bound event listener
  EventListener  listener;

  // Variant caller
  void delegate(Variant v) func;

  this(string clsName, void delegate(Variant v) func) {
    this.clsName = clsName;
    this.func = func;
  }
}

mixin template Listenable() {
  ListenerObject[]  listeners;

  void loadListeners(T)() {
    foreach (mem; __traits(allMembers, T)) {
      foreach(attr; __traits(getAttributes, __traits(getMember, T, mem))) {
        static if (__traits(hasMember, attr, "clsName")) {
          this.registerListener(new ListenerObject(attr.clsName, (v) {
            attr.func(v, mixin("&(cast(T)this)." ~ mem));
          }));
        }
      }
    }
  }

  void registerListener(ListenerObject obj) {
    this.listeners ~= obj;
  }
}
