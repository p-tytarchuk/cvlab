// Task 2: move semantics - Buffer class. See practise.md.

#pragma once

#include <cstddef>

namespace cvlab::memory {

// TODO: wrap a raw int*. Print a message from each special member below so
// the call sequence is visible when several are pushed into a
// std::vector<Buffer> and it reallocates.
class Buffer {
 public:
  explicit Buffer(std::size_t size);
  ~Buffer();

  Buffer(const Buffer& other);
  Buffer(Buffer&& other) noexcept;

  Buffer& operator=(const Buffer& other);
  Buffer& operator=(Buffer&& other) noexcept;

 private:
  int* data_ = nullptr;
  std::size_t size_ = 0;
};

}  // namespace cvlab::memory
