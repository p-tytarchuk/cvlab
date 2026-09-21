# cvlab

A hands-on C++20 learning lab, built as one monorepo and organized by topic.

Each topic (memory management, STL and language features, multithreading,
model inference, and more) is a small self-contained module with its own
tests. I write the tests first (TDD) to check that I understand the topic,
then write the implementation.

## What's inside
- **Modern C++**: memory management, STL and language features, concurrency
- **Model deployment and inference frameworks**: ONNX Runtime, OpenVINO, TensorRT
- **Other topics**: computer vision with OpenCV, benchmarks, mini projects

## Highlights
- TDD with GoogleTest and Google Benchmark
- Sanitizers (ASan, UBSan, TSan) built in as CMake presets
- Third-party libraries downloaded as source, pinned by version and SHA256,
  and built locally (no system packages needed)
- Works on Ubuntu and macOS (Apple Silicon)
- VS Code ready (CMake Tools, clangd, CodeLLDB)

## Quick start
    ./scripts/build_third_party.sh
    cmake --preset debug
    cmake --build --preset debug
    ctest --preset debug
