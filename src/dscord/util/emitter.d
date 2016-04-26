module dscord.util.emitter;

import std.stdio;
import std.variant;

class Emitter {
  void delegate(string name, Variant arg)[]  all;
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
    auto v = Variant(obj);
    foreach (f; this.all) {
      f(T.stringof, v);
    }

    if (!(T.stringof in this.listeners)) {
      return;
    }

    foreach (f; this.listeners[T.stringof]) {
      f(v);
    }
  }

  void listenAll(void delegate(string name, Variant arg) f) {
    this.all ~= f;
  }
}

