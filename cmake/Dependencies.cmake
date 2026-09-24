# Locates the locally built third-party prefix and imports every dependency.
#
# All third-party code enters the project HERE and nowhere else. Topics see
# only imported targets (GTest::gtest_main, opencv_core, ...).

include_guard(GLOBAL)

# --- Where the libraries were installed -------------------------------------
# scripts/build_third_party.sh installs into third_party/install/<os>-<arch>.
# The same rule is computed here so the two agree without a shared file.
# cvlab_host_tag() must match host_tag() in scripts/build_third_party.sh.
function(cvlab_host_tag out_var)
  string(TOLOWER "${CMAKE_SYSTEM_NAME}" _os)
  if(_os STREQUAL "darwin")
    set(_os macos)
  endif()

  string(TOLOWER "${CMAKE_SYSTEM_PROCESSOR}" _arch)
  if(_arch MATCHES "^(x86_64|amd64)$")
    set(_arch x86_64)
  elseif(_arch MATCHES "^(aarch64|arm64)$")
    set(_arch arm64)
  endif()

  set(${out_var} "${_os}-${_arch}" PARENT_SCOPE)
endfunction()

if(CVLAB_THIRD_PARTY_PREFIX)
  # Explicit override wins, e.g. a shared prefix on a build machine.
  set(_cvlab_prefix "${CVLAB_THIRD_PARTY_PREFIX}")
else()
  cvlab_host_tag(_cvlab_tag)
  set(_cvlab_prefix "${CMAKE_SOURCE_DIR}/third_party/install/${_cvlab_tag}")
endif()

if(NOT EXISTS "${_cvlab_prefix}")
  message(FATAL_ERROR
    "\n"
    "Third-party libraries are not built yet.\n"
    "  Expected prefix: ${_cvlab_prefix}\n"
    "\n"
    "Run ./scripts/build_third_party.sh first\n"
    "\n"
    "Override the location with -DCVLAB_THIRD_PARTY_PREFIX=/path/to/prefix\n"
  )
endif()

list(PREPEND CMAKE_PREFIX_PATH "${_cvlab_prefix}")
set(CVLAB_THIRD_PARTY_PREFIX "${_cvlab_prefix}" CACHE PATH "Local third-party install prefix" FORCE)

# Never fall back to Homebrew/apt: if something is missing we want a hard error
# naming the missing library, not a silent system pickup with a different ABI.
set(CMAKE_FIND_USE_CMAKE_SYSTEM_PATH OFF)
set(CMAKE_FIND_USE_SYSTEM_ENVIRONMENT_PATH OFF)

# --- Dependencies -----------------------------------------------------------
find_package(GTest CONFIG REQUIRED)
include(GoogleTest)

if(CVLAB_BUILD_BENCHMARKS)
  find_package(benchmark CONFIG REQUIRED)
endif()

find_package(OpenCV CONFIG REQUIRED COMPONENTS core imgproc imgcodecs)

message(STATUS "cvlab: third-party prefix ${_cvlab_prefix}")
message(STATUS "cvlab: OpenCV ${OpenCV_VERSION}")
