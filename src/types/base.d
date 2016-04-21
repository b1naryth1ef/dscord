module types.base;

import std.conv,
       std.typecons;

import api.client,
       util.json;

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

class APIObject {
  APIClient client;

  this(JSONObject obj) {
    this.load(obj);
  }

  void load(JSONObject obj) {}
}

