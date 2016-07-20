/**
  Utilties for handling/listening to events through the dscord bot interface.
*/

module dscord.bot.listener;

import std.variant,
       std.string,
       std.array;

import dscord.gateway.events,
       dscord.types.all,
       dscord.util.emitter;

/**
  UDA that can be used on a Plugin, informing it that the function will handle
  all events of type T.

  Params:
    T = Event type to listen for
*/
ListenerDef!T Listener(T)() {
  return ListenerDef!(T)(T.stringof, (event, func) {
    func(event.get!(T));
  });
}

/**
  Utility struct returned by the UDA.
*/
struct ListenerDef(T) {
  string clsName;
  void delegate(Variant, void delegate(T)) func;
}

/**
  A ListenerObject represents the configuration/state for a single listener.
*/
class ListenerObject {
  /** The class name of the event this listener is for */
  string  clsName;

  /** EventListener function for this Listener */
  EventListener  listener;

  /** Utility variant caller for converting event type */
  void delegate(Variant v) func;

  this(string clsName, void delegate(Variant v) func) {
    this.clsName = clsName;
    this.func = func;
  }
}

/**
  The Listenable template is a virtual implementation which handles the listener
  UDAs, storing them within a local "listeners" mapping.
*/
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

  /**
    Registers a listener from a ListenerObject
  */
  void registerListener(ListenerObject obj) {
    this.listeners ~= obj;
  }
}
