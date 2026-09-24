// Integration project - AlignedFramePool. See practise.md.

#pragma once

#include <cstddef>

#include "pooled_frame.hpp"

namespace cvlab::pipeline {

// TODO: a fixed set of preallocated, SIMD-aligned (alignas(32) or
// aligned_alloc) buffers. acquire() hands out a PooledFrame; release() is
// called by PooledFrame's destructor, not directly. Print each buffer
// address and verify 32-byte alignment at runtime.
class AlignedFramePool {
 public:
  AlignedFramePool(std::size_t frame_size, std::size_t capacity);
  ~AlignedFramePool();

  PooledFrame acquire();
  void release(std::byte* data);

 private:
  std::size_t frame_size_ = 0;
};

}  // namespace cvlab::pipeline
