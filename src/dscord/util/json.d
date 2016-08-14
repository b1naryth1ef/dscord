/**
  Utilities releated to JSON processing.
*/
module dscord.util.json;

public import fast.json : FastJson = Json, parseTrustedJSON, DataType;
public import vibe.data.json : VibeJSON = Json, parseJsonString;

alias JSON = FastJson!(0u, false);
