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

  string popBack() {
    string line = this.lines[$-1];
    this.lines = this.lines[0..$-2];
    return line;
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

    if (this.length + raw.length > this.maxLength) {
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

/**
  Utility class for constructing tabulated messages.
*/
class MessageTable {
  private {
    string[][] entries;
    size_t[] sizes;
    string delim;
    bool wrapped;
  }

  /**
    Creates a new MessageTable

    Params:
      delim = deliminator to use between table columns
      wrapped = whether to place a deliminator at the left/right margins
  */
  this(string delim=" | ", bool wrapped=true) {
    this.delim = delim;
    this.wrapped = wrapped;
  }

  /**
    Add a row.

    Params:
      args = sorted columns
  */
  void add(string[] args...) {
    // Duplicate the args (its a reference) and append to our rows
    this.entries ~= args.dup;

    // Iterate over all the columns and update our sizes storage
    size_t pos = 0;
    foreach (part; args) {
      if (this.sizes.length <= pos) {
        this.sizes ~= part.length;
      } else if (this.sizes[pos] < part.length) {
        this.sizes[pos] = part.length;
      }
      pos++;
    }
  }

  /**
    Appends the output of this table to a message buffer
  */
  void appendToBuffer(MessageBuffer buffer) {
    // Iterate over each row
    foreach (entry; this.entries) {
      size_t pos;
      string line;

      // If we're wrapped, add left margin deliminator
      if (this.wrapped) line ~= this.delim;

      // Iterate over each column in the row
      foreach (part; entry) {
        line ~= part ~ " ".replicate(this.sizes[pos] - part.length) ~ this.delim;
        pos++;
      }

      // If we're not wrapped, remove the end deliminator
      if (!this.wrapped) line = line[0..($ - this.delim.length)];
      buffer.append(line);
    }
  }
}
