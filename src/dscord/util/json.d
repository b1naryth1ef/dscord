/**
  Utilities releated to JSON processing.
*/
module dscord.util.json;

import std.stdio;

import std.conv,
       std.meta,
       std.traits;

public import vibe.data.json : VibeJSON = Json, parseJsonString;

import dscord.types.base : IModel;
public import dscord.util.string : camelCaseToUnderscores;


enum JSONIgnore;
enum JSONFlat;

struct JSONSource {
  string src;
}

struct JSONListToMap {
  string field;
}

VibeJSON serializeToJSON(T)(T sourceObj, string[] ignoredFields = []) {
  import std.algorithm : canFind;

  version (JSON_DEBUG_S) {
    pragma(msg, "Generating Serialization for: ", typeof(sourceObj));
  }

  VibeJSON result = VibeJSON.emptyObject;
  string sourceFieldName, dstFieldName;

  foreach (fieldName; FieldNameTuple!T) {
    // Runtime check if we are being ignored
    if (ignoredFields.canFind(fieldName)) continue;

    version(JSON_DEBUG_S) {
      pragma(msg, "  -> ", fieldName);
    }

    alias FieldType = typeof(__traits(getMember, sourceObj, fieldName));

    static if (hasUDA!(mixin("sourceObj." ~ fieldName), JSONIgnore)) {
      version (JSON_DEBUG) {
        pragma(msg, "    -> skipping");
        writefln("  -> skipping");
      }
      continue;
    } else static if ((is(FieldType == struct) || is(FieldType == class)) &&
        hasUDA!(typeof(mixin("sourceObj." ~ fieldName)), JSONIgnore)) {
      version (JSON_DEBUG) {
        pragma(msg, "    -> skipping");
        writefln("  -> skipping");
      }
      continue;
    } else static if (fieldName[0] == '_') {
      version (JSON_DEBUG) {
        pragma(msg, "    -> skipping");
        writefln("  -> skipping");
      }
      continue;
    } else {
        static if (hasUDA!(mixin("sourceObj." ~ fieldName), JSONSource)) {
          dstFieldName = getUDAs!(mixin("sourceObj." ~ fieldName), JSONSource)[0].src;
        } else {
          dstFieldName = camelCaseToUnderscores(fieldName);
        }


      static if (hasUDA!(mixin("sourceObj." ~ fieldName), JSONListToMap)) {
        version (JSON_DEBUG) pragma(msg, "    -= TODO");
        // TODO
        /+
          __traits(getMember, sourceObj, fieldName) = typeof(__traits(getMember, sourceObj, fieldName)).fromJSONArray!(
            getUDAs!(mixin("sourceObj." ~ fieldName), JSONListToMap)[0].field
          )(sourceObj, fieldData);
        +/
      } else {
        version (JSON_DEBUG) pragma(msg, "    -= dumpSingleField");
        result[dstFieldName] = dumpSingleField(mixin("sourceObj." ~ fieldName));
      }
    }
  }

  return result;
}

private VibeJSON dumpSingleField(T)(ref T field) {
  static if (is(T == struct)) {
    return field.serializeToJSON;
  } else static if (is(T == class)) {
    return field ? field.serializeToJSON : VibeJSON(null);
  } else static if (isSomeString!T) {
    return VibeJSON(field);
  } else static if (isArray!T) {
    return VibeJSON();
    // TODO
  } else {
    return VibeJSON(field);
  }
}

