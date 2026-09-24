// Tests for task 4: dangling pointer / use-after-free.
//
// Workflow: write the test first, run it, WATCH IT FAIL, then implement.
// This topic is best exercised by deliberately triggering the bug under
// -fsanitize=address and reading the report, rather than asserting on a
// value - note the ASan-blamed line in a comment once reproduced.

#include <gtest/gtest.h>

#include "dangling_uaf.hpp"

namespace {

}  // namespace
