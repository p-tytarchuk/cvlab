cmake_minimum_required(VERSION 3.24)

project(cvlab
  VERSION 0.1.0
  DESCRIPTION "A hands-on C++20 learning lab"
  LANGUAGES CXX
)

list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/cmake)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)          # -std=c++20, never -std=gnu++20
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)  # for clangd

option(CVLAB_BUILD_TESTING    "Build the tests"      ON)
option(CVLAB_BUILD_BENCHMARKS "Build the benchmarks" ON)

# Optional inference backends. OFF by default: see docs/setup.md.
option(CVLAB_WITH_ONNXRUNTIME "Enable ONNX Runtime backend" OFF)
option(CVLAB_WITH_OPENVINO    "Enable OpenVINO backend"     OFF)
option(CVLAB_WITH_TENSORRT    "Enable TensorRT backend"     OFF)

# --- Common compile options -------------------------------------------------
# Every cvlab target links this; third-party code deliberately does not, so a
# warning-clean build never depends on someone else's headers.
add_library(cvlab_options INTERFACE)
target_compile_options(cvlab_options INTERFACE
  -Wall -Wextra -Wpedantic
  -Wshadow -Wconversion -Wsign-conversion
  -Wnon-virtual-dtor -Woverloaded-virtual
)

if(CVLAB_BUILD_TESTING)
  enable_testing()
endif()

include(Dependencies)
include(CvlabTopic)

add_subdirectory(common)
add_subdirectory(part1_modern_cpp)
add_subdirectory(part2_model_deployment)
add_subdirectory(part3_other)
