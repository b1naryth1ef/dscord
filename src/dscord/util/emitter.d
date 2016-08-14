/**
  Utility for emitting/subscribing to events.
*/
module dscord.util.emitter;

import vibe.core.concurrency,
       vibe.core.core;

import std.stdio,
       std.algorithm,
       std.array,
       std.variant,
       std.datetime,
       core.time;

import dscord.util.errors;

/**
  Special exception used to stop the emission of an event.
*/
class EmitterStop : Exception { mixin ExceptionMixin; }

/**
  Interface implementing a single call method for emitting an event.
*/
interface BoundEmitter {
  void call(string, Variant);
}

/**
  Base event listener implementation.
*/
class BaseEventListener : BoundEmitter {
  string     name;
  Emitter    e;

  /**
    Unbinds this listener forever.
  */
  void unbind() {
    this.e.listeners[this.name] = this.e.listeners[this.name].filter!(
      (li) => li != this).array;
  }

  void call(string name, Variant arg) {

  }
}

/**
  Listener for a specific event.
*/
class EventListener : BaseEventListener {
  void delegate(Variant arg)  func;

  this(Emitter e, string name, void delegate(Variant) f) {
    this.e = e;
    this.name = name;
    this.func = f;
  }

  override void call(string name, Variant arg) {
    this.func(arg);
  }
}

/**
  Array of EventListeners
*/
alias EventListenerArray = EventListener[];

/**
  Listener for all events.
*/
class AllEventListener : BaseEventListener {
  void delegate(string, Variant)  func;

  this(Emitter e, void delegate(string, Variant) f) {
    this.e = e;
    this.func = f;
  }

  override void call(string name, Variant arg) {
    this.func(name, arg);
  }
}

/**
  Event emitter which allows the emission and subscription of events.
*/
class Emitter {
  BoundEmitter[][string]  listeners;

  /**
    Listen to an event by string, ignoring the actual event in the callback.
  */
  EventListener on(string event, void delegate() f) {
    auto li = new EventListener(this, event, (arg) {
      try { f(); } catch (EmitterStop) { return; }
    });

    this.listeners[event] ~= li;
    return li;
  }

  /**
    Listen to an event based on its type.
  */
  EventListener listen(T)(void delegate(T) f) {
    auto li = new EventListener(this, T.stringof, (arg) {
      try { f(arg.get!T); } catch (EmitterStop) { return; }
    });

    this.listeners[T.stringof] ~= li;
    return li;
  }

  /**
    Listen to an event based on its name.
  */
  EventListener listenRaw(string event, void delegate(Variant) f) {
    auto li = new EventListener(this, event, f);
    this.listeners[event] ~= li;
    return li;
  }

  /**
    Listen to all events.
  */
  AllEventListener listenAll(void delegate(string, Variant) f) {
    auto li = new AllEventListener(this, f);
    this.listeners[""] ~= li;
    return li;
  }

  /**
    Emit an event.
  */
  void emit(T)(T obj) {
    this.emitByName!T(T.stringof, obj, false);
    this.emitByName!T(T.stringof, obj, true);
  }

  private void emitByName(T)(string name, T obj, bool all) {
    if (!((all ? "" : name) in this.listeners)) {
      return;
    }

    auto v = Variant(obj);

    foreach (func; this.listeners[all ? "" : name]) {
      runTask({
        try {
          func.call(name, v);
        } catch (Exception e) {
          writeln(e.toString);
        }
      });
    }
  }
}
