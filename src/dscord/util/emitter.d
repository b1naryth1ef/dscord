module dscord.util.emitter;

import std.variant;

class Emitter {
  void delegate(Variant arg)[][string]  listeners;

  void on(string event, void delegate() f) {
    this.listeners[event] ~= (arg) {
      f();
    };
  }

  void listen(T)(void delegate(T) f) {
    this.listeners[T.stringof] ~= (arg) {
      f(arg.get!T);
    };
  }

  void emit(T)(T obj) {
    if (!(T.stringof in this.listeners)) {
      return;
    }

    auto v = Variant(obj);
    foreach (f; this.listeners[T.stringof]) {
      f(v);
    }
  }
}

