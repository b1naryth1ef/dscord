module dscord.util.sharding;

import dscord.types.all;

ushort shardNumber(Snowflake id, ushort numShards) {
  return (id >> 22) % numShards;
}
