# Setup

cvlab builds on macOS (Apple Silicon) and Ubuntu 22.04/24.04 with the same
commands. Everything except the toolchain is built from pinned source inside
the repository.

## One-line build

    ./scripts/build_third_party.sh && cmake --preset debug && cmake --build --preset debug && ctest --preset debug

## Prerequisites

Only a toolchain is needed. The build script checks for these and, if one is
missing, prints the exact install command — it never runs `sudo` itself.

### macOS

    xcode-select --install          # Apple Clang, git, make
    brew install cmake ninja

Ninja is what the presets use, so install it: `cmake --preset debug` then
works with no extra flags. Without it the build script falls back to
`Unix Makefiles` and warns, and you must pass `-G "Unix Makefiles"` to
`cmake --preset` yourself, because a preset's generator field otherwise wins.

Installing Ninja after a first build with Make is handled: the script notices
the generator changed and resets the third-party build tree. Installed
libraries and cached downloads are kept, so only the build tree is redone.

### Ubuntu

    sudo apt-get update
    sudo apt-get install -y build-essential cmake ninja-build git curl pkg-config

Ubuntu 22.04 ships CMake 3.22, which is **too old** — cvlab needs >= 3.24.
Either use the Kitware APT repository or install a newer CMake another way;
the script fails with a clear message and the version it found.

## First build: what to expect

Measured on an M-series Mac (14 cores, Ninja, archives already downloaded):

| Step                              | Ninja     | Unix Makefiles |
| --------------------------------- | --------- | -------------- |
| googletest                        | ~3 s      | ~5 s           |
| google benchmark                  | ~6 s      | ~6 s           |
| OpenCV (core, imgproc, imgcodecs) | ~37 s     | ~42 s          |
| **Total third-party**             | **~46 s** | **~53 s**      |
| cvlab configure + build + test    | ~2 s      | ~2 s           |

Add a one-time download of roughly 100 MB, almost all of it OpenCV.

OpenCV is fast here only because the build is deliberately minimal
(`BUILD_LIST=core,imgproc,imgcodecs`). A full OpenCV build with every module
takes tens of minutes; adding modules will move this number a lot. With Ninja
and more cores, expect faster. On a CI runner with fewer cores, expect
several minutes — which is why CI caches the install prefix.

**You only pay this once.** The dependency build and cvlab's own build are
separate CMake projects, so `rm -rf build/` rebuilds only your code (~2 s).

## Day-to-day

    cmake --preset debug            # configure
    cmake --build --preset debug    # build
    ctest --preset debug            # run tests

Presets: `debug`, `release`, `asan`, `tsan`.

Useful variations:

    ctest --preset debug -R OpenCV          # only matching tests
    ctest --preset debug --output-on-failure
    cmake --build --preset debug -j 8

### Build script options

    ./scripts/build_third_party.sh                 # default set
    ./scripts/build_third_party.sh gtest opencv    # only these
    ./scripts/build_third_party.sh --clean opencv  # rebuild one library
    ./scripts/build_third_party.sh --debug         # separate Debug prefix
    ./scripts/build_third_party.sh --jobs 4

`--clean` removes only generated trees: the build tree, the installed files
and the stamp for the chosen libraries. It never deletes your sources, and it
never deletes `third_party/downloads/`, so a clean rebuild does not
re-download anything.

## Sanitizers, build types and ABI

Third-party libraries are built **Release** regardless of how cvlab is built.
They are tools, not the subject of study, and a Debug OpenCV is slow and
large. A few consequences worth understanding.

### ASan — works, with a caveat

ASan does not require every object to be instrumented, so an uninstrumented
Release OpenCV is fine: a bug in *your* code is still caught with a precise
report. What you lose is detail inside OpenCV frames — a stack trace through
OpenCV shows less than it would for instrumented code.

OpenCV's static initialisers allocate memory that is never freed. These are
benign one-time allocations, not leaks in your code, so CI runs ASan with
`detect_leaks=0`. When hunting a leak in your own code, turn it back on:

    ASAN_OPTIONS=detect_leaks=1 ctest --preset asan

### TSan — read this before trusting it

TSan is different from ASan in a way that matters. It needs **all** code
participating in a data race to be instrumented to reason correctly. With an
uninstrumented OpenCV:

- **False negatives.** A race between your thread and a thread inside OpenCV
  can go unreported: TSan cannot see OpenCV's synchronisation.
- **False positives.** OpenCV's internal threading can look like unsynchronised
  access when TSan cannot see the locks involved.

