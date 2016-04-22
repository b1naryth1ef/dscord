module types.message;

import types.base;


class Message : Model {
  Snowflake  id;

  this(JSONObject obj) {
    super(obj);
  }

  override void load(JSONObject obj) {
    this.id = obj.get!Snowflake("id");
  }
}