void deserializeFromJSON(T)(T sourceObj, VibeJSON sourceData) {
  version (JSON_DEBUG) {
    pragma(msg, "Generating Deserialization for: ", typeof(sourceObj));
  }

  string sourceFieldName, dstFieldName;
  VibeJSON fieldData;

  foreach (fieldName; FieldNameTuple!T) {
    version (JSON_DEBUG) {
      pragma(msg, "  -> ", fieldName);
      writefln("%s", fieldName);
    }

    alias FieldType = typeof(__traits(getMember, sourceObj, fieldName));

    // First we need to check whether we should ignore this field
    static if (hasUDA!(mixin("sourceObj." ~ fieldName), JSONIgnore)) {
      version (JSON_DEBUG) {
        pragma(msg, "    -> skipping");
        writefln("  -> skipping");
      }
      continue;
    } else static if ((is(FieldType == struct) || is(FieldType == class)) &&
        hasUDA!(typeof(mixin("sourceObj." ~ fieldName)), JSONIgnore)) {
      version (JSON_DEBUG) {
        pragma(msg, "    -> skipping");
        writefln("  -> skipping");
      }
      continue;
    } else static if (fieldName[0] == '_') {
      version (JSON_DEBUG) {
        pragma(msg, "    -> skipping");
        writefln("  -> skipping");
      }
      continue;
    } else {
      // Now we grab the data
      static if (hasUDA!(mixin("sourceObj." ~ fieldName), JSONFlat)) {
        fieldData = sourceData;
      } else {
        static if (hasUDA!(mixin("sourceObj." ~ fieldName), JSONSource)) {
          sourceFieldName = getUDAs!(mixin("sourceObj." ~ fieldName), JSONSource)[0].src;
        } else {
          sourceFieldName = camelCaseToUnderscores(fieldName);
        }

        if (
            (sourceFieldName !in sourceData) ||
            (sourceData[sourceFieldName].type == VibeJSON.Type.undefined) ||
            (sourceData[sourceFieldName].type == VibeJSON.Type.null_)) {
          continue;
        }

        fieldData = sourceData[sourceFieldName];
      }

      // Now we parse the data
      version (JSON_DEBUG) {
        writefln("  -> src from %s", fieldData);
      }

      // meh
      static if (hasUDA!(mixin("sourceObj." ~ fieldName), JSONListToMap)) {
        version (JSON_DEBUG) pragma(msg, "    -= JSONListToMap");
        __traits(getMember, sourceObj, fieldName) = typeof(__traits(getMember, sourceObj, fieldName)).fromJSONArray!(
          getUDAs!(mixin("sourceObj." ~ fieldName), JSONListToMap)[0].field
        )(sourceObj, fieldData);
      } else {
        version (JSON_DEBUG) pragma(msg, "    -= loadSingleField");
        __traits(getMember, sourceObj, fieldName) = loadSingleField!(T, FieldType)(sourceObj, fieldData);
        // loadSingleField!(T, FieldType)(sourceObj, __traits(getMember, sourceObj, fieldName), fieldData);
      }
    }
  }
}

template ArrayElementType(T : T[]) {
  alias T ArrayElementType;
}

template AATypes(T) {
  alias ArrayElementType!(typeof(T.keys)) key;
  alias ArrayElementType!(typeof(T.values)) value;
}

private Z loadSingleField(T, Z)(T sourceObj, VibeJSON data) {
  version (JSON_DEBUG) {
    writefln("  -> parsing type %s from %s", fullyQualifiedName!Z, data.type);
  }

  // Some deserialization strategies we take require a reference to the type.
  Z result;

  static if (is(Z == struct)) {
    result.deserializeFromJSON(data);
    return result;
  } else static if (is(Z == class)) {
    // If we have a constructor which allows the parent object and the JSON data use it
    static if (__traits(compiles, {
      new Z(sourceObj, data);
    })) {
      result = new Z(sourceObj, data);
      result.attach(sourceObj);
    } else static if (hasMember!(Z, "client")) {
      result = new Z(__traits(getMember, sourceObj, "client"), data);
      result.attach(sourceObj);
    } else {
      result = new Z;
      result.deserializeFromJSON(data);
    }
    return result;
  } else static if (isSomeString!Z) {
    static if (__traits(compiles, {
      return cast(Z)data.get!string;
    })) {
      return cast(Z)data.get!string;
    } else {
      return data.get!string.to!Z;
    }
  } else static if (isArray!Z) {
    alias AT = ArrayElementType!(Z);

    foreach (obj; data) {
      /* AT v; */
      /* loadSingleField!(T, AT)(sourceObj, v, obj); */
      AT v = loadSingleField!(T, AT)(sourceObj, obj);
      result ~= v;
    }
    return result;
  } else static if (isAssociativeArray!Z) {
    alias ArrayElementType!(typeof(result.keys)) Tk;
    alias ArrayElementType!(typeof(result.values)) Tv;

    foreach (ref string k, ref v; data) {
      /* Tv val; */
      /* loadSingleField!(T, Tv)(sourceObj, val, v); */
      Tv val = loadSingleField!(T, Tv)(sourceObj, v);

      result[k.to!Tk] = val;
    }
    return result;
  } else static if (isIntegral!Z) {
    if (data.type == VibeJSON.Type.string) {
      return data.get!string.to!Z;
    } else {
      static if (__traits(compiles, { result = data.to!Z; })) {
        return data.to!Z;
      } else {
        return data.get!Z;
      }
    }
  } else {
    return data.to!Z;
  }
}

private void attach(T, Z)(T baseObj, Z parentObj) {
  foreach (fieldName; FieldNameTuple!T) {
    alias FieldType = typeof(__traits(getMember, baseObj, fieldName));

    static if (is(FieldType == Z)) {
      __traits(getMember, baseObj, fieldName) = parentObj;
    }
  }
}


T deserializeFromJSON(T)(VibeJSON jsonData) {
  T result = new T;
  result.deserializeFromJSON(jsonData);
  return result;
}

T[] deserializeFromJSONArray(T)(VibeJSON jsonData, T delegate(VibeJSON) cons) {
  T[] result;

  foreach (item; jsonData) {
    result ~= cons(item);
  }

  return result;
}
