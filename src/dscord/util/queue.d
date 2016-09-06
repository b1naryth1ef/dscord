/**
  A FIFO queue implementation.
*/
module dscord.util.queue;

import vibe.core.sync;

import std.container.dlist,
       std.array,
       core.time;

/**
  A simple Queue of type T.
*/
class Queue(T) {
  private DList!(T) data;

  /// Returns the size of the array
  private size_t _size;

  void setSize(size_t size) {
    this._size = size;
  }

  @property size_t size() {
    return this._size;
  }

  /// Returns true if the queue is empty
  @property bool empty() {
    return this.data.empty;
  }

  /// Raw array access
  @property T[] array() {
    return this.data.array;
  }

  /// Clear the entire queue
  void clear() {
    this.data.removeFront(this.size);
    this.setSize(0);
  }

  /// Push an item to the back of the queue. Returns false if the queue is full.
  bool push(T item) {
    this.data.insertBack(item);
    this.setSize(this.size + 1);
    return true;
  }

  /// Push multiple items to the back of the queue. Returns false if the queue is
  //   full.
  bool push(T[] arr) {
    this.data.insertBack(arr);
    this.setSize(this.size + 1);
    return true;
  }

  /// Pops a single item off the front of the queue. Throws an exception if the
  //   queue is empty.
  T pop() {
    if (this.data.empty) {
      throw new Exception("Cannot pop from empty Queue");
    }

    T v = this.data.front;
    this.data.removeFront();
    this.setSize(this.size - 1);
    return v;
  }

  /// Peaks at the last item in the queue.
  T peakBack() {
    if (this.data.empty) {
      throw new Exception("Cannot peak into empty Queue");
    }

    return this.data.back;
  }

  /// Peaks at the first item in the queue.
  T peakFront() {
    if (this.data.empty) {
      throw new Exception("Cannot peak into empty Queue");
    }

    return this.data.front;
  }
}

/**
  A blocking queue of type T.
*/
class BlockingQueue(T) : Queue!T {
  private ManualEvent onInsert;
  private ManualEvent onModify;

  this() {
    this.onInsert = createManualEvent();
    this.onModify = createManualEvent();
  }

  override void setSize(size_t size) {
    if (this._size < size) {
      this.onInsert.emit();
    }

    this.onModify.emit();
    this._size = size;
  }

  bool wait(Duration timeout) {
    if (this.onModify.wait(timeout, 0) != 0) {
      return false;
    }
    return true;
  }

  void wait() {
    this.onModify.wait();
  }

  T pop(Duration timeout) {
    if (this.onInsert.wait(timeout, 0) != 0) {
      return null;
    }

    return this.pop(false);
  }

  /// Pops a single item off the front of the queue. Throws an exception if the
  //   queue is empty.
  T pop(bool block=true) {
    if (this.data.empty) {
      if (block) {
        this.onInsert.wait();
      } else {
        return null;
      }
    }

    return this.pop();
  }

  override T pop() {
    T v = this.data.front;
    this.data.removeFront();
    this.setSize(this.size - 1);
    return v;
  }
}

/**
  A SizedQueue of type T.
*/
class SizedQueue(T) : Queue!T {
  /// Maximum size of the queue
  size_t     maxSize;

  this(size_t maxSize) {
    this.maxSize = maxSize;
  }

  /// True if the queue is full
  @property bool full() {
    return this.size == this.maxSize;
  }

  override bool push(T item) {
    if (this.size == this.maxSize) return false;
    return super.push(item);
  }

  override bool push(T[] arr) {
    if (arr.length + this.size > this.maxSize) return false;
    return super.push(arr);
  }
}