So: **TSan is for cvlab's own threading code** — the concurrency topics, where
your code is instrumented and OpenCV is not in the picture. Do not conclude
from a clean TSan run that an OpenCV-using pipeline is race-free.

If you ever need it properly, rebuild the dependency instrumented into a
separate prefix:

    CXXFLAGS="-fsanitize=thread" ./scripts/build_third_party.sh --clean --debug opencv
    cmake --preset tsan -DCVLAB_THIRD_PARTY_PREFIX=third_party/install/<tag>-debug

### Static linking and ABI

Everything is built static (`BUILD_SHARED_LIBS=OFF`) and with
`CMAKE_POSITION_INDEPENDENT_CODE=ON`. Static linking keeps the prefix
relocatable: binaries run straight from the build tree with no
`DYLD_LIBRARY_PATH` or `LD_LIBRARY_PATH` setup, and CI caching stays simple.

The superbuild forwards `CMAKE_C_COMPILER`/`CMAKE_CXX_COMPILER` to every
dependency, so all of it is built by the same compiler as cvlab. Mixing
toolchains — a libstdc++ OpenCV against a libc++ cvlab, for instance — is an
ABI mismatch that usually appears as link errors about `std::__1::` symbols.
If you switch compilers, rebuild the dependencies:

    ./scripts/build_third_party.sh --clean

## Troubleshooting

**`Run ./scripts/build_third_party.sh first`**
Configure found no install prefix. Run the script. If your prefix lives
elsewhere, pass `-DCVLAB_THIRD_PARTY_PREFIX=/path/to/prefix`.

**`cmake X.Y is too old; cvlab needs >= 3.24`**
Most likely Ubuntu 22.04's CMake 3.22. Install a newer one; see Prerequisites.

**`CMake was unable to find a build program corresponding to "Ninja"`**
The presets ask for Ninja. Install it (`brew install ninja`,
`sudo apt-get install ninja-build`), or override per invocation:

    cmake --preset debug -G "Unix Makefiles"

A preset's `generator` field beats the `CMAKE_GENERATOR` environment
variable, so `-G` on the command line is the way to override it.

**`Does not match the generator used previously`**
The third-party build tree was configured with a different generator — most
often because you installed Ninja after a first build with Make. The build
script detects this and resets the tree itself, so just re-run it. If you hit
it in cvlab's own `build/` instead, `rm -rf build/` and reconfigure.

**A SHA256 mismatch**
See "Hash mismatches" in `third_party/README.md`. Delete the archive from
`third_party/downloads/` and re-run; if it persists, upstream may have
regenerated the archive. Never disable the check.

**OpenCV picked up a Homebrew or apt library**
It should not: the superbuild disables every `WITH_*` that probes the system
and sets `CMAKE_IGNORE_PATH` for `/opt/homebrew` and `/usr/local`. Verify
with:

    grep -E "(ZLib|JPEG|PNG):" third_party/build/<tag>/opencv-build.log

Each should read `build` (or `build-libjpeg-turbo`), never a system path. If
one does not, open an issue against the superbuild block rather than working
around it locally.

**Tests pass in debug but fail under asan**
That is ASan doing its job — a real bug in your code that Debug did not
expose. Read the report; it names the file and line.

**Link errors mentioning `std::__1::` or `__cxx11`**
An ABI mismatch between the dependencies and cvlab; see "Static linking and
ABI" above. Rebuild with `./scripts/build_third_party.sh --clean`.

## Optional inference backends

`CVLAB_WITH_ONNXRUNTIME`, `CVLAB_WITH_OPENVINO` and `CVLAB_WITH_TENSORRT` are
**OFF by default** and not yet implemented.

- **ONNX Runtime / OpenVINO** — both will be **built from source**, pinned by
  URL and SHA256 like every other dependency. This keeps the build fully
  hermetic and matches your toolchain, so both work under sanitizers and on
  arm64 (Intel ships no official OpenVINO prebuilt for Apple Silicon).
  The cost is a long first build — expect tens of minutes for ONNX Runtime
  and over an hour for OpenVINO, each pulling a large dependency tree. CI
  caches the install prefix, so that cost is paid once per version bump.
- **TensorRT / CUDA** — cannot be downloaded or built automatically. It stays
  an optional *system* dependency found with `find_package`, guarded to Linux
  with an NVIDIA GPU.

## Adding a library

See "Adding a library" in `third_party/README.md`: one entry in
`versions.cmake`, about ten lines in the superbuild, one `find_package`, then
link it from a topic through `LIBS`.
