#!/usr/bin/env bash
set -Eeuo pipefail

RELEASE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

log_info() { printf '[INFO] %s\n' "$*"; }
log_warn() { printf '[WARN] %s\n' "$*" >&2; }
die() {
  local message="$1"
  local status="${2:-1}"
  printf '[ERROR] %s\n' "$message" >&2
  exit "$status"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1" 3
}

require_file() {
  [ -f "$1" ] || die "Required file not found: $1" 3
}

validate_semver() {
  [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+([+-][0-9A-Za-z.-]+)?$ ]] ||
    die "Invalid semantic version: $1" 2
}

detect_target() {
  local os arch
  case "$(uname -s)" in
    Linux*) os="linux" ;;
    Darwin*) os="darwin" ;;
    MINGW*|MSYS*|CYGWIN*) os="win32" ;;
    *) die "Unsupported operating system: $(uname -s)" 2 ;;
  esac
  case "$(uname -m)" in
    x86_64|amd64) arch="x64" ;;
    aarch64|arm64) arch="arm64" ;;
    *) die "Unsupported architecture: $(uname -m)" 2 ;;
  esac
  printf '%s-%s\n' "$os" "$arch"
}

assert_local_target() {
  local actual
  actual="$(detect_target)"
  [ "$1" = "$actual" ] || die "Target $1 must be built on a matching host (current: $actual)" 2
}

assert_inside_workspace() {
  local resolved root
  resolved="$(realpath -m "$1")"
  root="$(realpath -m "$RELEASE_ROOT")"
  case "$resolved" in
    "$root"/*) ;;
    *) die "Path must be inside the workspace: $resolved" 2 ;;
  esac
}

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

sha512_file() {
  if command -v sha512sum >/dev/null 2>&1; then
    sha512sum "$1" | awk '{print $1}'
  else
    shasum -a 512 "$1" | awk '{print $1}'
  fi
}

git_revision() {
  git -C "$1" rev-parse HEAD
}

run_logged() {
  local log_file="$1"
  shift
  mkdir -p "$(dirname "$log_file")"
  local status=0
  "$@" >"$log_file" 2>&1 || status=$?
  if [ "$status" -ne 0 ]; then
    tail -40 "$log_file" >&2 || true
    return "$status"
  fi
}
