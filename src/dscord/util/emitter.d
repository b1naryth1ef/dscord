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
  Variant    value;

  // Function
  void delegate(Variant arg)  f;

  // Async
  TaskCondition  await;

  this(Emitter e, string name, void delegate(Variant arg) f, bool async=false) {
    this.name = name;
    this.e = e;
    if (async) {
      this.await = new TaskCondition(new TaskMutex);
    } else {
      this.f = f;
    }
  }

  Variant wait(Duration timeout = 1.seconds) {
    assert(!this.f, "wait is only available on async listeners");
    // synchronized (this.await.mutex) {
      if (!this.await.wait(timeout)) {
        this.value = new Variant(null);
      }
   // }
    return this.value;
  }

  void unbind() {
    this.e.listeners[this.name] = this.e.listeners[this.name].filter!(
      (li) => li != this).array;
  }

  void opCall(Variant arg) {
    if (this.f) {
      this.f(arg);
    } else {
      this.value = arg;
      this.unbind();
      this.await.notifyAll();
    }
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

  Listener listen(T)(void delegate(T) f, bool async=false) {
    auto li = new Listener(this, T.stringof, (arg) {
      writefln("calling %s", f);
      f(arg.get!T);
    }, async);

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

  T waitFor(T)(Duration timeout=1.seconds) {
    auto handler = this.listen!T(null, true);
    auto value = handler.wait(timeout);

    writefln("%s", value);
    if (value.convertsTo!T) {
      return value.coerce!T;
    } else {
      return null;
    }
  }
}

