module dscord.util.emitter;

import vibe.core.concurrency,
       vibe.core.core;

import std.stdio,
       std.algorithm,
       std.array,
       std.variant,
       core.time;

class Listener {
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
  Listener[][string]  listeners;
  // Listener[]          all;

  Listener on(string event, void delegate() f) {
    auto li = new Listener(this, event, (arg) {
      f();
    });

    this.listeners[event] ~= li;
    return li;
  }

  Listener listen(T)(void delegate(T) f) {
    auto li = new Listener(this, T.stringof, (arg) {
      f(arg.get!T);
    });

    this.listeners[T.stringof] ~= li;
    return li;
  }

  void emitTask(T)(T obj) {
    runTask(this.emit, obj);
  }

  void emit(T)(T obj) {
    auto v = Variant(obj);

    if (!(T.stringof in this.listeners)) {
      return;
    }

    foreach (f; this.listeners[T.stringof]) {
      f(v);
    }
  }
}
