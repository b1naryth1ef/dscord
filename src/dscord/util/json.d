/**
  Utilities releated to JSON processing.
*/
module dscord.util.json;

import std.traits;

public import vibe.data.json : VibeJSON = Json, parseJsonString;

/*
  Why is this not an interface with seperate implementations for each JSON parser?
  Because for some reason that doesnt link correctly. Cri.
*/

version (Have_fast) {
  public import fast.json : FastJson = Json, parseTrustedJSON, DataType;

  alias JSON = FastJson!(0u, false);

  class JSONDecoder {
    JSON obj;

    this(string content) {
      this.obj = parseTrustedJSON(content);
    }

    void keySwitch(Args...)(scope void delegate()[Args.length] dlg...) {
      this.obj.keySwitch!(Args)(dlg);
    }

    T singleKey(T)(string key) {
      return obj.singleKey(key).read!T;
    }

    T read(T)() {
      static if (isSomeString!T) {
        return obj.read!T.dup;
      } else {
        return obj.read!T;
      }
    }

    T[] readArray(T)() {
      return obj.read!(T[]);
    }

    VibeJSON.Type peek() {
      final switch (this.obj.peek()) {
        case DataType.string:
          return VibeJSON.Type.string;
        case DataType.number:
          return VibeJSON.Type.int_;
        case DataType.object:
          return VibeJSON.Type.object;
        case DataType.array:
          return VibeJSON.Type.array;
        case DataType.boolean:
          return VibeJSON.Type.bool_;
        case DataType.null_:
          return VibeJSON.Type.null_;
      }
    }

    int opApply(scope int delegate(const size_t) foreachBody) {
      return this.obj.opApply(foreachBody);
    }

    void skipValue() {
      this.obj.skipValue();
    }

    @property int delegate(scope int delegate(ref const char[])) byKey(string lastKey="") {
      return this.obj.byKey();
    }
  }

} else {

  class JSONDecoder {
    VibeJSON obj;

    private VibeJSON currentObj;
    private string currentKey;
    private uint currentIndex = uint.max;
    private string byLastKey;

    this(string content) {
      this.obj = parseJsonString(content);
      this.currentObj = obj;
    }

    private VibeJSON current() {
      if (this.currentKey != "") {
        return this.currentObj[this.currentKey];
      } else if (this.currentIndex != uint.max) {
        return this.currentObj[this.currentIndex];
      } else {
        throw new Exception("Cannot read from un keyed/indexed object.");
      }
    }

    void keySwitch(Args...)(scope void delegate()[Args.length] dlg...) {
      VibeJSON lastObj;
      string lastKey = this.currentKey;

      // If we have a currentKey and we're keySwitching, adjust currentObj
      if (this.currentKey != "") {
        lastObj = this.currentObj;
        this.currentObj = this.currentObj[this.currentKey];
      }

      foreach (idx, arg; Args) {
        if (this.currentObj[arg].type == VibeJSON.Type.undefined) {
          continue;
        }
        this.currentKey = arg;
        dlg[idx]();
      }

      this.currentKey = lastKey;
      this.currentObj = lastObj;
    }

    T singleKey(T)(string key) {
      return this.currentObj[key].get!T;
    }

    T read(T)() {
      if (this.current().type == VibeJSON.Type.null_) {
        T v;
        return v;
      }

      return this.current().get!T;
    }

    T[] readArray(T)() {
      T[] array;

      foreach (ref VibeJSON item; this.currentObj[this.currentKey]) {
        array ~= item.get!T;
      }

      return array;
    }

    VibeJSON.Type peek() {
      return this.current().type;
    }

    int opApply(scope int delegate(const size_t) foreachBody) {
      int i = 0;

      VibeJSON lastObj = this.currentObj;
      string lastKey = this.currentKey;
      this.currentKey = "";

      foreach (uint idx, VibeJSON item; lastObj[lastKey]) {
        if (item.type == VibeJSON.Type.object) {
          this.currentObj = item;
        } else {
          this.currentIndex = idx;
        }
        i = foreachBody(0);
      }

      this.currentKey = lastKey;
      this.currentObj = lastObj;
      this.currentIndex = uint.max;
      return i;
    }

    void skipValue() {
      this.currentKey = "";
      this.currentIndex = uint.max;
    }

    @property int delegate(scope int delegate(ref const char[])) byKey(string lastKey="") {
      this.byLastKey = lastKey;
      return &this.byKeyImpl;
    }

    private int byKeyImpl(scope int delegate(ref const char[]) foreachBody) {
      string lastKey = this.currentKey;

      foreach (string key, VibeJSON value; this.currentObj) {
        if (key == this.byLastKey) continue;
        this.currentKey = key;
        foreachBody(key);
      }

      // If we have a last key, send it to the delegate now
      if (this.byLastKey in this.currentObj) {
        this.currentKey = this.byLastKey;
        foreachBody(this.byLastKey);
      }

      this.currentKey = lastKey;
      return 0;
    }
  }
}
