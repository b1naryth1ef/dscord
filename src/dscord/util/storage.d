/**
  A simple JSON storage wrapper.
*/
module dscord.util.storage;

import std.file : dirSeparator, read, write, exists;
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

  VibeJSON opIndex(string key) {
    return this.obj[key];
  }

  bool has(string key) {
    return !((key in this.obj) is null);
  }
}
