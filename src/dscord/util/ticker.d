/**
  Utility for medium-precision interval timing.
*/

module dscord.util.ticker;

import core.time;
import vibe.core.core : vibeSleep = sleep;
import core.sys.posix.sys.time;

/**
  Returns UTC time in milliseconds.
*/
long getUnixTimeMilli() {
  timeval t;
  gettimeofday(&t, null);
  return t.tv_sec * 1000 + t.tv_usec / 100;
}

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

    vibeSleep((this.next - now).msecs);
    this.setNext();
  }
}

unittest {
  Ticker t = new Ticker(1.seconds);

  for (int i = 0; i < 10; i++) {
    t.sleep();
  }
}
