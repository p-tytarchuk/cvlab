#include "memory_management.hpp"

#include <chrono>
#include <cstddef>
#include <cstdlib>
#include <iostream>

// Counts calls through the global new/delete so the test can assert on an
// actual allocation count rather than trusting that a loop "ran".
inline std::size_t g_alloc_count = 0;

void* operator new(std::size_t size) {
  ++g_alloc_count;
  return std::malloc(size);
}
void operator delete(void* p) noexcept { std::free(p); }

namespace cvlab::memory {

std::pair<int, int> measure_stack_and_heap() {
  const int max_elements = 256;
  const int max_iteration = 10000000;

  const auto before = g_alloc_count;
  const auto stack_start = std::chrono::steady_clock::now();

  for (int i = 0; i < max_iteration; ++i) {
    int st[max_elements];
    const int index = (i >= max_elements) ? 0 : i;
    st[index] = i;
  }

  const auto after_stack = g_alloc_count;
  const auto stack_elapsed =
      std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now() - stack_start);

  const auto heap_start = std::chrono::steady_clock::now();

  for (int i = 0; i < max_iteration; ++i) {
    int* hp = new int[max_elements];
    const int index = (i >= max_elements) ? 0 : i;
    hp[index] = i;
    delete[] hp;
  }

  const auto after_heap = g_alloc_count;
  const auto heap_elapsed =
      std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now() - heap_start);

  // Stack allocation is just moving the stack pointer, an O(1) instruction
  // with no bookkeeping; heap allocation walks a general-purpose allocator's
  // free list/metadata, so it is dramatically slower per call. std::cerr is
  // the record of that here since the return value is allocation counts, not
  // timings.
  std::cerr << "stack: " << stack_elapsed.count() << " ms, heap: " << heap_elapsed.count() << " ms\n";

  return {after_stack - before, after_heap - after_stack};
}

}  // namespace cvlab::memory
