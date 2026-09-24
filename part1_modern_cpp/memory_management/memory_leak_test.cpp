// Tests for task 5: memory leak - reproduce and catch it.
//
// Workflow: write the test first, run it, WATCH IT FAIL, then implement.
// The catch here is external tooling (Valgrind, LeakSanitizer) rather than
// a gtest assertion - record what each report said in a comment once run.

#include <gtest/gtest.h>

#include "memory_leak.hpp"

namespace {

}  // namespace
