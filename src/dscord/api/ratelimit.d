/**
  Utilities for tracking and managing rate limits.
*/
module dscord.api.ratelimit;

import std.conv,
       std.math,
       std.random,
       core.time,
       core.sync.mutex;

import vibe.core.core;

import dscord.api.routes,
       dscord.util.time;

/// Return a random backoff duration (by default between 0.5 and 3 seconds)
Duration randomBackoff(int low=500, int high=3000) {
  int milliseconds = uniform(low, high);
  return milliseconds.msecs;
}

/**
  Stores the rate limit state for a given bucket.
*/
struct RateLimitState {
  int remaining;

  /// Time at which this rate limit resets
  long resetTime;

  /// Returns true if this request is valid
  bool willRateLimit() {
    if (this.remaining - 1 < 0) {
      if (getUnixTime() <= this.resetTime) {
        return true;
      }
    }

    return false;
  }

  /// Return the time that needs to be waited before another request can be made
  Duration waitTime() {
    return (this.resetTime - getUnixTime()).seconds + 500.msecs;
  }
}

/**
  RateLimiter provides an interface for rate limiting HTTP Requests.
*/
class RateLimiter {
  ManualEvent[Bucket]     cooldowns;
  RateLimitState[Bucket]  states;

  /// Cooldown a bucket for a given duration. Blocks ALL requests from completing.
  void cooldown(Bucket bucket, Duration duration) {
    if (bucket in this.cooldowns) {
      this.cooldowns[bucket].wait();
    } else {
      this.cooldowns[bucket] = createManualEvent();
      sleep(duration);
      this.cooldowns[bucket].emit();
      this.cooldowns.remove(bucket);
    }
  }

  /**
    Check whether a request can be made for a bucket. If the bucket is on cooldown,
    wait until the cooldown resets before returning.
  */
  bool check(Bucket bucket, Duration timeout) {
    // If we're currently waiting for a cooldown, join the waiting club
    if (bucket in this.cooldowns) {
      if (this.cooldowns[bucket].wait(timeout, 0) != 0) {
        return false;
      }
    }

    // If we don't have the bucket cached, return
    if (bucket !in this.states) return true;

    // If this request will rate limit, wait until it won't anymore
    if (this.states[bucket].willRateLimit()) {
      this.cooldown(bucket, this.states[bucket].waitTime());
    }

    return true;
  }

  /// Update a given bucket with headers returned from a request.
  void update(Bucket bucket, string remaining, string reset, string retryAfter) {
    long resetSeconds = (reset.to!long);

    // If we have a retryAfter header, it may be more accurate
    if (retryAfter != "") {
      FloatingPointControl fpctrl;
      fpctrl.rounding = FloatingPointControl.roundUp;
      long retryAfterSeconds = rndtol(retryAfter.to!long / 1000.0);

      long nextRequestAt = getUnixTime() + retryAfterSeconds;
      if (nextRequestAt > resetSeconds) {
        resetSeconds = nextRequestAt;
      }
    }

    // Create a new RateLimitState if one doesn't exist
    if (bucket !in this.states) {
      this.states[bucket] = RateLimitState();
    }

    // Save our remaining requests and reset seconds
    this.states[bucket].remaining = remaining.to!int;
    this.states[bucket].resetTime = resetSeconds;
  }
}

