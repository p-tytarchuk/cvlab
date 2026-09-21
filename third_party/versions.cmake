# Single source of truth for every third-party library.
#
# Adding a library = one cvlab_declare_library() block here, one
# ExternalProject_Add() block in CMakeLists.txt, then find_package() +
# link in the main project. See third_party/README.md.
#
# Hashes are REAL: each archive was downloaded and hashed with
# `shasum -a 256`, then confirmed byte-identical on an independent
# re-download. Never invent or copy a hash you have not verified.
#
# To bump a version:
#   1. change VERSION and URL here
#   2. curl -L <url> -o /tmp/a.tar.gz && shasum -a 256 /tmp/a.tar.gz
#   3. paste the new SHA256
#   4. ./scripts/build_third_party.sh --clean <lib> && ./scripts/build_third_party.sh <lib>

include_guard(GLOBAL)

set(CVLAB_LIBRARIES "" CACHE INTERNAL "All declared third-party libraries")

# cvlab_declare_library(NAME <name> VERSION <v> URL <url> SHA256 <hash>)
#
# Stores the fields as CVLAB_<NAME>_{VERSION,URL,SHA256,ARCHIVE} so the
# superbuild and the build script read the same values.
function(cvlab_declare_library)
  cmake_parse_arguments(L "" "NAME;VERSION;URL;SHA256;ARCHIVE" "" ${ARGN})

  foreach(_field NAME VERSION URL SHA256)
    if(NOT L_${_field})
      message(FATAL_ERROR "cvlab_declare_library: ${_field} is required")
    endif()
  endforeach()

  # Guard against a placeholder hash reaching a build.
  string(LENGTH "${L_SHA256}" _hash_len)
  if(NOT _hash_len EQUAL 64)
    message(FATAL_ERROR
      "cvlab_declare_library(${L_NAME}): SHA256 must be 64 hex characters, got ${_hash_len}")
  endif()

  string(TOUPPER "${L_NAME}" _upper)
  if(NOT L_ARCHIVE)
    set(L_ARCHIVE "${L_NAME}-${L_VERSION}.tar.gz")
  endif()

  set(CVLAB_${_upper}_VERSION "${L_VERSION}" PARENT_SCOPE)
  set(CVLAB_${_upper}_URL     "${L_URL}"     PARENT_SCOPE)
  set(CVLAB_${_upper}_SHA256  "${L_SHA256}"  PARENT_SCOPE)
  set(CVLAB_${_upper}_ARCHIVE "${L_ARCHIVE}" PARENT_SCOPE)

  list(APPEND CVLAB_LIBRARIES "${L_NAME}")
  set(CVLAB_LIBRARIES "${CVLAB_LIBRARIES}" CACHE INTERNAL "All declared third-party libraries")
endfunction()

# ---------------------------------------------------------------------------
# Default libraries (built by scripts/build_third_party.sh with no arguments)
# ---------------------------------------------------------------------------

# Test framework. v1.18.0 requires C++17 or newer, which suits a C++20 project.
cvlab_declare_library(
  NAME    googletest
  VERSION 1.18.0
  URL     https://github.com/google/googletest/archive/refs/tags/v1.18.0.tar.gz
  SHA256  6e3191c1455468b3fc35a417fb565c1c5071aee1b7e7f85e30cf48a98d37d8b5
)

# Microbenchmarks.
cvlab_declare_library(
  NAME    benchmark
  VERSION 1.9.5
  URL     https://github.com/google/benchmark/archive/refs/tags/v1.9.5.tar.gz
  SHA256  9631341c82bac4a288bef951f8b26b41f69021794184ece969f8473977eaa340
)

# Computer vision. Deliberately the 4.x line, not 5.x: OpenCV 5 is a major
# release with breaking API changes, while essentially all tutorials and
# inference-framework integrations still assume 4.x. Bump when you want to
# study the migration, not by default.
cvlab_declare_library(
  NAME    opencv
  VERSION 4.14.0
  URL     https://github.com/opencv/opencv/archive/refs/tags/4.14.0.tar.gz
  SHA256  ee8fb9b30eb60850431b4656447080e3737b56e45719c92b67f245950609f86e
)

# ---------------------------------------------------------------------------
# Optional libraries (OFF by default; see docs/setup.md)
# ---------------------------------------------------------------------------
# ONNX Runtime and OpenVINO will be declared here and BUILT FROM SOURCE,
# pinned by URL + SHA256 like everything else: hermetic, toolchain-matched,
# sanitizer-friendly, and arm64-capable (Intel ships no official OpenVINO
# prebuilt for Apple Silicon). Both are long builds - see docs/setup.md.
#
# TensorRT is never declared here: it cannot be downloaded automatically and
# stays an optional system dependency found via find_package() on Linux +
# NVIDIA only.
