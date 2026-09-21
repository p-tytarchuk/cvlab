# cvlab — project conventions

A C++20 monorepo for practising modern C++, model deployment and inference
frameworks. Organised by topic, driven by tests.

## Build and test

    ./scripts/build_third_party.sh      # once, and after a versions.cmake bump
    cmake --preset debug
    cmake --build --preset debug
    ctest --preset debug

Presets: `debug`, `release`, `asan`, `tsan`. Full setup, timings and
troubleshooting live in `docs/setup.md`.

Ninja is the presets' generator. Without it installed, add
`-G "Unix Makefiles"` to the configure step — a preset's generator field beats
the `CMAKE_GENERATOR` environment variable.

## TDD workflow

Tests come first. The point of this repo is to check understanding of a
topic, and a test written after the implementation mostly checks that the
code does what it already does.

1. Write the test and **watch it fail**. A test that has never failed has not
   been shown to test anything.
2. Write the minimum implementation to make it pass.
3. Refactor with the test green.

Prefer assertions on real values over assertions that something merely ran.
`common/tests/opencv_smoke_test.cpp` is the reference: it checks actual pixel
values after a resize rather than checking that `cv::resize` returned.

## Layout

    common/            shared helpers and the dependency smoke tests
    part1_modern_cpp/  memory, STL, concurrency, SDK design, performance
    part2_model_deployment/  ONNX Runtime, OpenVINO, TensorRT, SNPE/QNN
    part3_other/       OpenCV, benchmarks, mini projects
    cmake/             all build logic that is not a topic
    scripts/           developer entry points
    third_party/       pinned third-party sources and the superbuild
    docs/              setup and notes

## Adding a topic

Create a directory, add `add_subdirectory(<name>)` to the part's
`CMakeLists.txt`, and declare it:

    cvlab_add_topic(NAME smart_pointers
      SRCS    smart_pointers.cpp        # omit for a header-only topic
      TESTS   smart_pointers_test.cpp
      BENCH   smart_pointers_bench.cpp  # optional
      LIBS    opencv_core               # imported targets only
    )

Targets are prefixed `cvlab_`, so the test binary above is
`cvlab_smart_pointers_test`.

## Rules that keep the repo portable

**Third-party code only through `third_party/`.** No `find_package` of a
system library, no `FetchContent`, no vcpkg, no Conan, no brew or apt
packages. Every dependency is a pinned archive with a verified SHA256, built
locally. Adding one: `third_party/README.md`.

**No OS-specific code in topics.** No `if(APPLE)`, no `if(UNIX)`, no
`#ifdef __APPLE__` in a topic's `CMakeLists.txt`. Platform differences belong
in `cmake/`, `scripts/` or `third_party/`. A topic describes *what* it needs;
the build system decides *how* on this machine.

**Never invent a SHA256.** Download the archive, hash it, paste the result.
A wrong hash either breaks the build for everyone or, worse, pins something
nobody verified.

**Both machines, same commands.** macOS arm64 and Ubuntu x86_64 are equal
targets. Shell code must work under macOS's bash 3.2 *and* Linux's bash 5:
expand possibly-empty arrays as `${arr[@]+"${arr[@]}"}`, and remember BSD sed
lacks `\+`. CI runs both.

## Commit style

Conventional commits, imperative mood:

    feat:  a new topic or capability
    test:  tests, including the failing ones written first
    build: CMake, the superbuild, dependency versions
    ci:    GitHub Actions
    docs:  documentation
    chore: everything else
    fix:   a bug fix

Keep commits small and focused. The body explains **why**, and records what
was actually verified — "13/13 pass under asan on macOS arm64" is worth more
than "tests pass".

## Verification honesty

State what was run, on what, and what was not. This repo targets two
platforms and most local work only exercises one; say which. Do not describe
a build as working on Ubuntu when it has only been run on macOS — CI is what
settles the other platform.
