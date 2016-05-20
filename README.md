# dscord
dscord is a Discord client library written in D-lang thats focused on performance at high user and guild counts.

## Compiling
To compile dscord, you need any modern D-lang compiler (I recommend the latest stable version of dmd).

## Example
```d
import dscord.client;

// First, setup an API client with our bot auth token
auto client = new Client("MY_BOT_AUTH_TOKEN");

// Bind a state update, this will inform us when we've recieved all guilds
client.state.onStartupComplete = {
  writefln("Startup Complete");
};

// Bind a gateway event, this will tell us when we've gotten (and processed) the ready payload
client.gw.onEvent!Ready((Ready r) {
  writeln("Ready Complete");
});

// Next, open up our gateway connection
client.gw.start();
```
