// Topic: memory management.
//
// Declare here what a test needs to name. Nothing in this header is meant to
// survive - it exists so the first test has something to fail against.

#pragma once

#include <utility>

namespace cvlab::memory {

std::pair<int, int> measure_stack_and_heap();

}  // namespace cvlab::memory
