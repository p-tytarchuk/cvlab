# Topic: mini real-time frame pipeline - the integration project that ties
# together every memory_management warm-up task (pools, alignment, RAII,
# move semantics, forwarding, zero-copy std::span processing, and debugging
# an intentionally introduced bug under ASan/Valgrind). See practise.md.
#
# ring_buffer.hpp and the create<> helper in frame_pipeline.hpp are
# header-only (templates) and contribute no .cpp.
cvlab_add_topic(NAME mini_frame_pipeline
  SRCS  aligned_frame_pool.cpp
        pooled_frame.cpp
        frame_pipeline.cpp
  TESTS mini_frame_pipeline_test.cpp
)
