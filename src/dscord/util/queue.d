module dscord.util.queue;

import std.container.dlist,
       std.array;

class SizedQueue(T) {
  DList!(T)  data;
  size_t     maxSize;
  size_t     size;

  this(size_t maxSize) {
    this.maxSize = maxSize;
  }

  @property bool full() {
    return this.size == this.maxSize;
  }

  @property bool empty() {
    return this.size == 0 && this.data.empty;
  }

  @property T[] array() {
    return this.data.array;
  }

  void clear() {
    this.data.removeFront(this.size);
    this.size = 0;
  }

  bool push(T item) {
    if (this.size == this.maxSize) return false;
    this.size++;
    this.data.insertBack(item);
    return true;
  }

  bool push(T[] arr) {
    if (arr.length + this.size > this.maxSize) return false;
    this.size += arr.length;
    this.data.insertBack(arr);
    return true;
  }

  T pop() {
    if (this.data.empty) {
      throw new Exception("Cannot pop from empty SizedQueue");
    }

    this.size--;
    T v = this.data.front;
    this.data.removeFront();
    return v;
  }


  T peakBack() {
    if (this.data.empty) {
      throw new Exception("Cannot peak into empty SizedQueue");
    }

    return this.data.back;
  }

  T peakFront() {
    if (this.data.empty) {
      throw new Exception("Cannot peak into empty SizedQueue");
    }

    return this.data.front;
  }
}
