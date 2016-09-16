/// Utilties related to unix time
module dscord.util.time;

version (Posix) {
  import core.sys.posix.sys.time;

  /// Returns UTC time in microseconds
  long getUnixTimeMicro() {
    timeval t;
    gettimeofday(&t, null);
    return 1000000 * t.tv_sec + t.tv_usec;
  }

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
}

version (Windows) {
  import core.sys.windows.winbase;

  long getUnixTimeMilli() {
    SYSTEMTIME systemTime;
    GetSystemTime(&systemTime);
    FILETIME fileTime;
    SystemTimeToFileTime( &systemTime, &fileTime );
    long fileTimeNano100;
    fileTimeNano100 = ((cast(long)fileTime.dwHighDateTime) << 32) + fileTime.dwLowDateTime;
    long posixTime = fileTimeNano100/10000 - 11644473600000;
    return posixTime;
  }

  long getUnixTime() {
    return getUnixTimeMilli() / 1000;
  }
}