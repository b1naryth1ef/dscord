module dscord.util.dynlib;

import std.string;

import dscord.util.errors;

import core.stdc.stdio;
import core.stdc.stdlib;
import core.sys.posix.dlfcn;

alias dynamicLibrary = void*;

dynamicLibrary loadDynamicLibrary(string path) {
  void* lh = dlopen(toStringz(path), RTLD_NOW);
  if (!lh) {
    throw new BaseError("Failed to loadDynamicLibrary (%s): %s", path, fromStringz(dlerror()));
  }

  return lh;
}

T loadFromDynamicLibrary(T)(dynamicLibrary lh, string name) {
  T result = cast(T)dlsym(lh, toStringz(name));
  char* error = dlerror();

  if (error) {
    throw new BaseError("Failed to loadFromDynamicLibrary: %s", name);
  }

  return result;
}

void unloadDynamicLibrary(dynamicLibrary lh) {
  dlclose(lh);
}
