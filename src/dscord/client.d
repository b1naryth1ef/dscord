/**
  The top API abstraction encompassing REST, WS/Gateway, and state tracking.
*/
module dscord.client;

import std.stdio;

public import std.experimental.logger;

import std.algorithm.iteration;

import dscord.api,
       dscord.types,
       dscord.state,
       dscord.voice,
       dscord.gateway,
       dscord.util.emitter;


/**
  Struct containing configuration for Gateway sharding.
*/
struct ShardInfo {
  /** This shards number. */
  ushort shard = 0;

  /** Total number of shards. */
  ushort numShards = 1;
}

@JSONIgnore
class Client {
  /** Base log */
  Logger  log;

  /** Bot Authentication token */
  string  token;

  /** Sharding configuration */
  ShardInfo* shardInfo;

  /** APIClient instance */
  APIClient      api;

  /** GatewayClient instance */
  GatewayClient  gw;

  /** State instance */
  State  state;

  /** Mapping of voice connections */
  VoiceClient[Snowflake]  voiceConns;

  /** Emitter for gateway events */
  Emitter  events;

  this(string token, LogLevel lvl=LogLevel.all, ShardInfo* shardInfo = null) {
    this.log = new FileLogger(stdout, lvl);
    this.token = token;
    this.shardInfo = shardInfo ? shardInfo : new ShardInfo();

    this.api = new APIClient(this);
    this.gw = new GatewayClient(this);
    this.state = new State(this);
  }

  /**
    Returns the current user.
  */
  @property User me() {
    return this.state.me;
  }

  /**
    Deletes an array of message IDs for a given channel, properly bulking them
    if required.

    Params:
      channelID = the channelID all the messages originate from
      messages = the array of message IDs
  */
  void deleteMessages(Snowflake channelID, Snowflake[] messages) {
    if (messages.length <= 2) {
      messages.each!(x => this.api.channelsMessagesDelete(channelID, x));
    } else {
      this.api.channelsMessagesDeleteBulk(channelID, messages);
    }
  }

  void updateStatus(uint idleSince, Game game=null) {
    this.gw.send(new StatusUpdate(idleSince, game));
  }
}
