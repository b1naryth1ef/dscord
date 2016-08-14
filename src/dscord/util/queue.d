/**
  A FIFO queue implementation.
*/
module dscord.util.queue;

import std.container.dlist,
       std.array;

/**
  A SizedQueue of type T.
*/
class SizedQueue(T) {
  private {
    DList!(T)  data;
  }

  /// Maximum size of the queue
  size_t     maxSize;

  /// Current size of the queu
  size_t     size;

  this(size_t maxSize) {
    this.maxSize = maxSize;
  }

  /// True if the queue is full
  @property bool full() {
    return this.size == this.maxSize;
  }

  /// True if the queue is empty
  @property bool empty() {
    return this.size == 0 && this.data.empty;
  }

  /// Raw queue array (ordered properly)
  @property T[] array() {
    return this.data.array;
  }

  /// Clear the entire queue
  void clear() {
    this.data.removeFront(this.size);
    this.size = 0;
  }

  /// Push an item to the back of the queue. Returns false if the queue is full.
  bool push(T item) {
    if (this.size == this.maxSize) return false;
    this.size++;
    this.data.insertBack(item);
    return true;
  }

  /// Push multiple items to the back of the queue. Returns false if the queue is
  //   full.
  bool push(T[] arr) {
    if (arr.length + this.size > this.maxSize) return false;
    this.size += arr.length;
    this.data.insertBack(arr);
    return true;
  }

  /// Pops a single item off the front of the queue. Throws an exception if the
  //   queue is empty.
  T pop() {
    if (this.data.empty) {
      throw new Exception("Cannot pop from empty SizedQueue");
    }

    this.size--;
    T v = this.data.front;
    this.data.removeFront();
    return v;
  }


  /// Peaks at the last item in the queue.
  T peakBack() {
    if (this.data.empty) {
      throw new Exception("Cannot peak into empty SizedQueue");
    }

    return this.data.back;
  }

  /// Peaks at the first item in the queue.
  T peakFront() {
    if (this.data.empty) {
      throw new Exception("Cannot peak into empty SizedQueue");
    }

    return this.data.front;
  }
}
