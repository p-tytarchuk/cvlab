// Integration project - RingBuffer<T, N>. See practise.md.

#pragma once

#include <array>
#include <cstddef>

namespace cvlab::pipeline {

// TODO: thread-safe ring buffer connecting producer to consumer, backed by
// a fixed-size std::array (stack, not heap). push/pop move T in and out -
// never copy. Get it working single-threaded first (push N, pop N, verify
// order) before adding a mutex + condition_variable for blocking push/pop.
template <typename T, std::size_t N>
class RingBuffer {
 public:
  void push(T value);
  T pop();

 private:
  std::array<T, N> buffer_{};
};

}  // namespace cvlab::pipeline
