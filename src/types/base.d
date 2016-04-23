module types.base;

import std.conv,
       std.typecons;

public import util.json;

import client;


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
    this.load(obj);
  }

  void load(JSONObject obj) {}
}

class ModelMap(Ti, Tm) {
  alias _getter = Tm delegate(Ti);
  alias _setter = void delegate(Ti, Tm);

  _getter  getter;
  _setter  setter;
  Tm[Ti]   storage;

  this() {}

  this(_getter getter) {
    this.getter = getter;
  }

  this(_getter getter, _setter setter) {
    this.getter = getter;
    this.setter = setter;
  }

  void set(Ti key, Tm value) {
    if (value is null) {
      this.del(key);
      return;
    }

    this.storage[key] = value;
  }

  Tm get(Ti id) {
    if (!(id in this.storage)) {
      return this.refresh(id);
    }

    return this.storage[id];
  }

  Tm getOrSet(Ti key, Tm delegate() set) {
    if (key in this.storage) {
      return this.storage[key];
    }
    this.set(key, set());
    return this.storage[key];
  }

  Tm refresh(Ti id) {
    assert(this.getter, "Must have getter to refresh");
    this.storage[id] = this.getter(id);
    if (this.setter) this.setter(id, this.storage[id]);
    return this.storage[id];
  }

  void del(Ti id) {
    this.storage.remove(id);
    if (this.setter) this.setter(id, null);
  }

  Tm opIndex(Ti key) {
    return this.get(key);
  }

  void opIndexAssign(Tm value, Ti key) {
    this.storage[key] = value;
    if (this.setter) this.setter(key, value);
  }
}
