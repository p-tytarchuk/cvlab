#!/usr/bin/env bash
#
# Builds cvlab's third-party dependencies from pinned source archives.
#
#   ./scripts/build_third_party.sh                    # default set
#   ./scripts/build_third_party.sh gtest opencv       # only these
#   ./scripts/build_third_party.sh --clean opencv     # drop its build+install
#   ./scripts/build_third_party.sh --debug            # separate Debug prefix
#   ./scripts/build_third_party.sh --jobs 4
#
# Everything is installed under third_party/install/<os>-<arch>[-debug].
# Nothing is installed system-wide and sudo is never invoked.

set -Eeuo pipefail

# Note on ${arr[@]+"${arr[@]}"}: macOS ships bash 3.2, where expanding an
# empty array as "${arr[@]}" under `set -u` aborts with "unbound variable".
# The +-expansion form is the portable way to iterate a possibly-empty array.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THIRD_PARTY="${REPO_ROOT}/third_party"
DOWNLOADS="${THIRD_PARTY}/downloads"

DEFAULT_LIBS=(googletest benchmark opencv)

# --- Pretty output ----------------------------------------------------------
if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_RED=$'\033[31m'
  C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_BLUE=$'\033[34m'
else
  C_RESET=''; C_BOLD=''; C_RED=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''
fi

info()  { printf '%s==>%s %s\n' "${C_BLUE}${C_BOLD}" "${C_RESET}" "$*"; }
ok()    { printf '%s  ok%s %s\n' "${C_GREEN}" "${C_RESET}" "$*"; }
warn()  { printf '%swarn%s %s\n' "${C_YELLOW}" "${C_RESET}" "$*" >&2; }
die()   { printf '%serror%s %s\n' "${C_RED}${C_BOLD}" "${C_RESET}" "$*" >&2; exit 1; }

on_error() {
  local line=$1
  printf '\n%serror%s build_third_party.sh failed at line %s\n' \
    "${C_RED}${C_BOLD}" "${C_RESET}" "${line}" >&2
}
trap 'on_error ${LINENO}' ERR

# --- Host detection ---------------------------------------------------------
# Must agree with cvlab_host_tag() in cmake/Dependencies.cmake.
detect_host() {
  local os arch
  case "$(uname -s)" in
    Darwin) os=macos ;;
    Linux)  os=linux ;;
    *)      die "unsupported OS: $(uname -s). cvlab supports macOS and Linux." ;;
  esac
  case "$(uname -m)" in
    x86_64|amd64)  arch=x86_64 ;;
    arm64|aarch64) arch=arm64 ;;
    *)             die "unsupported architecture: $(uname -m)" ;;
  esac
  HOST_OS="${os}"
  HOST_TAG="${os}-${arch}"
}

# Install command hints, printed but never run: this script does not sudo.
install_hint() {
  local tool=$1
  if [[ "${HOST_OS}" == "macos" ]]; then
    case "${tool}" in
      cmake)      echo "brew install cmake" ;;
      ninja)      echo "brew install ninja" ;;
      git)        echo "xcode-select --install" ;;
      pkg-config) echo "brew install pkg-config" ;;
      c++|cc)     echo "xcode-select --install" ;;
      *)          echo "brew install ${tool}" ;;
    esac
  else
    case "${tool}" in
      cmake)      echo "sudo apt-get install -y cmake" ;;
      ninja)      echo "sudo apt-get install -y ninja-build" ;;
      git)        echo "sudo apt-get install -y git" ;;
      pkg-config) echo "sudo apt-get install -y pkg-config" ;;
      c++|cc)     echo "sudo apt-get install -y build-essential" ;;
      curl)       echo "sudo apt-get install -y curl" ;;
      *)          echo "sudo apt-get install -y ${tool}" ;;
    esac
  fi
}

require_tool() {
  local tool=$1 purpose=$2
  if ! command -v "${tool}" >/dev/null 2>&1; then
    printf '%serror%s missing required tool: %s (%s)\n' \
      "${C_RED}${C_BOLD}" "${C_RESET}" "${tool}" "${purpose}" >&2
    printf '       install it with:  %s\n' "$(install_hint "${tool}")" >&2
    return 1
  fi
  return 0
}

