#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/release/common.sh"

VERSION=""
NODE_VERSION=""
TARGET=""
STAGING=""
OUTPUT=""
ARCHIVE_SHA256=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --version) VERSION="$2"; shift 2 ;;
    --node-version) NODE_VERSION="$2"; shift 2 ;;
    --target) TARGET="$2"; shift 2 ;;
    --staging) STAGING="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --archive-sha256) ARCHIVE_SHA256="$2"; shift 2 ;;
    *) die "Unknown Node packaging argument: $1" 2 ;;
  esac
done

[ -n "$VERSION" ] && [ -n "$NODE_VERSION" ] && [ -n "$TARGET" ] && [ -n "$STAGING" ] && [ -n "$OUTPUT" ] && [ -n "$ARCHIVE_SHA256" ] ||
  die "Node packaging requires version, node-version, target, archive-sha256, staging and output" 2
validate_semver "$VERSION"
assert_local_target "$TARGET"
assert_inside_workspace "$STAGING"
assert_inside_workspace "$OUTPUT"
require_command curl
require_command node
[[ "$ARCHIVE_SHA256" =~ ^[a-f0-9]{64}$ ]] || die "Invalid Node.js archive checksum" 2

case "$TARGET" in
  linux-x64) NODE_PLATFORM="linux-x64" ;;
  linux-arm64) NODE_PLATFORM="linux-arm64" ;;
  darwin-x64) NODE_PLATFORM="darwin-x64" ;;
  darwin-arm64) NODE_PLATFORM="darwin-arm64" ;;
  *) die "Node packaging currently supports Linux and macOS tarballs" 2 ;;
esac

rm -rf "$STAGING"
mkdir -p "$STAGING/runtime" "$STAGING/downloads" "$OUTPUT/components" "$OUTPUT/.metadata/$TARGET" "$OUTPUT/logs"
ARCHIVE="$STAGING/downloads/node.tar.gz"
NODE_URL="https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-${NODE_PLATFORM}.tar.gz"
LOG_FILE="$OUTPUT/logs/node.log"

log_info "Downloading Node.js $NODE_VERSION ($TARGET)"
run_logged "$LOG_FILE" curl -fSL "$NODE_URL" -o "$ARCHIVE"
[ "$(sha256_file "$ARCHIVE")" = "$ARCHIVE_SHA256" ] || die "Node.js archive checksum mismatch" 6
tar xzf "$ARCHIVE" --strip-components=1 -C "$STAGING/runtime"
rm -rf "$STAGING/downloads"

ACTIVE_NODE_VERSION="$("$STAGING/runtime/bin/node" --version)"
[ "$ACTIVE_NODE_VERSION" = "v$NODE_VERSION" ] || die "Node.js runtime self-check failed" 5
node - "$STAGING/runtime/component-manifest.json" "$NODE_VERSION" "$TARGET" <<'NODE'
import fs from 'node:fs';
const [, , file, version, target] = process.argv;
fs.writeFileSync(file, `${JSON.stringify({
  schemaVersion: 1,
  component: 'node',
  version,
  target,
  entrypoint: 'bin/node',
  source: { url: `https://nodejs.org/dist/v${version}/` },
  createdAt: new Date().toISOString(),
}, null, 2)}\n`);
NODE

NAME="documents-node-v${NODE_VERSION}-${TARGET}.tar.gz"
ARTIFACT="$OUTPUT/components/$NAME"
tar czf "$ARTIFACT" -C "$STAGING/runtime" .
node - "$OUTPUT/.metadata/$TARGET/node.json" "$NODE_VERSION" "$TARGET" "components/$NAME" <<'NODE'
import fs from 'node:fs';
const [, , file, version, target, artifact] = process.argv;
fs.writeFileSync(file, `${JSON.stringify({
  component: 'node', version, target, artifact, runtime: { node: version },
}, null, 2)}\n`);
NODE

log_info "Node.js artifact created: $ARTIFACT"
