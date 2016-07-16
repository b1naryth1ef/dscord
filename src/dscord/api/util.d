module dscord.api.util;

import vibe.http.client,
       vibe.stream.operations;

import dscord.types.all,
       dscord.util.errors;

class APIError : BaseError {
  this(int code, string msg) {
    super("[%s] %s", code, msg);
  }
}

// Simple URL constructor to help building routes
struct U {
  string  _bucket;
  string  value;

  this(string url) {
    if (url[0] != '/') {
      url = "/" ~ url;
    }

    this.value = url;
  }

  U opCall(string url) {
    this.value ~= "/" ~ url;
    return this;
  }

  U opCall(Snowflake s) {
    this.opCall(s.toString());
    return this;
  }

  U bucket(string bucket) {
    this._bucket = bucket;
    return this;
  }
}

// Wrapper for HTTP API Responses
// TODO: move this to another place
class APIResponse {
  private {
    HTTPClientResponse res;
  }

  // We cache content so HTTPClientResponse can be GC'd without pain
  string content;

  this(HTTPClientResponse res) {
    this.res = res;
    this.content = res.bodyReader.readAllUTF8();
    this.res.disconnect();
  }

  APIResponse ok() {
    if (100 < this.statusCode && this.statusCode < 400) {
      return this;
    }

    throw new APIError(this.statusCode, this.content);
  }

  @property string contentType() {
    return this.res.contentType;
  }

  @property int statusCode() {
    return this.res.statusCode;
  }

  @property VibeJSON vibeJSON() {
    return parseJsonString(this.content);
  }

  @property JSON fastJSON() {
    return parseTrustedJSON(this.content);
  }

  string header(string name, string def="") {
    if (name in this.res.headers) {
      return this.res.headers[name];
    }

    return def;
  }
}

