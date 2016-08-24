/**
  Utilities for tracking and managing rate limits.
*/
module dscord.api.ratelimit;

import std.conv,
       std.math,
       std.random,
       core.time,
       core.sync.condition,
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
  Stores the rate limit state for a given route.
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
  ManualEvent[Route]     cooldowns;
  RateLimitState[Route]  states;

  /// Cooldown a route for a given duration. Blocks ALL requests from completing.
  void cooldown(Route route, Duration duration) {
    if (route in this.cooldowns) {
      this.cooldowns[route].wait();
    } else {
      this.cooldowns[route] = createManualEvent();
      sleep(duration);
      this.cooldowns[route].emit();
      this.cooldowns.remove(route);
    }
  }

  /**
    Check whether a request can be made for a route. If the route is on cooldown,
    wait until the cooldown resets before returning.
  */
  bool check(Route route, Duration timeout) {
    // If we're currently waiting for a cooldown, join the waiting club
    if (route in this.cooldowns) {
      if (this.cooldowns[route].wait(timeout, 0) != 0) {
        return false;
      }
    }

    // If we don't have the route cached, return
    if (route !in this.states) return true;

    // If this request will rate limit, wait until it won't anymore
    if (this.states[route].willRateLimit()) {
      this.cooldown(route, this.states[route].waitTime());
    }

    return true;
  }

  /// Update a given route with headers returned from a request.
  void update(Route route, string remaining, string reset, string retryAfter) {
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
    if (route !in this.states) {
      this.states[route] = RateLimitState();
    }

    // Save our remaining requests and reset seconds
    this.states[route].remaining = remaining.to!int;
    this.states[route].resetTime = resetSeconds;
  }
}

