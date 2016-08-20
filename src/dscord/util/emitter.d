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

enum EmitterOrder {
  BEFORE = 1,
  UNSPECIFIED = 2,
  AFTER = 3,
}

immutable EmitterOrder[] EmitterOrderAll = [
  EmitterOrder.BEFORE,
  EmitterOrder.UNSPECIFIED,
  EmitterOrder.AFTER,
];

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
  EmitterOrder  order;
  Emitter  e;
  string  name;

  /**
    Unbinds this listener forever.
  */
  void unbind() {
    this.e.listeners[this.order][this.name] = this.e.listeners[this.order][this.name].filter!(
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

  this(Emitter e, string name, EmitterOrder order, void delegate(Variant) f) {
    this.e = e;
    this.name = name;
    this.order = order;
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

  this(Emitter e, EmitterOrder order, void delegate(string, Variant) f) {
    this.e = e;
    this.order = order;
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
  BoundEmitter[][string][EmitterOrder]  listeners;

  /**
    Listen to an event by string, ignoring the actual event in the callback.
  */
  EventListener on(string event, void delegate() f, EmitterOrder order=EmitterOrder.UNSPECIFIED) {
    auto li = new EventListener(this, event, order, (arg) {
      try { f(); } catch (EmitterStop) { return; }
    });

    this.listeners[order][event] ~= li;
    return li;
  }

  /**
    Listen to an event based on its type.
  */
  EventListener listen(T)(void delegate(T) f, EmitterOrder order=EmitterOrder.UNSPECIFIED) {
    auto li = new EventListener(this, T.stringof, order, (arg) {
      try { f(arg.get!T); } catch (EmitterStop) { return; }
    });

    this.listeners[order][T.stringof] ~= li;
    return li;
  }

  /**
    Listen to an event based on its name.
  */
  EventListener listenRaw(string event, void delegate(Variant) f, EmitterOrder order=EmitterOrder.UNSPECIFIED) {
    auto li = new EventListener(this, event, order, f);
    this.listeners[order][event] ~= li;
    return li;
  }

  /**
    Listen to all events.
  */
  AllEventListener listenAll(void delegate(string, Variant) f, EmitterOrder order=EmitterOrder.UNSPECIFIED) {
    auto li = new AllEventListener(this, order, f);
    this.listeners[order][""] ~= li;
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
    Variant v;

    if (all) name = "";

    foreach (order; EmitterOrderAll) {
      if (!(order in this.listeners)) continue;
      if (!(name in this.listeners[order])) continue;
      if (!v.hasValue()) v = Variant(obj);

      foreach (func; this.listeners[order][name]) {
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
}
