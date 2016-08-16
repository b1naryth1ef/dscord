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
  static void infoWorker(Task parent, string url) {
    auto proc = new Process(["youtube-dl", "-i", "-j", "--youtube-skip-dash-manifest", url]);

    shared string[] lines;
    while (!proc.stdout.eof()) {
      parent.sendCompat(proc.stdout.readln());
    }

    parent.sendCompat(null);

    // Let the process terminate
    proc.wait();
  }

  /**
    Loads songs from a given youtube-dl compatible URL, calling a delegate with
    each song. This function is useful for downloading large playlists where
    waiting for all the songs to be processed takes a long time. When downloading
    is completed, the delegate `complete` will be called with the total number of
    songs downloaded/pasred.

    Params:
      url = url of playlist or song to download
      cb = delegate taking a VibeJSON object for each song downloaded from the URL.
      complete = delegate taking a size_t, called when completed (with the total
        number of downloaded songs)
  */
  static void getInfoAsync(string url, void delegate(VibeJSON) cb, void delegate(size_t) complete=null) {
    Task worker = runWorkerTaskH(&YoutubeDL.infoWorker, Task.getThis, url);

    size_t count = 0;
    while (true) {
      try {
        string line = receiveOnlyCompat!(string);
        runTask(cb, parseJsonString(line));
        count += 1;
      } catch (MessageMismatch e) {
        break;
      } catch (Exception e) {}
    }

    if (complete) complete(count);
  }

  /**
    Returns a VibeJSON object with information for a given URL.
  */
  static VibeJSON[] getInfo(string url) {
    VibeJSON[] result;

    Task worker = runWorkerTaskH(&YoutubeDL.infoWorker, Task.getThis, url);

    while (true) {
      try {
        string line = receiveOnlyCompat!(string);
        result ~= parseJsonString(line);
      } catch (MessageMismatch e) {
        break;
      } catch (Exception e) {}
    }

    return result;
  }

  static void downloadWorker(Task parent, string url) {
    auto chain = new ProcessChain().
      run(["youtube-dl", "-v", "-f", "bestaudio", "-o", "-", url]).
      run(["ffmpeg", "-i", "pipe:0", "-f", "s16le", "-ar", "48000", "-ac", "2", "pipe:1", "-vol", "100"]).
      run(["dcad"]);

    shared ubyte[][] frames = cast(shared ubyte[][])rawReadFramesFromFile(chain.end);
    parent.sendCompat(frames);

    // Let the process terminate
    chain.wait();
  }

  /**
    Downloads and encodes a given URL into a playable format. This function spawns
    a new worker thread to download and encode a given youtube-dl compatabile
    URL.
  */
  static DCAFile download(string url) {
    Task worker = runWorkerTaskH(&YoutubeDL.downloadWorker, Task.getThis, url);
    auto frames = receiveOnlyCompat!(shared ubyte[][])();
    return new DCAFile(cast(ubyte[][])frames);
  }
}
