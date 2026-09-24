# cvlab_add_topic() - the single entry point every topic uses.
#
# Topics never call find_package(), never test for an OS, and never touch
# compiler flags. They declare what they are and what they need; everything
# platform-specific lives in cmake/, scripts/ and third_party/.
#
#   cvlab_add_topic(NAME smart_pointers
#     SRCS    smart_pointers.cpp        # optional: a library of topic code
#     TESTS   smart_pointers_test.cpp   # GoogleTest sources -> one test binary
#     BENCH   smart_pointers_bench.cpp  # Google Benchmark sources -> one binary
#     LIBS    opencv_core               # imported targets to link
#   )
#
# NAME is prefixed with cvlab_ to keep target names unique across the monorepo.

include_guard(GLOBAL)

function(cvlab_add_topic)
  cmake_parse_arguments(T "" "NAME" "SRCS;TESTS;BENCH;LIBS" ${ARGN})

  if(NOT T_NAME)
    message(FATAL_ERROR "cvlab_add_topic: NAME is required")
  endif()
  if(T_UNPARSED_ARGUMENTS)
    message(FATAL_ERROR "cvlab_add_topic(${T_NAME}): unknown arguments: ${T_UNPARSED_ARGUMENTS}")
  endif()

  set(_topic cvlab_${T_NAME})

  # Optional topic library. Header-only topics simply pass no SRCS; consumers
  # still get the include directory through this INTERFACE/STATIC target.
  if(T_SRCS)
    add_library(${_topic} STATIC ${T_SRCS})
    target_include_directories(${_topic} PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
    target_link_libraries(${_topic} PUBLIC cvlab_options ${T_LIBS})
  else()
    add_library(${_topic} INTERFACE)
    target_include_directories(${_topic} INTERFACE ${CMAKE_CURRENT_SOURCE_DIR})
    target_link_libraries(${_topic} INTERFACE cvlab_options ${T_LIBS})
  endif()

  if(T_TESTS)
    if(NOT CVLAB_BUILD_TESTING)
      # Tests were requested but testing is off for this configuration.
    else()
      set(_test ${_topic}_test)
      add_executable(${_test} ${T_TESTS})
      target_link_libraries(${_test} PRIVATE ${_topic} GTest::gtest_main)
      # Discover cases at build time so ctest lists them individually; a crash
      # in one binary then names the case instead of the whole file.
      gtest_discover_tests(${_test}
        PROPERTIES LABELS ${T_NAME}
        DISCOVERY_MODE PRE_TEST
      )
    endif()
  endif()

  if(T_BENCH AND CVLAB_BUILD_BENCHMARKS)
    set(_bench ${_topic}_bench)
    add_executable(${_bench} ${T_BENCH})
    target_link_libraries(${_bench} PRIVATE ${_topic} benchmark::benchmark_main)
  endif()
endfunction()
