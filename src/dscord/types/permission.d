module dscord.types.permission;

import std.format,
       std.algorithm.iteration;

import dscord.types;

class PermissionsError : Exception {
  Permissions perm;

  this(T...)(Permissions perm, T args) {
    this.perm = perm;
    super(format("Permission required: %s", perm));
  }
}

alias Permission = ulong;

enum Permissions : Permission {
  NONE,
  CREATE_INSTANT_INVITE = 1 << 0,
  KICK_MEMBERS = 1 << 1,
  BAN_MEMBERS = 1 << 2,
  ADMINISTRATOR = 1 << 3,
  MANAGE_CHANNELS = 1 << 4,
  MANAGE_GUILD = 1 << 5,
  READ_MESSAGES = 1 << 10,
  SEND_MESSAGES = 1 << 11,
  SEND_TSS_MESSAGES = 1 << 12,
  MANAGE_MESSAGES = 1 << 13,
  EMBED_LINKS = 1 << 14,
  ATTACH_FILES = 1 << 15,
  READ_MESSAGE_HISTORY = 1 << 16,
  MENTION_EVERYONE = 1 << 17,
  CONNECT = 1 << 20,
  SPEAK = 1 << 21,
  MUTE_MEMBERS = 1 << 22,
  DEAFEN_MEMBERS = 1 << 23,
  MOVE_MEMBERS = 1 << 24,
  USE_VAD = 1 << 25,
  CHANGE_NICKNAME = 1 << 26,
  MANAGE_NICKNAMES = 1 << 27,
  MANAGE_ROLES = 1 << 28,
}

interface IPermissible {
  Permission getPermissions(Snowflake user);
}

mixin template Permissible() {
  bool can(Snowflake user, Permission perm) {
    auto perms = this.getPermissions(user);

    return
      ((perms & Permissions.ADMINISTRATOR) == Permissions.ADMINISTRATOR) ||
      ((this.getPermissions(user) & perm) == perm);
  }

  bool can(Snowflake user, Permission[] some...) {
    return some.map!((p) => this.can(user, p)).all();
  }

  bool can(User user, Permission perm) {
    return can(user.id, perm);
  }

  bool can(User user, Permission[] some...) {
    return can(user.id, some);
  }
}
