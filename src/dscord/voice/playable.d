module dscord.voice.playable;

import dcad.types : DCAFile;

interface Playable {
  const short getFrameDuration();
  const short getFrameSize();
  ubyte[] nextFrame();
  bool hasMoreFrames();
  void start();
}

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

class DCAPlaylist : Playable {
  private {
    DCAPlayable[]  playlist;
    DCAPlayable    current;
  }

  this(DCAPlayable[] playlist) {
    this.playlist = playlist;
  }

  void add(DCAPlayable p) {
    this.playlist ~= p;
  }

  @property size_t length() {
    return this.playlist.length;
  }

  const short getFrameDuration() {
    return 20;
  }

  const short getFrameSize() {
    return 960;
  }

  bool hasMoreFrames() {
    if (!this.current) return false;
    if (this.current.hasMoreFrames()) return true;
    if (this.playlist.length) return true;
    return false;
  }

  ubyte[] nextFrame() {
    if (!this.current.hasMoreFrames()) {
      if (this.playlist.length) {
        this.next();
      }
    }

    return this.current.nextFrame();
  }

  void next() {
    if (!this.playlist.length) {
      this.current = null;
      return;
    }

    this.current = this.playlist[0];
    if (this.playlist.length > 1) {
      this.playlist = this.playlist[1..$];
    } else {
      this.playlist = [];
    }
  }

  void start() {
    if (this.playlist.length) {
      this.next();
    }
  }
}
