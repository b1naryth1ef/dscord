/**
  Utility types that wrap specific utility functionality, without directly
  representing data/modeling from Discord.
*/
module dscord.types.util;

import std.format,
       std.array;

/**
  Utility class for constructing messages that can be sent over discord, allowing
  for inteligent limiting of size and stripping of formatting characters.
*/
class MessageBuffer {
  private {
    bool codeBlock;
    bool filter;
    size_t _maxLength;
    string[] lines;
  }

  /**
    Params:
      codeBlock = if true, this message will be sent within a codeblock
      filter = if true, appended lines will be filtered for codeblocks/newlines
      maxLength = maximum length of this message, defaults to 2000
  */
  this(bool codeBlock = true, bool filter = true, size_t maxLength = 2000) {
    this.codeBlock = codeBlock;
    this.filter = filter;
    this._maxLength = maxLength;
  }

  /**
    Max length of this message (subtracting for formatting)
  */
  @property size_t maxLength() {
    size_t value = this._maxLength;

    // Codeblock backticks
    if (this.codeBlock) {
      value -= 6;
    }

    // Newlines
    value -= this.lines.length;

    return value;
  }

  /**
    Current length of this message (without formatting)
  */
  @property size_t length() {
    size_t len;

    foreach (line; lines) {
      len += line.length;
    }

    return len;
  }

  /**
    Formatted contents of this message.
  */
  @property string contents() {
    string contents = this.lines.join("\n");

    if (this.codeBlock) {
      return "```" ~ contents ~ "```";
    }

    return contents;
  }

  /**
    Append a line to this message. Returns false if the buffer is full.
  */
  bool append(string line) {
    string raw = line;

    // TODO: make this smarter
    if (this.filter) {
      raw = raw.replace("`", "").replace("\n", "");
    }

    if (this.length + raw.length > this.realMaxLength) {
      return false;
    }

    this.lines ~= raw;
    return true;
  }

  /**
    Format and append a line to this message. Returns false if the buffer is
    full.
  */
  bool appendf(T...)(string fmt, T args) {
    return this.append(format(fmt, args));
  }
}
