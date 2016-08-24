/**
  Utilties related to Discord Guild sharding.
*/
module dscord.util.sharding;

import dscord.types;

/// Returns the shard number a given snowflake is on (given the number of shards)
ushort shardNumber(Snowflake id, ushort numShards) {
  return (id >> 22) % numShards;
}
