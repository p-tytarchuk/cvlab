// Tests for the memory management topic.
//
// Workflow: write the test first, run it, WATCH IT FAIL, then implement.
// Assert on real values - a state observed, a count, a pointer that is now
// null - never merely that a call returned.

#include <gtest/gtest.h>

#include "memory_management.hpp"

namespace {

TEST(MemoryManagement, MeasureStackAndHeap) {
  const std::pair<int, int> result = cvlab::memory::measure_stack_and_heap();
  EXPECT_EQ(result.first, 0);
  EXPECT_NE(result.second, 0);
}

}  // namespace