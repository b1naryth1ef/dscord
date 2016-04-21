# D-scord
D-scord is a Discord client library written in D-lang thats focused on performance at high user and guild counts.

## Example
```d

import dscord.api.client;

// Setup an API client with our auth token
APIClient client = new APIClient("my_auth_token");

// Get the current user (over the API)
User me = client.me();

// Get the users guilds, using the local cache
GuildMap guilds = me.guilds;

// But, if we want we can force a refresh from the API
GuildMap fresherGuilds = me.getGuilds();

// Or, maybe we should grab a specific guild and skip the cache
Guild myFavoriteGuild = me.getGuild(Snowflake(1234567890));
```
