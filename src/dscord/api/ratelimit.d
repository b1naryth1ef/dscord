module dscord.api.ratelimit;

import core.time,
       core.sync.condition,
       core.sync.mutex;

import vibe.core.core;

/*
TODO: Rewrite this.
TODO: this does not work (rofl)

Ideally the RateLimiter can be quite a bit more smart than it currently is, namely:
  1. RateLimiter should flush requests slowly, vs spamming all the requests after
    the cooldown.
  2. RateLimiter should take into account how many requests are being queued and
    cancel/error requests past a certain sane limit to avoid large queues and warn
    users of bad behavior.
*/

class RateLimiter {
  Condition[string]  cooldowns;

  bool wait(string url, Duration timeout) {
    if (!(url in this.cooldowns)) return true;
    return this.cooldowns[url].wait(timeout);
  }

  void cooldown(string url, Duration cooldown) {
    this.cooldowns[url] = new Condition(new Mutex);
    sleep(cooldown);
    this.cooldowns[url].notifyAll();
    this.cooldowns.remove(url);
  }
}

