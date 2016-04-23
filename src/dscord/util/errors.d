module dscord.util.errors;

import std.format;

class BaseError : Exception {
  this(T...)(string msg, T args) {
    super(format(msg, args));
  }
}
