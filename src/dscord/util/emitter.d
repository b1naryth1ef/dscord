module dscord.util.emitter;

import vibe.core.concurrency,
       vibe.core.core;

import std.stdio,
       std.algorithm,
       std.array,
       std.variant,
       core.time;

class EventListener {
  string     name;
  Emitter    e;

  // Function
  void delegate(Variant arg)  f;

  this(Emitter e, string name, void delegate(Variant arg) f) {
    this.name = name;
    this.e = e;
    this.f = f;
  }

  void unbind() {
    this.e.listeners[this.name] = this.e.listeners[this.name].filter!(
      (li) => li != this).array;
  }

  void opCall(Variant arg) {
    this.f(arg);
  }
}

// TODO: move cast to Listener
// TODO: add all listener

class Emitter {
  EventListener[][string]  listeners;
  // Listener[]          all;

  EventListener on(string event, void delegate() f) {
    auto li = new EventListener(this, event, (arg) {
      f();
    });

    this.listeners[event] ~= li;
    return li;
  }

  EventListener listen(T)(void delegate(T) f) {
    auto li = new EventListener(this, T.stringof, (arg) {
      f(arg.get!T);
    });

    this.listeners[T.stringof] ~= li;
    return li;
  }

  void emit(T)(T obj) {
    runTask(&this._emit!T, obj);
  }

  void _emit(T)(T obj) {
    auto v = Variant(obj);

    if (!(T.stringof in this.listeners)) {
      return;
    }

    foreach (f; this.listeners[T.stringof]) {
      f(v);
    }
  }
}
