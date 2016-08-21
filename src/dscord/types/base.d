module dscord.types.base;

import std.conv,
       std.typecons,
       std.stdio,
       std.algorithm,
       std.traits,
       std.functional;

import dscord.client;

import vibe.core.core : runTask, sleep;
import vibe.core.sync;

// Commonly used public imports
public import dscord.util.json;
public import std.datetime;

// TODO: Eventually this should be a type
alias Snowflake = ulong;

string toString(Snowflake s) {
  return to!string(s);
}

/*
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
  void load(ref JSON obj) {};

  this(Client client, ref JSON obj) {
    version (TIMING) {
      client.log.tracef("Starting creation of model %s", this.toString);
      auto sw = StopWatch(AutoStart.yes);
    }

    this.client = client;
    this.init();
    this.load(obj);

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
  this(Client client, ref JSON obj) {
    super(client, obj);
  }

  auto after(Duration delay) {
    return new AsyncChainer!(typeof(this))(this, delay);
  }

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
Snowflake readSnowflake(ref JSON obj) {
  string data = obj.read!string;
  if (!data) return 0;
  return data.to!Snowflake;
}

/**
  Utility method which loads many of a model T off of a fast JSON object. Returns
  an array of model T objects.
*/
T[] loadManyArray(T)(Client client, ref JSON obj) {
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
void loadMany(T)(Client client, ref JSON obj, void delegate(T) F) {
  foreach (item; obj) {
    F(new T(client, obj));
  }
}

/**
  Utility method that loads many of a model T off of a fast JSON object, passing
  in a sub-type TSub as the first argument to the constructor. Calls the delegate
  f for each member loaded, returning nothing.
*/
void loadManyComplex(TSub, T)(TSub sub, ref JSON obj, void delegate(T) F) {
  foreach (item; obj) {
    F(new T(sub, obj));
  }
}

/**
  A utility wrapper around an associative array that stores models.
*/
class ModelMap(TKey, TValue) {
  TValue[TKey]  data;

  /**
    Set the key to a value.
  */
  TValue set(TKey key, TValue value) {
    if (value is null) {
      this.remove(key);
      return null;
    }

    this.data[key] = value;
    return value;
  }

  /**
    Return the value for a key.
  */
  TValue get(TKey key) {
    return this.data[key];
  }

  /**
    Return the value for a key, or if it doesn't exist a default value.
  */
  TValue get(TKey key, TValue def) {
    if (this.has(key)) {
      return this.get(key);
    }
    return def;
  }

  /**
    Utility method that returns the value for a key.
  */
  TValue opCall(TKey key) {
    return this.data[key];
  }

  /**
    Removes a key.
  */
  void remove(TKey key) {
    this.data.remove(key);
  }

  /**
    Returns true if the key exists within the mapping.
  */
  bool has(TKey key) {
    return (key in this.data) != null;
  }

  TValue opIndex(TKey key) {
    return this.get(key);
  }

  void opIndexAssign(TValue value, TKey key) {
    this.set(key, value);
  }

  /**
    Returns the length of the mapping.
  */
  size_t length() {
    return this.data.length;
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
  */
  TValue pick(bool delegate(TValue) f) {
    foreach (value; this.data.values) {
      if (f(value)) {
        return value;
      }
    }
    return null;
  }

  /**
    Returns an array of keys from the mapping.
  */
  auto keys() {
    return this.data.keys;
  }

  /**
    returns an array of values from the mapping.
  */
  auto values() {
    return this.data.values;
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
