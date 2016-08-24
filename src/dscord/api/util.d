module dscord.api.util;

import std.uri,
       std.array,
       std.format,
       std.algorithm.iteration;

import vibe.http.client,
       vibe.stream.operations;

import dscord.types,
       dscord.util.errors;

/**
  An error returned from the `APIClient` based on HTTP response code.
*/
class APIError : BaseError {
  this(int code, string msg) {
    super("[%s] %s", code, msg);
  }
}

/**
  Simple URL constructor to help building routes
*/
struct U {
  private {
    string          _bucket;
    string[]        paths;
    string[string]  params;
  }

  @property string value() {
    string url = this.paths.join("/");

    if (this.params.length) {
      string[] parts;
      foreach (ref key, ref value; this.params) {
        parts ~= format("%s=%s", key, encodeComponent(value));
      }
      url ~= "?" ~ parts.join("&");
    }

    return "/" ~ url;
  }

  this(string url) {
    this.paths ~= url;
  }

  this(string paramKey, string paramValue) {
    this.params[paramKey] = paramValue;
  }

  string getBucket() {
    return this._bucket;
  }

  U opCall(string url) {
    this.paths ~= url;
    return this;
  }

  U opCall(Snowflake s) {
    this.paths ~= s.toString();
    return this;
  }

  U opCall(string paramKey, string paramValue) {
    this.params[paramKey] = paramValue;
    return this;
  }

  U bucket(string bucket) {
    this._bucket = bucket;
    return this;
  }

  U param(string name, string value) {
    this.params[name] = value;
    return this;
  }
}

/**
  Wrapper for HTTP REST Responses.
*/
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

  /**
    Raises an APIError exception if the request failed.
  */
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

