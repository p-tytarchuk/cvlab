// Integration project - PooledFrame. See practise.md.

#pragma once

#include <cstddef>

namespace cvlab::pipeline {

class AlignedFramePool;

// TODO: move-only RAII handle that returns its buffer to the
// AlignedFramePool it came from on destruction.
class PooledFrame {
 public:
  PooledFrame() = default;
  ~PooledFrame();

  PooledFrame(const PooledFrame&) = delete;
  PooledFrame& operator=(const PooledFrame&) = delete;

  PooledFrame(PooledFrame&& other) noexcept;
  PooledFrame& operator=(PooledFrame&& other) noexcept;

  std::byte* data() const;
  std::size_t size() const;

 private:
  friend class AlignedFramePool;
  PooledFrame(AlignedFramePool& pool, std::byte* data, std::size_t size);

  AlignedFramePool* pool_ = nullptr;
  std::byte* data_ = nullptr;
  std::size_t size_ = 0;
};

}  // namespace cvlab::pipeline
