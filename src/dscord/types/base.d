module dscord.types.base;

import std.conv,
       std.typecons,
       std.stdio,
       std.algorithm,
       std.traits,
       std.functional;

import dscord.client;

import vibe.core.core : runTask, sleep;

public import dscord.util.json;
public import std.datetime;

alias Snowflake = ulong;

string toString(Snowflake s) {
  return to!string(s);
}

class Cache(T) {
  T data;

  T get() {
    return data;
  }

  T all(T delegate() f) {
    if (!this.data) {
      this.data = f();
    }
    return this.data;
  }

  T refresh(T delegate() f) {
    this.data = f();
    return this.data;
  }
}

/*
  ModelDispatcher is a proxy for chaining model actions
    TODO: this needs to have a chained resolver in it so we can actually
    y'know.. chain it?
*/
class ModelDispatcher(T) {
  T obj;
  Duration delay;

  this(T obj, Duration delay) {
    this.obj = obj;
    this.delay = delay;
  }

  auto opDispatch(string func, Args...)(Args args) {
    runTask({
      sleep(delay);
      this.obj.call!(func)(args);
    });
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
    return new ModelDispatcher!(typeof(this))(this, delay);
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
