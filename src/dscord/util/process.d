/**
  Includes a utility class for unix-pipe chaining of system processes.
*/
module dscord.util.process;

import std.algorithm.iteration,
       std.array;

static import std.stdio,
              std.process;

/**
  Represents a single running process in the chain.
*/
struct Process {
  std.process.Pid pid;
  std.process.Pipe pipe;

  /**
   Creates a new process (and spawns it).

    Params:
      args = args for the process
      upstream = file object used as stdin for the process
  */
  this(string[] args, std.stdio.File upstream) {
    this.pipe = std.process.pipe();
    this.pid = std.process.spawnProcess(args, upstream, this.pipe.writeEnd);
  }

  /**
    Creates a new process (and spawns it)

    Params:
      args = args for the process
  */
  this(string[] args) {
    this(args, std.stdio.stdin);
  }

  /// Waits for this process to complete and returns the exit code.
  int wait() {
    return std.process.wait(this.pid);
  }

  /// File object of this processes stdout
  @property std.stdio.File stdout() {
    return this.pipe.readEnd;
  }
}

/**
  Represents a chain of processes with each member piping its stdout into the
  next members stdin.
*/
class ProcessChain {
  Process*[] members;

  /// Adds a new process in the chain.
  ProcessChain run(string[] args) {
    members ~= new Process(args,
      this.members.length ? this.members[$-1].pipe.readEnd : std.stdio.stdin);
    return this;
  }

  /// Waits for all processes in the chain to exit and returns an array of exit codes.
  int[] wait() {
    assert(this.members.length);
    return this.members.map!((p) => p.wait()).array;
  }

  /// Returns stdout for the last process in the chain.
  std.stdio.File end() {
    assert(this.members.length);
    return this.members[$-1].pipe.readEnd;
  }
}
