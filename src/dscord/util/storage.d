module dscord.util.storage;

import std.stdio;


import std.file : dirSeparator, read, write, exists;
import std.json : JSON_TYPE, JSONValue, parseJSON;

class JSONObjectProxy {
  JSONValue obj;
  JSONObjectProxy[string]  proxies;

  this(JSONValue obj) {
    this.obj = obj;
  }

  this() {
    this.obj = JSONValue();
    this.obj.type = JSON_TYPE.OBJECT;
  }

  void remove(string key) {
    // TODO: handle subproxies
    destroy(this.obj[key]);
  }

  JSONValue opIndex(string key) {
    return this.obj[key];
  }

  void opIndexAssign(JSONValue value, string key) {
    this.obj[key] = value;
  }

  JSONObjectProxy getProxy(string key) {
    if (key in this.proxies) {
      return this.proxies[key];
    }

    if (!(key in this.obj)) {
      this.obj[key] = JSONValue();
      this.obj[key].type = JSON_TYPE.OBJECT;
    }

    return new JSONObjectProxy(this.obj[key]);
  }

  int opApply(int delegate(string, ref JSONValue) dg) {
    int res;

    foreach (string k, ref JSONValue v; this.obj) {
      res = dg(k, v);
      if (res < 0) return res;
    }

    return 0;
  }

  bool has(string key) {
    return !((key in this.obj) is null);
  }
}

class Storage : JSONObjectProxy {
  string     path;

  this(string path) {
    this.path = path;
  }

  void load() {
    if (exists(this.path)) {
      string data = cast(string)read(this.path);
      this.obj = parseJSON(data);
    } else {
      this.obj = JSONValue();
      this.obj.type = JSON_TYPE.OBJECT;
    }
  }

  void save() {
    write(this.path, this.obj.toString());
  }

  /* void ensureObject(string key) { */
  /*   if (!(key in this.obj)) { */
  /*     this.obj[key] = JSONValue(); */
  /*     this.obj[key].type = JSON_TYPE.OBJECT; */
  /*   } */
  /* } */
  /*  */
  /* JSONValue opIndex(string key) { */
  /*   return this.obj[key]; */
  /* } */
  /*  */
  /* bool has(string key) { */
  /*   return !((key in this.obj) is null); */
  /* } */
}
