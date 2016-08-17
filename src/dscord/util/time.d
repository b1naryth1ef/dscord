/// Utilties related to unix time
module dscord.util.time;

import core.sys.posix.sys.time;

/// Returns UTC time in milliseconds.
long getUnixTimeMilli() {
  timeval t;
  gettimeofday(&t, null);
  return t.tv_sec * 1000 + t.tv_usec / 1000;
}

/// Returns UTC time in seconds.
long getUnixTime() {
  return getUnixTimeMilli() / 1000;
}

