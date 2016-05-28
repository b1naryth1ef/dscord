module dscord.bot.plugin;

import dscord.bot.command;

class Plugin : CommandHandler {
  this(this T)() {
    this.loadCommands!T();
  }
}

