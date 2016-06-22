module dscord.util.errors;

import std.format;

public mixin template ExceptionMixin() {
  this(string msg = null, Throwable next = null) { super(msg, next); }
  this(string msg, string file, size_t line, Throwable next = null) {
    super(msg, file, line, next);
  }
}

class BaseError : Exception {
  this(T...)(string msg, T args) {
    super(format(msg, args));
  }
}