check_prerequisites() {
  info "Checking prerequisites"
  local missing=0

  require_tool cmake "configures and builds everything" || missing=1
  require_tool git   "used by CMake for some source steps" || missing=1
  require_tool tar   "unpacks the source archives" || missing=1

  # A downloader: either is fine.
  if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
    printf '%serror%s need curl or wget to download archives\n' \
      "${C_RED}${C_BOLD}" "${C_RESET}" >&2
    printf '       install it with:  %s\n' "$(install_hint curl)" >&2
    missing=1
  fi

  # A C++ compiler.
  if [[ -z "${CXX:-}" ]] && ! command -v c++ >/dev/null 2>&1 && ! command -v g++ >/dev/null 2>&1; then
    printf '%serror%s no C++ compiler found\n' "${C_RED}${C_BOLD}" "${C_RESET}" >&2
    printf '       install it with:  %s\n' "$(install_hint c++)" >&2
    missing=1
  fi

  (( missing == 0 )) || die "install the tools above, then run this script again"

  # cmake >= 3.24 is required for the preset and ExternalProject features used.
  local cmake_version
  cmake_version="$(cmake --version | head -1 | awk '{print $3}')"
  if ! printf '3.24.0\n%s\n' "${cmake_version}" | sort -V -C; then
    die "cmake ${cmake_version} is too old; cvlab needs >= 3.24. Install with: $(install_hint cmake)"
  fi
  ok "cmake ${cmake_version}"

  # Ninja is preferred but optional; Make is the documented fallback.
  if command -v ninja >/dev/null 2>&1; then
    GENERATOR="Ninja"
    ok "ninja $(ninja --version)"
  else
    GENERATOR="Unix Makefiles"
    warn "ninja not found, falling back to '${GENERATOR}' (slower)"
    warn "  install it with:  $(install_hint ninja)"
  fi

  # pkg-config is not required by the default set, so only note its absence.
  command -v pkg-config >/dev/null 2>&1 || \
    warn "pkg-config not found; not needed for the default libraries"
}

# --- Argument parsing -------------------------------------------------------
usage() {
  cat <<USAGE
Usage: $(basename "$0") [options] [library ...]

Libraries: ${DEFAULT_LIBS[*]} (default: all of them)
           'gtest' is accepted as an alias for 'googletest'.

Options:
  --clean        Remove the build tree and install prefix of the chosen
                 libraries, then rebuild. Never touches your source files.
  --debug        Build dependencies in Debug into a separate -debug prefix.
  -j, --jobs N   Parallel build jobs (default: all cores).
  -h, --help     Show this help.

Environment:
  CVLAB_MIRROR_URL   Base URL tried before the upstream download URL.
  http_proxy / https_proxy   Honoured by curl and CMake as usual.

Offline use: drop the archives named in third_party/versions.cmake into
third_party/downloads/ by hand. A file whose SHA256 matches is never
re-downloaded.
USAGE
}

CLEAN=0
BUILD_TYPE=Release
PREFIX_SUFFIX=""
JOBS=""
REQUESTED=()

while (( $# )); do
  case "$1" in
    --clean)     CLEAN=1; shift ;;
    --debug)     BUILD_TYPE=Debug; PREFIX_SUFFIX="-debug"; shift ;;
    -j|--jobs)   [[ ${2:-} =~ ^[0-9]+$ ]] || die "--jobs needs a number"; JOBS="$2"; shift 2 ;;
    --jobs=*)    JOBS="${1#*=}"; [[ ${JOBS} =~ ^[0-9]+$ ]] || die "--jobs needs a number"; shift ;;
    -h|--help)   usage; exit 0 ;;
    -*)          die "unknown option: $1 (try --help)" ;;
    *)           REQUESTED+=("$1"); shift ;;
  esac
done

detect_host

# Default parallelism: every core.
if [[ -z "${JOBS}" ]]; then
  if [[ "${HOST_OS}" == "macos" ]]; then
    JOBS="$(sysctl -n hw.ncpu)"
  else
    JOBS="$(nproc)"
  fi
fi

# Normalise names and validate before doing any work.
LIBS=()
if (( ${#REQUESTED[@]} == 0 )); then
  LIBS=("${DEFAULT_LIBS[@]}")
else
  for lib in ${REQUESTED[@]+"${REQUESTED[@]}"}; do
    case "${lib}" in
      gtest|googletest) LIBS+=(googletest) ;;
      benchmark)        LIBS+=(benchmark) ;;
      opencv)           LIBS+=(opencv) ;;
      *) die "unknown library '${lib}'. Known: ${DEFAULT_LIBS[*]}" ;;
    esac
  done
fi

BUILD_DIR="${THIRD_PARTY}/build/${HOST_TAG}${PREFIX_SUFFIX}"
INSTALL_PREFIX="${THIRD_PARTY}/install/${HOST_TAG}${PREFIX_SUFFIX}"

# --- Idempotence ------------------------------------------------------------
# A stamp records the version a library was installed at, so re-running the
# script is cheap and a version bump in versions.cmake forces a rebuild.
stamp_file() { echo "${INSTALL_PREFIX}/.cvlab-stamp-$1"; }

# Reads the pinned VERSION for a library out of versions.cmake.
# Uses awk, not sed: BSD sed (macOS) does not support \+ in a basic regex, so
# a sed range that works on Ubuntu silently matches nothing here.
pinned_version() {
  awk -v want="$1" '
    $1 == "NAME"    && $2 == want { in_block = 1; next }
    in_block && $1 == "VERSION"   { print $2; exit }
    in_block && $0 ~ /^\)/        { exit }
  ' "${THIRD_PARTY}/versions.cmake"
}

