module types.user;

import types.base,
       types.guild,
       util.json;

class User : APIObject {
  Snowflake  id;
  string     username;
  string     discriminator;
  byte[]     avatar;
  bool       verified;
  string     email;

  // Caches
  Cache!GuildMap    guildCache;
  // Cache!ChannelMap  dmCache;

  this(JSONObject obj) {
    super(obj);

    this.guildCache = new Cache!GuildMap;
  }

  void load(JSONObject obj) {
    this.id = obj.get!Snowflake("id");
    this.username = obj.get!string("username");
    this.discriminator = obj.get!string("discriminator");
    this.avatar = cast(byte[])obj.get!string("avatar");
    this.verified = obj.get!bool("verified", false);
    this.email = obj.get!string("email", "");
  }

  @property GuildMap guilds() {
    return this.guildCache.all({
      return this.client.meGuilds();
    });
  }

  Guild guild(Snowflake id) {
    return this.guildCache.get()[id];
  }

  Guild getGuild(Snowflake id) {
    // TODO: update cache
    return this.client.guild(id);
  }

  GuildMap getGuilds() {
    return this.guildCache.refresh({
      return this.client.meGuilds();
    });
  }
}
