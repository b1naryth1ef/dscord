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
class APIResponse {
  private {
    HTTPClientResponse res;
  }

  this(HTTPClientResponse res) {
    this.res = res;
  }

  void ok() {
    if (100 < this.statusCode && this.statusCode < 400) {
      return;
    }

    throw new APIError(this.statusCode, this.content);
  }

  @property string contentType() {
    return this.res.contentType;
  }

  @property int statusCode() {
    return this.res.statusCode;
  }

  @property VibeJSON json() {
    return parseJsonString(this.content);
  }

  @property string content() {
    return this.res.bodyReader.readAllUTF8();
  }

  string header(string name, string def="") {
    if (name in this.res.headers) {
      return this.res.headers[name];
    }

    return def;
  }
}

