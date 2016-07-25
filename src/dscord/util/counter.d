module dscord.util.counter;

import std.algorithm;

class Counter(T) {
  uint     total;
  uint[T]  storage;

  uint get(T v) {
    return this.storage[v];
  }

  void tick(T v) {
    this.total += 1;
    this.storage[v] += 1;
  }

  void reset(T v) {
    this.total -= this.storage[v];
    this.storage[v] = 0;
  }

  void resetAll() {
    foreach (ref k; this.storage.keys) {
      this.reset(k);
    }
    this.total = 0;
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
