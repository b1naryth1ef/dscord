module dscord.types.base;

import std.conv,
       std.typecons,
       std.stdio,
       std.array,
       std.algorithm,
       std.traits,
       std.functional;

import dscord.client;

import vibe.core.core : runTask, sleep;
import vibe.core.sync;

// Commonly used public imports
public import dscord.util.json;
public import std.datetime;

immutable ulong DISCORD_EPOCH = 1420070400000;

// TODO: Eventually this should be a type
alias Snowflake = ulong;

string toString(Snowflake s) {
  return to!string(s);
}

SysTime toSysTime(Snowflake s) {
  return SysTime(unixTimeToStdTime(cast(int)(((s >> 22) + DISCORD_EPOCH) / 1000)));
}

/**
  AsyncChainer is a utility for exposing methods that can help
  chain actions with various delays/resolving patterns.
*/
class AsyncChainer(T) {
  private {
    T obj;
    AsyncChainer!T parent;
    ManualEvent resolveEvent;
    bool ignoreFailure;
  }

  /**
    The base constructor which handles the optional creation of ManualEvent used
    in the case where this member of the AsyncChain has a delay (or depends on
    something with a delay).

    Params:
      obj = the object to wrap for chaining
      hasResolver = if true, create a ManualEvent used for resolving
  */
  this(T obj, bool hasResolver = false) {
    this.obj = obj;

    if (hasResolver) {
      this.resolveEvent = createManualEvent();
    }
  }

  /**
    Delayed constructor creates an AsyncChainer chain member which waits for
    the specified delay before resolving the current and next members of the
    chain.

    Params:
      obj = the object to wrap for chaining
      delay = a duration to delay before resolving
      parent = the parent member in the chain to depend on before resolving
  */
  this(T obj, Duration delay, AsyncChainer!T parent = null) {
    this(obj, true);

    this.parent = parent;

    runTask({
      // If we have a parent, wait on its resolve event first
      if (this.parent) {
        this.parent.resolveEvent.wait();
      }

      // Then sleep for the delay
      sleep(delay);

      // And trigger our resolve event
      this.resolveEvent.emit();
    });
  }

  private void call(string func, Args...)(Args args) {
    if (this.ignoreFailure) {
      try {
        this.obj.call!(func)(args);
      } catch (Exception e) {}
    } else {
      this.obj.call!(func)(args);
    }
  }

  /**
    Utility method for chaining. Returns a new child member of the chain.
  */
  AsyncChainer!T after(Duration delay) {
    return new AsyncChainer!T(this.obj, delay, this);
  }

  /**
    opDispatch override that provides a mechanisim for wrapped chaining of the
    inner object.
  */
  AsyncChainer!T opDispatch(string func, Args...)(Args args) {
    if (this.resolveEvent) {
      auto next = new AsyncChainer!T(this.obj, true);

      runTask({
        this.resolveEvent.wait();
        this.call!(func)(args);
        next.resolveEvent.emit();
      });

      return next;
    } else {
      this.call!(func)(args);
      // this.obj.call!(func)(args);
      return this;
    }
  }

  AsyncChainer!T maybe() {
    this.ignoreFailure = true;
    return this;
  }
}



/**
  Base class for all models. Provides a simple interface definition and some
  utility constructor code.
*/
class IModel {
  Client  client;

  void init() {};
  void load(JSONDecoder obj) {};

  this(Client client, JSONDecoder obj) {
    version (TIMING) {
      client.log.tracef("Starting creation of model %s", this.toString);
      auto sw = StopWatch(AutoStart.yes);
    }

    this.client = client;
    this.init();

    if (obj) this.load(obj);

    version (TIMING) {
      this.client.log.tracef("Finished creation of model %s in %sms", this.toString,
        sw.peek().to!("msecs", real));
    }
  }
}

/**
  Base template for all models. Provides utility methods for AsyncChaining and
  a base constructor that calls the parent IModel constructor.
*/
mixin template Model() {
  this(Client client, JSONDecoder obj) {
    super(client, obj);
  }

  /// Allows chaining based on a delay. Returns a new AsyncChainer of this type.
  auto after(Duration delay) {
    return new AsyncChainer!(typeof(this))(this, delay);
  }

  /// Allows arbitrary chaining. Returns a new AsyncChainer of this type.
  auto chain() {
    return new AsyncChainer!(typeof(this))(this);
  }

  void call(string blah, T...)(T args) {
    __traits(getMember, this, blah)(args);
  }
}

