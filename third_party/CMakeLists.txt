# Third-party superbuild.
#
# A SEPARATE CMake project from cvlab itself. It downloads pinned source
# archives, verifies their SHA256, builds each library and installs it into
# a per-platform prefix. The main project then consumes that prefix with
# find_package(... CONFIG REQUIRED).
#
# Driven by scripts/build_third_party.sh; you rarely configure it by hand.
#
#   cmake -S third_party -B third_party/build/<tag> \
#         -DCVLAB_INSTALL_PREFIX=third_party/install/<tag>
#   cmake --build third_party/build/<tag>

cmake_minimum_required(VERSION 3.24)

project(cvlab_third_party LANGUAGES C CXX)

include(ExternalProject)
include(${CMAKE_CURRENT_LIST_DIR}/versions.cmake)

# --- Configuration ----------------------------------------------------------
set(CVLAB_INSTALL_PREFIX "" CACHE PATH "Where libraries are installed")
if(NOT CVLAB_INSTALL_PREFIX)
  message(FATAL_ERROR "CVLAB_INSTALL_PREFIX is required (scripts/build_third_party.sh sets it)")
endif()

set(CVLAB_DOWNLOAD_DIR "${CMAKE_CURRENT_LIST_DIR}/downloads"
    CACHE PATH "Archive cache, shared across platforms")

# Third-party code is built Release by default: it is a dependency, not the
# subject of study, and a Debug OpenCV is both slow and large. Your own code
# is built Debug/ASan/TSan independently - see docs/setup.md for the caveats.
set(CVLAB_DEP_BUILD_TYPE "Release" CACHE STRING "Build type for dependencies")

# Which libraries to build this run. Empty means all declared ones.
set(CVLAB_ONLY "" CACHE STRING "Semicolon-separated subset of libraries to build")

# Optional mirror for corporate networks: CVLAB_MIRROR_URL=https://host/path
# is tried first, falling back to the upstream URL. Archives dropped into
# downloads/ by hand are used as-is when the hash matches.
set(CVLAB_MIRROR_URL "$ENV{CVLAB_MIRROR_URL}" CACHE STRING "Optional archive mirror base URL")

message(STATUS "third_party: install prefix  ${CVLAB_INSTALL_PREFIX}")
message(STATUS "third_party: build type      ${CVLAB_DEP_BUILD_TYPE}")
message(STATUS "third_party: downloads       ${CVLAB_DOWNLOAD_DIR}")
if(CVLAB_MIRROR_URL)
  message(STATUS "third_party: mirror          ${CVLAB_MIRROR_URL}")
endif()

# --- Helpers ----------------------------------------------------------------
# Builds the URL list for a library: mirror first (if set), then upstream.
function(cvlab_url_list out_var lib)
  string(TOUPPER "${lib}" _u)
  set(_urls "")
  if(CVLAB_MIRROR_URL)
    list(APPEND _urls "${CVLAB_MIRROR_URL}/${CVLAB_${_u}_ARCHIVE}")
  endif()
  list(APPEND _urls "${CVLAB_${_u}_URL}")
  set(${out_var} "${_urls}" PARENT_SCOPE)
endfunction()

# True when the caller asked for this library (or for everything).
function(cvlab_wants out_var lib)
  if(NOT CVLAB_ONLY)
    set(${out_var} TRUE PARENT_SCOPE)
  elseif("${lib}" IN_LIST CVLAB_ONLY)
    set(${out_var} TRUE PARENT_SCOPE)
  else()
    set(${out_var} FALSE PARENT_SCOPE)
  endif()
endfunction()

