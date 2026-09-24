// Tests for the mini real-time frame pipeline integration project.
//
// Workflow: write the test first, run it, WATCH IT FAIL, then implement.
// Follow the suggested build order in PRACTICE_PLAN.md:
//   1. AlignedFramePool + PooledFrame, no threads - acquire/release,
//      leak-free under Valgrind.
//   2. RingBuffer, single-threaded - push N frames, pop them all, verify
//      order.
//   3. Producer/consumer threads (std::thread, condition_variable).
//   4. std::span-based processing function, in place on pool memory.
//   5. Whole thing under -fsanitize=address,undefined and Valgrind with
//      zero warnings.
//   6. Deliberately break something, confirm the tools catch it, fix it.

#include <gtest/gtest.h>

#include "aligned_frame_pool.hpp"
#include "frame_pipeline.hpp"
#include "pooled_frame.hpp"
#include "ring_buffer.hpp"

namespace
{

}  // namespace
