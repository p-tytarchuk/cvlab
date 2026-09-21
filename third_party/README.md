# third_party

Every third-party library cvlab uses is downloaded as a **pinned source
archive**, verified against a **SHA256**, built locally and installed into a
per-platform prefix inside this directory. Nothing comes from Homebrew, apt,
vcpkg or Conan — only the basic toolchain (compiler, CMake, git) is expected
on the machine.

## Layout

    third_party/
      README.md              this file
      versions.cmake         single source of truth: name, version, URL, SHA256
      CMakeLists.txt         superbuild (ExternalProject_Add per library)
      downloads/             cached source archives          (gitignored)
      build/<os>-<arch>/     build trees                     (gitignored)
      install/<os>-<arch>/   installed headers and libraries (gitignored)

`<os>-<arch>` is e.g. `macos-arm64` or `linux-x86_64`. The tag is computed in
two places that must agree: `host_tag` logic in
`scripts/build_third_party.sh` and `cvlab_host_tag()` in
`cmake/Dependencies.cmake`.

A `--debug` build installs into `<os>-<arch>-debug` instead, so Release and
Debug dependencies never overwrite each other.

## How it works

1. `scripts/build_third_party.sh` detects the host, checks prerequisites and
   configures **this directory as its own CMake project** — separate from
   cvlab itself.
2. The superbuild declares one `ExternalProject_Add` per library, with
   `URL` + `URL_HASH SHA256=...`. CMake downloads the archive into
   `downloads/`, verifies the hash, then configures, builds and installs it
   into `install/<tag>/`.
3. The main project's `cmake/Dependencies.cmake` puts that prefix on
   `CMAKE_PREFIX_PATH` and calls `find_package(... CONFIG REQUIRED)`.

Because the two projects are separate, deleting cvlab's `build/` never
rebuilds a dependency.

### Idempotence

After installing a library the script writes
`install/<tag>/.cvlab-stamp-<lib>` containing the version it built. A later
run compares that stamp against the pinned version in `versions.cmake` and
skips the library when they match. Bumping a version in `versions.cmake`
therefore forces exactly that library to rebuild.

## Adding a library

Three small edits:

**1. Pin it in `versions.cmake`.** Download the archive, hash it, paste it:

    curl -L <url> -o /tmp/archive.tar.gz
    shasum -a 256 /tmp/archive.tar.gz        # macOS
    sha256sum   /tmp/archive.tar.gz          # Linux

    cvlab_declare_library(
      NAME    fmt
      VERSION 11.0.2
      URL     https://github.com/fmtlib/fmt/archive/refs/tags/11.0.2.tar.gz
      SHA256  <the hash you just computed>
    )

Never invent or copy an unverified hash. `cvlab_declare_library()` rejects
anything that is not 64 hex characters, but it cannot tell a wrong hash from
a right one.

**2. Add a block to `CMakeLists.txt`** (about ten lines):

    cvlab_wants(_build_fmt fmt)
    if(_build_fmt)
      cvlab_common_ep_args(fmt)
      ExternalProject_Add(fmt
        ${_ep_common}
        CMAKE_ARGS
          ${_ep_toolchain}
          -DBUILD_SHARED_LIBS:BOOL=OFF
          -DFMT_TEST:BOOL=OFF
      )
    endif()

`${_ep_common}` carries the URL, hash, download dir and install dir;
`${_ep_toolchain}` forwards the compiler, build type and install prefix so
every dependency is built by the same toolchain as cvlab.

**3. Find it and link it.** In `cmake/Dependencies.cmake`:

    find_package(fmt CONFIG REQUIRED)

then from a topic:

    cvlab_add_topic(NAME my_topic TESTS my_topic_test.cpp LIBS fmt::fmt)

Finally add the name to `DEFAULT_LIBS` in `scripts/build_third_party.sh` if it
should build by default, and to the `case` that validates library arguments.

## Offline and restricted networks

**Mirror.** Set `CVLAB_MIRROR_URL` to a base URL holding the archives under
their pinned filenames; it is tried before the upstream URL:

    CVLAB_MIRROR_URL=https://mirror.internal/cvlab ./scripts/build_third_party.sh

**Manual drop-in.** Copy archives into `downloads/` using the exact filename
from `versions.cmake` (e.g. `opencv-4.14.0.tar.gz`). If the file is present
and its hash matches, nothing is downloaded.

**Proxies.** `http_proxy` / `https_proxy` are honoured by CMake and curl as
usual; no extra configuration is needed.

## Hash mismatches

A mismatch fails the build loudly, and that is deliberate. Two causes:

- **A corrupted or truncated download.** Delete the file from `downloads/`
  and re-run.
- **Upstream regenerated the archive.** GitHub's auto-generated tarballs
  (`/archive/refs/tags/...`) are not guaranteed byte-stable forever; a change
  in Git's compression can alter the bytes without the tag moving. Re-download
  by hand, inspect the contents, and only then re-pin the new hash.

Never "fix" a mismatch by disabling the check.

## Build type and sanitizers

Dependencies build in **Release** by default, even when cvlab is built Debug,
ASan or TSan. They are tools, not the subject of study, and a Debug OpenCV is
both slow and large.

See `docs/setup.md` for the ABI and sanitizer caveats — in particular why an
uninstrumented Release OpenCV limits what TSan can tell you.