# Arguments shared by every ExternalProject_Add call.
#
# DOWNLOAD_NO_EXTRACT is off; URL_HASH makes ExternalProject verify the
# archive and re-download on mismatch, which is what "fail loudly on a bad
# archive" means in practice.
macro(cvlab_common_ep_args lib)
  string(TOUPPER "${lib}" _U)
  cvlab_url_list(_urls ${lib})

  set(_ep_common
    URL              ${_urls}
    URL_HASH         SHA256=${CVLAB_${_U}_SHA256}
    DOWNLOAD_DIR     ${CVLAB_DOWNLOAD_DIR}
    DOWNLOAD_NAME    ${CVLAB_${_U}_ARCHIVE}
    PREFIX           ${CMAKE_CURRENT_BINARY_DIR}/${lib}
    INSTALL_DIR      ${CVLAB_INSTALL_PREFIX}
    UPDATE_COMMAND   ""
    TEST_COMMAND     ""
    USES_TERMINAL_DOWNLOAD  ON
    USES_TERMINAL_CONFIGURE ON
    USES_TERMINAL_BUILD     ON
    USES_TERMINAL_INSTALL   ON
    LOG_DOWNLOAD     OFF
  )

  # Forward the host toolchain so every dependency is built by the same
  # compiler as cvlab itself; a mixed toolchain is an ABI problem waiting.
  set(_ep_toolchain
    -DCMAKE_C_COMPILER:FILEPATH=${CMAKE_C_COMPILER}
    -DCMAKE_CXX_COMPILER:FILEPATH=${CMAKE_CXX_COMPILER}
    -DCMAKE_BUILD_TYPE:STRING=${CVLAB_DEP_BUILD_TYPE}
    -DCMAKE_INSTALL_PREFIX:PATH=${CVLAB_INSTALL_PREFIX}
    -DCMAKE_POSITION_INDEPENDENT_CODE:BOOL=ON
  )
  if(CMAKE_OSX_DEPLOYMENT_TARGET)
    list(APPEND _ep_toolchain -DCMAKE_OSX_DEPLOYMENT_TARGET:STRING=${CMAKE_OSX_DEPLOYMENT_TARGET})
  endif()
  if(CMAKE_OSX_ARCHITECTURES)
    list(APPEND _ep_toolchain -DCMAKE_OSX_ARCHITECTURES:STRING=${CMAKE_OSX_ARCHITECTURES})
  endif()
endmacro()

# ---------------------------------------------------------------------------
# googletest
# ---------------------------------------------------------------------------
cvlab_wants(_build_gtest googletest)
if(_build_gtest)
  cvlab_common_ep_args(googletest)
  ExternalProject_Add(googletest
    ${_ep_common}
    CMAKE_ARGS
      ${_ep_toolchain}
      -DBUILD_SHARED_LIBS:BOOL=OFF   # static: no rpath juggling for test binaries
      -DBUILD_GMOCK:BOOL=ON          # gmock is worth having for the SDK-design topics
      -DINSTALL_GTEST:BOOL=ON
      -Dgtest_force_shared_crt:BOOL=ON
  )
endif()

# ---------------------------------------------------------------------------
# google benchmark
# ---------------------------------------------------------------------------
cvlab_wants(_build_benchmark benchmark)
if(_build_benchmark)
  cvlab_common_ep_args(benchmark)
  ExternalProject_Add(benchmark
    ${_ep_common}
    CMAKE_ARGS
      ${_ep_toolchain}
      -DBUILD_SHARED_LIBS:BOOL=OFF
      -DBENCHMARK_ENABLE_TESTING:BOOL=OFF      # BUILD_TESTING for the dep itself
      -DBENCHMARK_ENABLE_GTEST_TESTS:BOOL=OFF  # do not make benchmark depend on gtest
      -DBENCHMARK_ENABLE_INSTALL:BOOL=ON
      -DBENCHMARK_ENABLE_WERROR:BOOL=OFF       # never fail on a new compiler's warnings
      -DBENCHMARK_DOWNLOAD_DEPENDENCIES:BOOL=OFF
  )
endif()