/**
  Utility method which reads a Snowflake off of a fast JSON object.
*/
Snowflake readSnowflake(JSONDecoder obj) {
  string data = obj.read!string;
  if (!data) return 0;
  return data.to!Snowflake;
}

/**
  Utility method which loads many of a model T off of a fast JSON object. Returns
  an array of model T objects.
*/
T[] loadManyArray(T)(Client client, JSONDecoder obj) {
  T[] data;

  foreach (item; obj) {
    data ~= new T(client, obj);
  }

  return data;
}

/**
  Utility method that loads many of a model T off of a fast JSON object. Calls
  the delegate f for each member loaded, returning nothing.
*/
void loadMany(T)(Client client, JSONDecoder obj, void delegate(T) F) {
  foreach (item; obj) {
    F(new T(client, obj));
  }
}

/**
  Utility method that loads many of a model T off of a fast JSON object, passing
  in a sub-type TSub as the first argument to the constructor. Calls the delegate
  f for each member loaded, returning nothing.
*/
void loadManyComplex(TSub, T)(TSub sub, JSONDecoder obj, void delegate(T) F) {
  foreach (item; obj) {
    F(new T(sub, obj));
  }
}

/**
  ModelMap serves as an abstraction layer around associative arrays that store
  models. Usually ModelMaps will be a direct mapping of ID (Snowflake) -> Model.
*/
class ModelMap(TKey, TValue) {
  /// Underlying associative array
  TValue[TKey]  data;

  /// Set the key to a value.
  TValue set(TKey key, TValue value) {
    if (value is null) {
      this.remove(key);
      return null;
    }

    this.data[key] = value;
    return value;
  }

  /// Return the value for a key. Throws an exception if the key does not exist.
  TValue get(TKey key) {
    return this.data[key];
  }

  /// Return the value for a key, or if it doesn't exist a default value.
  TValue get(TKey key, TValue def) {
    if (this.has(key)) {
      return this.get(key);
    }
    return def;
  }

  /// Removes a key.
  void remove(TKey key) {
    this.data.remove(key);
  }

  /// Returns true if the key exists within the mapping.
  bool has(TKey key) {
    return (key in this.data) != null;
  }

  /// Indexing by key
  TValue opIndex(TKey key) {
    return this.get(key);
  }

  /// Indexing assignment
  void opIndexAssign(TValue value, TKey key) {
    this.set(key, value);
  }

  /// Returns the length of the mapping.
  size_t length() {
    return this.data.length;
  }

  /// Returns a new mapping from a subset of keys.
  auto subset(TKey[] keysWanted) {
    auto obj = new ModelMap!(TKey, TValue);

    foreach (k; keysWanted) {
      obj[k] = this.get(k);
    }

    return obj;
  }

  /**
    Allows using a delegate to filter the keys/values of the mapping into a new
    mapping.

    Params:
      f = a delegate which returns true if the passed in key/value matches.
  */
  auto filter(bool delegate(TKey, TValue) f) {
    return this.subset(this.data.keys.filter!((k) => f(k, this.get(k))).array);
  }

  /**
    Allows using a delegate to filter the values of the mapping.

    Params:
      f = a delegate which returns true if the passed in value matches.
  */
  auto filter(bool delegate(TValue) f) {
    return this.data.values.filter!(f);
  }

  /**
    Allows applying a delegate over the values of the mapping.

    Params:
      f = a delegate which is applied to each value in the mapping.
  */
  auto each(void delegate(TValue) f) {
    return this.data.values.each!(f);
  }

  /**
    Returns a single value from the mapping, based on the return value of a
    delegate.

    Params:
      f = a delegate which returns true if the value passed in matches.
      def = default value to return if nothing matches.
  */
  TValue pick(bool delegate(TValue) f, TValue def=null) {
    foreach (value; this.data.values) {
      if (f(value)) {
        return value;
      }
    }
    return def;
  }

  /// Returns an array of keys from the mapping.
  auto keys() {
    return this.data.keys;
  }

  /// Returns an array of values from the mapping.
  auto values() {
    return this.data.values;
  }

  /// Return the set-union for an array of keys
  TKey[] keyUnion(TKey[] other) {
    return setUnion(this.keys, other).array;
  }

  int opApply(int delegate(ref TKey, ref TValue) dg) {
    int result = 0;
    foreach (a, b; this.data) {
      result = dg(a, b);
      if (result) break;
    }
    return result;
  }
}
