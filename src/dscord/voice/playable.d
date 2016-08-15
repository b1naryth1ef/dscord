/**
  Implementation of types that can be played on a VoiceClient
*/
module dscord.voice.playable;

import dcad.types : DCAFile;

/**
  An interface representing a type which can be played over a VoiceClient.
*/
interface Playable {
  /// Duration of the frame in milliseconds
  const short getFrameDuration();

  /// Size of the frame in bytes
  const short getFrameSize();

  /// Returns the next frame to be played
  ubyte[] nextFrame();

  /// Returns true while there are more frames to be played
  bool hasMoreFrames();

  /// Called when the Playable begins to be played
  void start();
}

/**
  Playable implementation for DCAFiles
*/
class DCAPlayable : Playable {
  private {
    DCAFile file;

    size_t frameIndex;
  }

  this(DCAFile file) {
    this.file = file;
  }

  // TODO: Don't hardcode this
  const short getFrameDuration() {
    return 20;
  }

  const short getFrameSize() {
    return 960;
  }

  bool hasMoreFrames() {
    return this.frameIndex < this.file.frames.length;
  }

  ubyte[] nextFrame() {
    this.frameIndex++;
    return this.file.frames[this.frameIndex - 1].data;
  }

  void start() {}
}

interface PlaylistProvider {
  bool hasNext();
  Playable getNext();
}

class Playlist : Playable {
  PlaylistProvider provider;
  Playable current;

  this(PlaylistProvider provider) {
    this.provider = provider;
  }

  const short getFrameDuration() {
    return this.current.getFrameDuration();
  }

  const short getFrameSize() {
    return this.current.getFrameSize();
  }

  bool hasMoreFrames() {
    if (!this.current) return false;
    if (this.current.hasMoreFrames()) return true;
    if (this.provider.hasNext()) return true;
    return false;
  }

  ubyte[] nextFrame() {
    if (!this.current.hasMoreFrames()) {
      if (this.provider.hasNext()) {
        this.current = this.provider.getNext();
      } else{
        this.current = null;
      }
    }

    return this.current.nextFrame();
  }

  void start() {
    this.next();
  }

  void next() {
    if (this.provider.hasNext()) {
      this.current = this.provider.getNext();
    } else {
      this.current = null;
    }
  }
}

/**
  Simple Playlist provider.
*/
class SimplePlaylistProvider : PlaylistProvider {
  private {
    Playable[] playlist;
  }

  this(Playable[] playlist) {
    this.playlist = playlist;
  }

  bool hasNext() {
    return (this.playlist.length > 0);
  }

  Playable getNext() {
    assert(this.hasNext());
    Playable next = this.playlist[0];
    this.playlist = this.playlist[1..$];
    return next;
  }

  @property size_t length() {
    return this.playlist.length;
  }

  void add(Playable p) {
    this.playlist ~= p;
  }

  void empty() {
    this.playlist = [];
  }
}
