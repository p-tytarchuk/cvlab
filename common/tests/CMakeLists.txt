# Smoke tests: each proves one dependency genuinely works, so that a failure
# in a topic is never ambiguous between "my code is wrong" and "my toolchain
# is wrong". They are deliberately the first thing that must pass.

if(NOT CVLAB_BUILD_TESTING)
  return()
endif()

add_executable(cvlab_gtest_smoke_test gtest_smoke_test.cpp)
target_link_libraries(cvlab_gtest_smoke_test PRIVATE cvlab_options GTest::gtest_main)
gtest_discover_tests(cvlab_gtest_smoke_test
  PROPERTIES LABELS smoke
  DISCOVERY_MODE PRE_TEST
)

add_executable(cvlab_opencv_smoke_test opencv_smoke_test.cpp)
target_link_libraries(cvlab_opencv_smoke_test
  PRIVATE cvlab_options GTest::gtest_main
          opencv_core opencv_imgproc opencv_imgcodecs
)
gtest_discover_tests(cvlab_opencv_smoke_test
  PROPERTIES LABELS smoke
  DISCOVERY_MODE PRE_TEST
)

if(CVLAB_BUILD_BENCHMARKS)
  add_executable(cvlab_benchmark_smoke_test benchmark_smoke_test.cpp)
  # benchmark::benchmark (not benchmark_main): gtest_main provides main().
  target_link_libraries(cvlab_benchmark_smoke_test
    PRIVATE cvlab_options GTest::gtest_main benchmark::benchmark
  )
  gtest_discover_tests(cvlab_benchmark_smoke_test
    PROPERTIES LABELS smoke
    DISCOVERY_MODE PRE_TEST
  )
endif()
