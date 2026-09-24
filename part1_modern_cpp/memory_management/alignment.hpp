// Task 7: alignment - verify and misuse it. See practise.md.

#pragma once

#include <cstddef>

namespace cvlab::memory {

// TODO: true if ptr is aligned to `alignment` bytes.
bool is_aligned(const void* ptr, std::size_t alignment);

// TODO: plain new float[count] - likely not 32-byte aligned.
float* allocate_unaligned_floats(std::size_t count);

// TODO: std::aligned_alloc(32, ...) sized for count floats.
float* allocate_aligned_floats(std::size_t count);

}  // namespace cvlab::memory
