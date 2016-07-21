module dscord.types.base;

import std.conv,
       std.typecons,
       std.stdio,
       std.algorithm,
       std.traits,
       std.functional;

import dscord.client;

import vibe.core.core : runTask, sleep;
import vibe.core.sync;

// Commonly used public imports
public import dscord.util.json;
public import std.datetime;

// TODO: Eventually this should be a type
alias Snowflake = ulong;

string toString(Snowflake s) {
  return to!string(s);
}

/*
  AsyncChainer is a utility for exposing methods that can help
  chain actions with various delays/resolving patterns.
*/
class AsyncChainer(T) {
  private {
    T obj;
    AsyncChainer!T parent;
    ManualEvent resolveEvent;
  }

  // Base constructor just needs to know whether this requires
  //  resolving, or is a pure (no-wait) member of the chain.
  this(T obj, bool hasResolver = false) {
    this.obj = obj;

    if (hasResolver) {
      this.resolveEvent = createManualEvent();
    }
  }

  // Delayed constructor will wait for delay period of time
  //  before resolving the next member in the chain.
  this(T obj, Duration delay, AsyncChainer!T parent = null) {
    this(obj, true);

    this.parent = parent;

    runTask({
      if (this.parent) {
        this.parent.resolveEvent.wait();
      }

      sleep(delay);
      this.resolveEvent.emit();
    });
  }

  AsyncChainer!T after(Duration delay) {
    return new AsyncChainer!T(this.obj, delay, this);
  }

  // opDispatch override provides the mechanisim for delaying the chain
  //  asynchornously.
  AsyncChainer!T opDispatch(string func, Args...)(Args args) {
    if (this.resolveEvent) {
      auto next = new AsyncChainer!T(this.obj, true);

      runTask({
        this.resolveEvent.wait();
        this.obj.call!(func)(args);
        next.resolveEvent.emit();
      });

      return next;
    } else {
      this.obj.call!(func)(args);
      return this;
    }
  }
}

class IModel {
  Client  client;

  void init() {};
  void load(ref JSON obj) {};

  this(Client client, ref JSON obj) {
    debug {
      client.log.tracef("Starting creation of model %s", this.toString);
      auto sw = StopWatch(AutoStart.yes);
    }

    this.client = client;
    this.init();
    this.load(obj);

    debug {
      this.client.log.tracef("Finished creation of model %s in %sms", this.toString,
        sw.peek().to!("msecs", real));
    }
  }
}

mixin template Model() {
  this(Client client, ref JSON obj) {
    super(client, obj);
  }

  auto after(Duration delay) {
    return new AsyncChainer!(typeof(this))(this, delay);
  }

  auto chain() {
    return new AsyncChainer!(typeof(this))(this);
  }

  void call(string blah, T...)(T args) {
    __traits(getMember, this, blah)(args);
  }
}

Snowflake readSnowflake(ref JSON obj) {
  string data = obj.read!string;
  if (!data) return 0;
  return data.to!Snowflake;
}

T[] loadManyArray(T)(Client client, ref JSON obj) {
  T[] data;

  foreach (item; obj) {
    data ~= new T(client, obj);
  }

  return data;
}

void loadMany(T)(Client client, ref JSON obj, void delegate(T) F) {
  foreach (item; obj) {
    F(new T(client, obj));
  }
}

void loadManyComplex(TSub, T)(TSub sub, ref JSON obj, void delegate(T) F) {
  foreach (item; obj) {
    F(new T(sub, obj));
  }
}

class ModelMap(TKey, TValue) {
  TValue[TKey]  data;

  TValue set(TKey key, TValue value) {
    if (value is null) {
      this.remove(key);
      return null;
    }

    this.data[key] = value;
    return value;
  }

  TValue get(TKey key) {
    return this.data[key];
  }

  TValue get(TKey key, TValue def) {
    if (this.has(key)) {
      return this.get(key);
    }
    return def;
  }

  TValue opCall(TKey key) {
    return this.data[key];
  }

  void remove(TKey key) {
    this.data.remove(key);
  }

  bool has(TKey key) {
    return (key in this.data) != null;
  }

  TValue opIndex(TKey key) {
    return this.get(key);
  }

  void opIndexAssign(TValue value, TKey key) {
    this.set(key, value);
  }

  size_t length() {
    return this.data.length;
  }

  auto filter(bool delegate(TValue) f) {
    return this.data.values.filter!(f);
  }

  auto each(void delegate(TValue) f) {
    return this.data.values.each!(f);
  }

  auto each(TValue delegate(TValue) f) {
    return this.data.values.each!(f);
  }

  TValue pick(bool delegate(TValue) f) {
    foreach (value; this.data.values) {
      if (f(value)) {
        return value;
      }
    }
    return null;
  }

  auto keys() {
    return this.data.keys;
  }

  auto values() {
    return this.data.values;
  }
}
