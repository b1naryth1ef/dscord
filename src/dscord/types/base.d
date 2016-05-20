module dscord.types.base;

import std.conv,
       std.typecons,
       std.stdio,
       std.algorithm;

import dscord.client,
       dscord.util.json;

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

class Model {
  Client client;

  this(Client client, JSONObject obj) {
    this.client = client;
    this.client.log.tracef("creating model %s with data %s", this.toString, obj.dumps());
    this.load(obj);
  }

  void load(JSONObject obj) {}
}

interface Identifiable {
  Snowflake getID();
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

  auto keys() {
    return this.data.keys;
  }

  auto values() {
    return this.data.values;
  }
}


// This pattern fucking sucks, I have no clue what I wanted :(
class IdentifiedModelMap(TValue) : ModelMap!(Snowflake, TValue) {
  override bool has(Snowflake key) {
    return (key in this.data) != null;
  }

  bool has(Identifiable i) {
    return this.has(i.getID());
  }
}
