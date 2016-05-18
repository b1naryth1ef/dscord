# D-scord
D-scord is a Discord client library written in D-lang thats focused on performance at high user and guild counts.

## Compiling
Because of [this](https://github.com/dlang/phobos/commit/1f1ed031a3215b3fa6585ccca189d68c1ad5b154) lovely bug, you need to run a nightly version of the D compiler for now. Luckily its super easy, just download 'DMD Nightly' from [here](https://dlang.org/download.html). DMD 2.072 and up are supported.

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
