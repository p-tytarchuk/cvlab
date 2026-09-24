// Task 6: memory pool - build the free-list pool. See practise.md.

#pragma once

#include <cstddef>

namespace cvlab::memory {

class FramePool;

// TODO: a move-only RAII handle over a slot borrowed from a FramePool,
// returning it to the pool's free list on destruction.
class PooledFrame {
 public:
  PooledFrame(FramePool& pool, void* data);
  ~PooledFrame();

  PooledFrame(const PooledFrame&) = delete;
  PooledFrame& operator=(const PooledFrame&) = delete;

  PooledFrame(PooledFrame&& other) noexcept;
  PooledFrame& operator=(PooledFrame&& other) noexcept;

  void* data() const;

 private:
  FramePool* pool_ = nullptr;
  void* data_ = nullptr;
};

// TODO: a fixed-size free-list pool of frame_size-byte slots. acquire()
// hands out a PooledFrame; release() is called by PooledFrame's destructor,
// not directly.
class FramePool {
 public:
  FramePool(std::size_t frame_size, std::size_t capacity);
  ~FramePool();

  PooledFrame acquire();
  void release(void* data);

 private:
  std::size_t frame_size_ = 0;
};

}  // namespace cvlab::memory
