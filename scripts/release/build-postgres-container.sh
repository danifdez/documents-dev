#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
IMAGE=""
ARGS=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --image) IMAGE="$2"; shift 2 ;;
    --) shift; ARGS=("$@"); break ;;
    *) printf '[ERROR] Unknown PostgreSQL builder argument: %s\n' "$1" >&2; exit 2 ;;
  esac
done

[ -n "$IMAGE" ] || { printf '[ERROR] PostgreSQL builder image is required\n' >&2; exit 2; }
[[ "$IMAGE" == *@sha256:* ]] || { printf '[ERROR] PostgreSQL builder image must be pinned by digest\n' >&2; exit 2; }
[ "${#ARGS[@]}" -gt 0 ] || { printf '[ERROR] PostgreSQL packaging arguments are required\n' >&2; exit 2; }

STAGING=""
OUTPUT=""
for ((index = 0; index < ${#ARGS[@]}; index += 1)); do
  case "${ARGS[$index]}" in
    --staging) STAGING="${ARGS[$((index + 1))]:-}" ;;
    --output) OUTPUT="${ARGS[$((index + 1))]:-}" ;;
  esac
done
[ -n "$STAGING" ] && [ -n "$OUTPUT" ] || { printf '[ERROR] PostgreSQL staging and output are required\n' >&2; exit 2; }

HOST_UID="$(id -u)"
HOST_GID="$(id -g)"
docker run --rm \
  -e HOST_UID="$HOST_UID" \
  -e HOST_GID="$HOST_GID" \
  -e STAGING_DIR="$STAGING" \
  -e OUTPUT_DIR="$OUTPUT" \
  -v "$ROOT_DIR:$ROOT_DIR" \
  -w "$ROOT_DIR" \
  "$IMAGE" \
  bash -ec '
    trap "status=\$?; chown -R \"\$HOST_UID:\$HOST_GID\" \"\$STAGING_DIR\" \"\$OUTPUT_DIR\" 2>/dev/null || true; exit \$status" EXIT
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
apt-get install -y --no-install-recommends build-essential ca-certificates curl flex bison nodejs perl tar zlib1g-dev
    "$@"
  ' documents-postgres-builder "$ROOT_DIR/scripts/release/package-postgres.sh" "${ARGS[@]}"
