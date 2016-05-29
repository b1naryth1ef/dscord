module dscord.util.emitter;

import vibe.core.concurrency,
       vibe.core.core;

import std.stdio,
       std.algorithm,
       std.array,
       std.variant,
       core.time;

interface BoundEmitter {
  void call(string, Variant);
}

class BaseEventListener : BoundEmitter {
  string     name;
  Emitter    e;

  void unbind() {
    this.e.listeners[this.name] = this.e.listeners[this.name].filter!(
      (li) => li != this).array;
  }

  void call(string name, Variant arg) {

  }
}

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

class Emitter {
  BoundEmitter[][string]  listeners;

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

  EventListener listenRaw(string event, void delegate(Variant) f) {
    auto li = new EventListener(this, event, f);
    this.listeners[event] ~= li;
    return li;
  }

  AllEventListener listenAll(void delegate(string, Variant) f) {
    auto li = new AllEventListener(this, f);
    this.listeners[""] ~= li;
    return li;
  }

  void emit(T)(T obj) {
    runTask(&this.emitByName!T, T.stringof, obj, false);
    runTask(&this.emitByName!T, T.stringof, obj, true);
  }

  void emitByName(T)(string name, T obj, bool all) {
    if (!((all ? "" : name) in this.listeners)) {
      return;
    }

    auto v = Variant(obj);

    foreach (func; this.listeners[all ? "" : name]) {
      func.call(name, v);
    }
  }
}
