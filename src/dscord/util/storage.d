/**
  A simple JSON storage wrapper.
*/
module dscord.util.storage;

import std.file : read, write, exists;
import std.path : dirSeparator;
import dscord.util.json;

class Storage {
  VibeJSON  obj;
  string    path;

  this(string path) {
    this.path = path;
  }

  void load() {
    if (exists(this.path)) {
      this.obj = parseJsonString(cast(string)read(this.path));
    } else {
      this.obj = VibeJSON.emptyObject;
    }
  }

  void save() {
    write(this.path, this.obj.toPrettyString());
  }

  VibeJSON ensureObject(string key) {
    if (!this.has(key)) {
      this.obj[key] = VibeJSON.emptyObject;
    }

    return this.obj[key];
  }

  void set(string key, VibeJSON o) {
    this.obj[key] = o;
  }

  VibeJSON opIndex(string key) {
    return this.obj[key];
  }

  bool has(string key) {
    return !((key in this.obj) is null);
  }

  T get(T)(string key) {
    return this.obj[key].get!T;
  }

  T get(T)(string key, T def) {
    if (this.has(key)) {
      return this.get!T(key);
    }
    return def;
  }
}
