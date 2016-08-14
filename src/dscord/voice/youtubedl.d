/**
  Set of utilties for interfacing with the youtube-dl command line program.
*/

module dscord.voice.youtubedl;

import dcad.types : DCAFile, rawReadFramesFromFile;
import vibe.core.core,
       vibe.core.concurrency;

import dscord.util.process,
       dscord.types.all;

class YoutubeDL {
  /**
    Returns a VibeJSON object with information for a given URL.
  */
  static VibeJSON getInfo(string url) {
    auto proc = new Process(["youtube-dl", "-i", "-j", "--youtube-skip-dash-manifest", url]);
    assert(proc.wait() == 0, "getAssetInfo non-zero exit code");

    string buffer;

    while (!proc.stdout.eof()) {
      buffer ~= proc.stdout.readln();
    }

    return parseJsonString(buffer);
  }

  static void downloadWorker(Task parent) {
    string url = receiveOnlyCompat!string();

    auto chain = new ProcessChain().
      run(["youtube-dl", "-v", "-f", "bestaudio", "-o", "-", url]).
      run(["ffmpeg", "-i", "pipe:0", "-f", "s16le", "-ar", "48000", "-ac", "2", "pipe:1"]).
      run(["dcad"]);

    shared ubyte[][] frames = cast(shared ubyte[][])rawReadFramesFromFile(chain.end);
    parent.sendCompat(frames);
  }

  /**
    Downloads and encodes a given URL into a playable format. This function spawns
    a new worker thread to download and encode a given youtube-dl compatabile
    URL.
  */
  static DCAFile download(string url) {
    Task worker = runWorkerTaskH(&YoutubeDL.downloadWorker, Task.getThis);
    worker.sendCompat(url);

    auto frames = receiveOnlyCompat!(shared ubyte[][])();
    return new DCAFile(cast(ubyte[][])frames);
  }
}
