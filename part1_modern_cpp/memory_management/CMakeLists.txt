# Topic: memory management - ownership, lifetime, smart pointers, allocation.
#
# One warm-up task per file pair; see practise.md for the full progression.
# forwarding_factory.hpp is header-only (a template) and contributes no .cpp.
cvlab_add_topic(NAME memory_management
  SRCS  memory_management.cpp
        buffer.cpp
        dangling_uaf.cpp
        memory_leak.cpp
        frame_pool.cpp
        alignment.cpp
  TESTS memory_management_test.cpp
        buffer_test.cpp
        forwarding_factory_test.cpp
        dangling_uaf_test.cpp
        memory_leak_test.cpp
        frame_pool_test.cpp
        alignment_test.cpp
  BENCH frame_pool_bench.cpp
)
