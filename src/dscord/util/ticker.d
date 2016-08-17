/**
  Utility for medium-precision interval timing.
*/

module dscord.util.ticker;

import core.time,
       std.algorithm.comparison;

import dscord.util.time;
import vibe.core.core : vibeSleep = sleep;

/**
  Ticker which can be used for interval-based timing. Operates at millisecond
  precision.
*/
class Ticker {
  private {
    long interval;
    long next = 0;
  }

  /**
    Create a new Ticker

    Params:
      interval = interval to tick at (any unit up to millisecond precision)
      autoStart = whether the instantiation of the object marks the first tick
  */
  this(Duration interval, bool autoStart=false) {
    this.interval = interval.total!"msecs";

    if (autoStart) this.start();
  }

  /// Sets when the next tick occurs
  private void setNext(long now = 0) {
    this.next = (now ? now : getUnixTimeMilli()) + this.interval;
  }

  /// Starts the ticker
  void start() {
    assert(this.next == 0, "Cannot start already running ticker");
    this.setNext();
  }

  /// Sleeps until the next tick
  void sleep() {
    long now = getUnixTimeMilli();

    if (this.next < now) {
      this.setNext();
      return;
    }

    long delay = min(this.interval, this.next - now);
    vibeSleep(delay.msecs);
    this.setNext();
  }
}

unittest {
  Ticker t = new Ticker(1.seconds);

  for (int i = 0; i < 10; i++) {
    t.sleep();
  }
}