# ---------------------------------------------------------------------------
# OpenCV - minimal, fully self-contained build
# ---------------------------------------------------------------------------
# Two rules drive this block:
#   1. Build only what is asked for (BUILD_LIST), because OpenCV is the long
#      pole of a first build.
#   2. Depend on nothing from brew/apt. Image codecs come from OpenCV's own
#      bundled zlib/libpng/libjpeg, and every other WITH_* that would probe
#      the system is explicitly OFF - several of them default to ON.
cvlab_wants(_build_opencv opencv)
if(_build_opencv)
  cvlab_common_ep_args(opencv)
  ExternalProject_Add(opencv
    ${_ep_common}
    CMAKE_ARGS
      ${_ep_toolchain}
      # Static: the prefix stays relocatable and binaries run straight from
      # the build tree with no DYLD_LIBRARY_PATH/LD_LIBRARY_PATH setup.
      -DBUILD_SHARED_LIBS:BOOL=OFF
      -DOPENCV_GENERATE_PKGCONFIG:BOOL=ON

      # Modules. Add more only when a topic needs them.
      -DBUILD_LIST:STRING=core,imgproc,imgcodecs

      # Nothing extra to build.
      -DBUILD_TESTS:BOOL=OFF
      -DBUILD_PERF_TESTS:BOOL=OFF
      -DBUILD_EXAMPLES:BOOL=OFF
      -DBUILD_DOCS:BOOL=OFF
      -DBUILD_opencv_apps:BOOL=OFF
      -DBUILD_JAVA:BOOL=OFF
      -DBUILD_FAT_JAVA_LIB:BOOL=OFF
      -DBUILD_PACKAGE:BOOL=OFF
      -DINSTALL_C_EXAMPLES:BOOL=OFF
      -DINSTALL_PYTHON_EXAMPLES:BOOL=OFF

      # No Python bindings, and do not let a stray interpreter drive the build.
      -DPYTHON_DEFAULT_EXECUTABLE:FILEPATH=
      -DBUILD_opencv_python_bindings_generator:BOOL=OFF
      -DBUILD_opencv_python_tests:BOOL=OFF

      # Bundled codecs: builds zlib/libpng/libjpeg from OpenCV's 3rdparty
      # tree so imgcodecs needs nothing from the system.
      -DBUILD_ZLIB:BOOL=ON
      -DBUILD_PNG:BOOL=ON
      -DBUILD_JPEG:BOOL=ON

      # Codecs we do not need: OFF so they cannot pick up brew/apt copies.
      # WITH_TIFF, WITH_WEBP, WITH_OPENJPEG and WITH_OPENEXR all default ON.
      -DWITH_TIFF:BOOL=OFF
      -DWITH_WEBP:BOOL=OFF
      -DWITH_OPENJPEG:BOOL=OFF
      -DWITH_JASPER:BOOL=OFF
      -DWITH_OPENEXR:BOOL=OFF
      -DWITH_IMGCODEC_HDR:BOOL=OFF
      -DWITH_IMGCODEC_SUNRASTER:BOOL=OFF
      -DWITH_IMGCODEC_PXM:BOOL=OFF
      -DWITH_IMGCODEC_PFM:BOOL=OFF

      # Video/GUI/compute backends: all OFF as specified.
      -DWITH_FFMPEG:BOOL=OFF
      -DWITH_GSTREAMER:BOOL=OFF
      -DWITH_GTK:BOOL=OFF
      -DWITH_GTK_2_X:BOOL=OFF
      -DWITH_QT:BOOL=OFF
      -DWITH_WIN32UI:BOOL=OFF
      -DWITH_OPENCL:BOOL=OFF
      -DWITH_OPENGL:BOOL=OFF
      -DWITH_CUDA:BOOL=OFF
      -DWITH_V4L:BOOL=OFF
      -DWITH_AVFOUNDATION:BOOL=OFF   # defaults ON on Apple
      -DWITH_1394:BOOL=OFF
      -DWITH_ARAVIS:BOOL=OFF
      -DWITH_GPHOTO2:BOOL=OFF

      # Optional accelerators / system libraries: OFF to keep the build
      # hermetic and reproducible across the two machines.
      -DWITH_EIGEN:BOOL=OFF          # defaults ON, probes the system
      -DWITH_LAPACK:BOOL=OFF         # defaults ON, would find Accelerate/OpenBLAS
      -DWITH_TBB:BOOL=OFF
      -DWITH_IPP:BOOL=OFF
      -DWITH_ITT:BOOL=OFF
      -DWITH_PROTOBUF:BOOL=OFF
      -DWITH_ADE:BOOL=OFF
      -DWITH_VTK:BOOL=OFF
      -DWITH_OPENVX:BOOL=OFF
      -DWITH_OBSENSOR:BOOL=OFF
      -DOPENCV_ENABLE_NONFREE:BOOL=OFF

      # Do not download anything at build time: every byte is pinned here.
      -DOPENCV_DOWNLOADER_STRICT:BOOL=ON
      -DBUILD_opencv_world:BOOL=OFF

      # Belt and braces against Homebrew/apt: ignore system prefixes entirely
      # when searching for packages.
      -DCMAKE_IGNORE_PATH:STRING=/opt/homebrew$<SEMICOLON>/opt/homebrew/bin$<SEMICOLON>/opt/homebrew/lib$<SEMICOLON>/opt/homebrew/include$<SEMICOLON>/usr/local$<SEMICOLON>/usr/local/bin$<SEMICOLON>/usr/local/lib$<SEMICOLON>/usr/local/include
      -DCMAKE_FIND_USE_SYSTEM_ENVIRONMENT_PATH:BOOL=OFF
      -DCMAKE_FIND_FRAMEWORK:STRING=NEVER
      -DCMAKE_FIND_APPBUNDLE:STRING=NEVER
  )
endif()
