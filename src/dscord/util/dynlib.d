module dscord.util.dynlib;

import std.string;

import dscord.util.errors;

alias DynamicLibrary = void*;

version (linux) {

import core.stdc.stdio;
import core.stdc.stdlib;
import core.sys.posix.dlfcn;

DynamicLibrary loadDynamicLibrary(string path) {
  void* lh = dlopen(toStringz(path), RTLD_NOW);
  if (!lh) {
    throw new BaseError("Failed to loadDynamicLibrary (%s): %s", path, fromStringz(dlerror()));
  }

  return lh;
}

T loadFromDynamicLibrary(T)(DynamicLibrary lh, string name) {
  T result = cast(T)dlsym(lh, toStringz(name));
  char* error = dlerror();

  if (error) {
    throw new BaseError("Failed to loadFromDynamicLibrary: %s", name);
  }

  return result;
}

void unloadDynamicLibrary(DynamicLibrary lh) {
  dlclose(lh);
}

} else {
  DynamicLibrary loadDynamicLibrary(string path) {
    throw new BaseError("Dynamic plugins are only supported on linux");
  }

  T loadFromDynamicLibrary(T)(DynamicLibrary lh, string name) {
    throw new BaseError("Dynamic plugins are only supported on linux");
  }

  void unloadDynamicLibrary(DynamicLibrary lh) {
    throw new BaseError("Dynamic plugins are only supported on linux");
  }
}