is_installed() {
  local lib=$1 stamp want have
  stamp="$(stamp_file "${lib}")"
  [[ -f "${stamp}" ]] || return 1
  want="$(pinned_version "${lib}")"
  have="$(cat "${stamp}")"
  [[ -n "${want}" && "${want}" == "${have}" ]]
}

write_stamp() {
  local lib=$1
  mkdir -p "${INSTALL_PREFIX}"
  pinned_version "${lib}" > "$(stamp_file "${lib}")"
}

clean_library() {
  # Only ever removes generated trees: downloads/ and your sources are safe.
  local lib=$1
  info "Cleaning ${lib}"
  rm -rf "${BUILD_DIR:?}/${lib}"
  rm -f  "$(stamp_file "${lib}")"
  case "${lib}" in
    googletest)
      rm -rf "${INSTALL_PREFIX}"/include/{gtest,gmock}
      rm -f  "${INSTALL_PREFIX}"/lib/libgtest*.a "${INSTALL_PREFIX}"/lib/libgmock*.a
      rm -rf "${INSTALL_PREFIX}"/lib/cmake/GTest
      ;;
    benchmark)
      rm -rf "${INSTALL_PREFIX}"/include/benchmark
      rm -f  "${INSTALL_PREFIX}"/lib/libbenchmark*.a
      rm -rf "${INSTALL_PREFIX}"/lib/cmake/benchmark
      ;;
    opencv)
      rm -rf "${INSTALL_PREFIX}"/include/opencv4
      rm -f  "${INSTALL_PREFIX}"/lib/libopencv_*.a
      rm -rf "${INSTALL_PREFIX}"/lib/cmake/opencv4 "${INSTALL_PREFIX}"/lib/opencv4
      rm -rf "${INSTALL_PREFIX}"/share/opencv4
      ;;
  esac
}

human_time() {
  local s=$1
  printf '%dm %02ds' $(( s / 60 )) $(( s % 60 ))
}

# --- Build ------------------------------------------------------------------
main() {
  info "cvlab third-party build"
  printf '     host:    %s\n'   "${HOST_TAG}"
  printf '     type:    %s\n'   "${BUILD_TYPE}"
  printf '     jobs:    %s\n'   "${JOBS}"
  printf '     prefix:  %s\n'   "${INSTALL_PREFIX}"
  printf '     libs:    %s\n\n' "${LIBS[*]-}"

  check_prerequisites
  mkdir -p "${DOWNLOADS}" "${BUILD_DIR}" "${INSTALL_PREFIX}"

  if (( CLEAN )); then
    for lib in ${LIBS[@]+"${LIBS[@]}"}; do clean_library "${lib}"; done
  fi

  # Skip anything already installed at the pinned version.
  local todo=()
  for lib in ${LIBS[@]+"${LIBS[@]}"}; do
    if is_installed "${lib}"; then
      ok "${lib} $(pinned_version "${lib}") already installed, skipping"
    else
      todo+=("${lib}")
    fi
  done

  if (( ${#todo[@]} == 0 )); then
    printf '\n%sNothing to do.%s All requested libraries are installed.\n' \
      "${C_GREEN}${C_BOLD}" "${C_RESET}"
    printf 'Configure cvlab with:  cmake --preset debug\n'
    return 0
  fi

  local total_start=${SECONDS}

  # One CMake invocation per library keeps the per-library timing honest and
  # lets --clean of one library leave the others untouched.
  for lib in ${todo[@]+"${todo[@]}"}; do
    local start=${SECONDS}
    info "Building ${lib} $(pinned_version "${lib}")"

    cmake -S "${THIRD_PARTY}" -B "${BUILD_DIR}" -G "${GENERATOR}" \
      -DCVLAB_INSTALL_PREFIX="${INSTALL_PREFIX}" \
      -DCVLAB_DEP_BUILD_TYPE="${BUILD_TYPE}" \
      -DCVLAB_ONLY="${lib}" \
      > "${BUILD_DIR}/${lib}-configure.log" 2>&1 \
      || { tail -30 "${BUILD_DIR}/${lib}-configure.log" >&2
           die "configuring ${lib} failed (full log: ${BUILD_DIR}/${lib}-configure.log)"; }

    cmake --build "${BUILD_DIR}" -j "${JOBS}" \
      > "${BUILD_DIR}/${lib}-build.log" 2>&1 \
      || { tail -40 "${BUILD_DIR}/${lib}-build.log" >&2
           die "building ${lib} failed (full log: ${BUILD_DIR}/${lib}-build.log)"; }

    write_stamp "${lib}"
    ok "${lib} built in $(human_time $(( SECONDS - start )))"
  done

  printf '\n%sDone%s in %s. Prefix: %s\n' \
    "${C_GREEN}${C_BOLD}" "${C_RESET}" "$(human_time $(( SECONDS - total_start )))" "${INSTALL_PREFIX}"
  printf '\nNext:\n  cmake --preset debug\n  cmake --build --preset debug\n  ctest --preset debug\n'
}

main "$@"
