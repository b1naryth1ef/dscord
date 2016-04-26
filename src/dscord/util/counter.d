module dscord.util.counter;

import std.algorithm;

class Counter(T) {
  uint[T]  storage;

  void tick(T v) {
    this.storage[v] += 1;
  }

  auto mostCommon(uint limit) {
    auto res = schwartzSort!(k => this.storage[k], "a > b")(this.storage.keys);
    if (res.length > limit) {
      return res[0..limit];
    } else {
      return res;
    }
  }
}
