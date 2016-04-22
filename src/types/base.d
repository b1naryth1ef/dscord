module types.base;

import std.conv,
       std.typecons;

public import util.json;

import client;


alias Snowflake = ulong;

string toString(Snowflake s) {
  return to!string(s);
}

struct Permission {
  uint _value;
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

  this(JSONObject obj) {
    this.load(obj);
  }

  void load(JSONObject obj) {}
}

class ModelMap(Ti, Tm) {
  alias _getter = Tm delegate(Ti);

  _getter  getter;
  Tm[Ti]   storage;

  this() {}

  this(_getter getter) {
    this.getter = getter;
  }

  Tm get(Ti id) {
    if (!(id in this.storage)) {
      return this.refresh(id);
    }

    return this.storage[id];
  }

  Tm refresh(Ti id) {
    this.storage[id] = this.getter(id);
    return this.storage[id];
  }

  void del(Ti id) {
    this.storage.remove(id);
  }

  Tm opIndex(Ti key) {
    return this.get(key);
  }

  void opIndexAssign(Tm value, Ti key) {
    this.storage[key] = value;
  }
}
