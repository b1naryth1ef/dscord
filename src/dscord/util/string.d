module dscord.util.string;

import std.string;
import std.array;
import std.ascii : isLower, isUpper;

pure string camelCaseToUnderscores(string input) {
  auto stringBuilder = appender!string;
  stringBuilder.reserve(input.length * 2);
  bool previousWasLower = false;

  foreach (c; input) {
    if (previousWasLower && c.isUpper()) {
      stringBuilder.put('_');
    }

    if (c.isLower()) {
      previousWasLower = true;
    } else {
      previousWasLower = false;
    }

    stringBuilder.put(c);
  }

  return stringBuilder.data.toLower();
}
