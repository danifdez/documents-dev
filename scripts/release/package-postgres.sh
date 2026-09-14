#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/release/common.sh"

VERSION=""
POSTGRES_VERSION=""
TARGET=""
POSTGRES_SOURCE_URL=""
POSTGRES_SOURCE_SHA256=""
PGVECTOR_SOURCE_URL=""
PGVECTOR_SOURCE_SHA256=""
AGE_SOURCE_URL=""
AGE_SOURCE_SHA512=""
STAGING=""
OUTPUT=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --version) VERSION="$2"; shift 2 ;;
    --postgres-version) POSTGRES_VERSION="$2"; shift 2 ;;
    --target) TARGET="$2"; shift 2 ;;
    --postgres-source-url) POSTGRES_SOURCE_URL="$2"; shift 2 ;;
    --postgres-source-sha256) POSTGRES_SOURCE_SHA256="$2"; shift 2 ;;
    --pgvector-source-url) PGVECTOR_SOURCE_URL="$2"; shift 2 ;;
    --pgvector-source-sha256) PGVECTOR_SOURCE_SHA256="$2"; shift 2 ;;
    --age-source-url) AGE_SOURCE_URL="$2"; shift 2 ;;
    --age-source-sha512) AGE_SOURCE_SHA512="$2"; shift 2 ;;
    --staging) STAGING="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    *) die "Unknown PostgreSQL packaging argument: $1" 2 ;;
  esac
done

[ -n "$VERSION" ] && [ -n "$POSTGRES_VERSION" ] && [ -n "$TARGET" ] && [ -n "$STAGING" ] && [ -n "$OUTPUT" ] ||
  die "PostgreSQL packaging requires version, postgres-version, target, staging and output" 2
[ -n "$POSTGRES_SOURCE_URL" ] && [ -n "$POSTGRES_SOURCE_SHA256" ] || die "PostgreSQL source is required" 2
[ -n "$PGVECTOR_SOURCE_URL" ] && [ -n "$PGVECTOR_SOURCE_SHA256" ] || die "pgvector source is required" 2
[ -n "$AGE_SOURCE_URL" ] && [ -n "$AGE_SOURCE_SHA512" ] || die "Apache AGE source is required" 2
validate_semver "$VERSION"
assert_local_target "$TARGET"
assert_inside_workspace "$STAGING"
assert_inside_workspace "$OUTPUT"
case "$TARGET" in linux-x64) ;; *) die "PostgreSQL source packaging currently supports linux-x64 only" 2 ;; esac
[[ "$POSTGRES_SOURCE_SHA256" =~ ^[a-f0-9]{64}$ ]] || die "Invalid PostgreSQL source checksum" 2
[[ "$PGVECTOR_SOURCE_SHA256" =~ ^[a-f0-9]{64}$ ]] || die "Invalid pgvector source checksum" 2
[[ "$AGE_SOURCE_SHA512" =~ ^[a-f0-9]{128}$ ]] || die "Invalid Apache AGE source checksum" 2
for tool in curl tar make gcc flex bison; do require_command "$tool"; done

rm -rf "$STAGING"
mkdir -p "$STAGING/runtime" "$STAGING/downloads" "$STAGING/sources" "$OUTPUT/components" "$OUTPUT/.metadata/$TARGET" "$OUTPUT/logs"
LOG_FILE="$OUTPUT/logs/postgres.log"
RUNTIME="$STAGING/runtime"
DOWNLOADS="$STAGING/downloads"
SOURCES="$STAGING/sources"
JOBS="$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf '2')"

download_and_verify() {
  local url="$1"
  local archive="$2"
  local algorithm="$3"
  local expected="$4"
  run_logged "$LOG_FILE.download.$(basename "$archive")" curl -fL "$url" -o "$archive"
  local actual
  case "$algorithm" in
    sha256) actual="$(sha256_file "$archive")" ;;
    sha512) actual="$(sha512_file "$archive")" ;;
    *) die "Unsupported source checksum algorithm: $algorithm" 2 ;;
  esac
  [ "$actual" = "$expected" ] || die "Source checksum mismatch for $(basename "$archive")" 6
}

extract_source() {
  local archive="$1"
  local destination="$2"
  mkdir -p "$destination"
  tar xzf "$archive" -C "$destination"
  local source_dir
  source_dir="$(find "$destination" -mindepth 1 -maxdepth 1 -type d | head -1)"
  [ -n "$source_dir" ] || die "Source archive has no top-level directory: $archive" 4
  printf '%s\n' "$source_dir"
}

POSTGRES_ARCHIVE="$DOWNLOADS/postgresql-${POSTGRES_VERSION}.tar.gz"
PGVECTOR_ARCHIVE="$DOWNLOADS/pgvector.tar.gz"
AGE_ARCHIVE="$DOWNLOADS/apache-age.tar.gz"
log_info "Downloading pinned PostgreSQL, pgvector and Apache AGE sources"
download_and_verify "$POSTGRES_SOURCE_URL" "$POSTGRES_ARCHIVE" sha256 "$POSTGRES_SOURCE_SHA256"
download_and_verify "$PGVECTOR_SOURCE_URL" "$PGVECTOR_ARCHIVE" sha256 "$PGVECTOR_SOURCE_SHA256"
download_and_verify "$AGE_SOURCE_URL" "$AGE_ARCHIVE" sha512 "$AGE_SOURCE_SHA512"

POSTGRES_SOURCE="$(extract_source "$POSTGRES_ARCHIVE" "$SOURCES/postgres")"
PGVECTOR_SOURCE="$(extract_source "$PGVECTOR_ARCHIVE" "$SOURCES/pgvector")"
AGE_SOURCE="$(extract_source "$AGE_ARCHIVE" "$SOURCES/age")"

log_info "Building PostgreSQL ${POSTGRES_VERSION}"
(cd "$POSTGRES_SOURCE" && run_logged "$LOG_FILE.postgres.configure" ./configure \
  --prefix="$RUNTIME" --without-readline --without-icu --without-ldap --without-pam --without-gssapi)
run_logged "$LOG_FILE.postgres.build" make -C "$POSTGRES_SOURCE" -j"$JOBS"
run_logged "$LOG_FILE.postgres.install" make -C "$POSTGRES_SOURCE" install
run_logged "$LOG_FILE.postgres.contrib.pg-trgm" make -C "$POSTGRES_SOURCE/contrib/pg_trgm" install
run_logged "$LOG_FILE.postgres.contrib.unaccent" make -C "$POSTGRES_SOURCE/contrib/unaccent" install

PG_CONFIG="$RUNTIME/bin/pg_config"
require_file "$PG_CONFIG"
log_info "Building pgvector and Apache AGE against the packaged PostgreSQL"
PG_CONFIG="$PG_CONFIG" run_logged "$LOG_FILE.pgvector.build" make -C "$PGVECTOR_SOURCE" OPTFLAGS= -j"$JOBS"
PG_CONFIG="$PG_CONFIG" run_logged "$LOG_FILE.pgvector.install" make -C "$PGVECTOR_SOURCE" install
PG_CONFIG="$PG_CONFIG" run_logged "$LOG_FILE.age.build" make -C "$AGE_SOURCE" -j"$JOBS"
PG_CONFIG="$PG_CONFIG" run_logged "$LOG_FILE.age.install" make -C "$AGE_SOURCE" install

require_file "$RUNTIME/lib/vector.so"
require_file "$RUNTIME/share/extension/vector.control"
require_file "$RUNTIME/lib/age.so"
require_file "$RUNTIME/share/extension/age.control"
require_file "$RUNTIME/share/extension/pg_trgm.control"
require_file "$RUNTIME/share/extension/unaccent.control"

PG_BIN="$RUNTIME/bin"
PG_LIB="$RUNTIME/lib"
SMOKE_DATA="$STAGING/smoke-data"
if [[ "$(id -u)" -eq 0 ]]; then
  command -v runuser >/dev/null 2>&1 || die "runuser is required to smoke-test PostgreSQL when building as root"
  install -d -o nobody -g nogroup "$SMOKE_DATA"
  POSTGRES_SMOKE=(runuser -u nobody -- env "LD_LIBRARY_PATH=$PG_LIB")
else
  mkdir -p "$SMOKE_DATA"
  POSTGRES_SMOKE=(env "LD_LIBRARY_PATH=$PG_LIB")
fi
"${POSTGRES_SMOKE[@]}" "$PG_BIN/initdb" -D "$SMOKE_DATA" -U documents --auth=trust --no-locale >"$LOG_FILE.smoke" 2>&1
printf 'CREATE EXTENSION pg_trgm;\nCREATE EXTENSION unaccent;\nCREATE EXTENSION vector;\nCREATE EXTENSION age;\n' |
  "${POSTGRES_SMOKE[@]}" "$PG_BIN/postgres" --single -D "$SMOKE_DATA" postgres >>"$LOG_FILE.smoke" 2>&1

rm -rf "$SMOKE_DATA" "$DOWNLOADS" "$SOURCES" "$RUNTIME/include" "$RUNTIME/lib/pgxs"

node --input-type=module - "$RUNTIME/component-manifest.json" "$VERSION" "$TARGET" "$POSTGRES_VERSION" <<'NODE'
import fs from 'node:fs';
const [, , file, release, target, postgres] = process.argv;
fs.writeFileSync(file, `${JSON.stringify({
  schemaVersion: 1, component: 'postgres', version: `${postgres}+documents.${release}`,
  release, target, entrypoint: 'bin/postgres', extensions: ['pg_trgm', 'unaccent', 'vector', 'age'],
  createdAt: new Date().toISOString(),
}, null, 2)}\n`);
NODE

NAME="documents-postgres-v${VERSION}-${TARGET}.tar.gz"
ARTIFACT="$OUTPUT/components/$NAME"
tar czf "$ARTIFACT" -C "$RUNTIME" .
node --input-type=module - "$OUTPUT/.metadata/$TARGET/postgres.json" "$VERSION" "$TARGET" "components/$NAME" "$POSTGRES_VERSION" <<'NODE'
import fs from 'node:fs';
const [, , file, release, target, artifact, postgres] = process.argv;
fs.writeFileSync(file, `${JSON.stringify({
  component: 'postgres', version: `${postgres}+documents.${release}`,
  target, artifact, runtime: { postgres }, requires: { extensions: ['pg_trgm', 'unaccent', 'vector', 'age'] },
}, null, 2)}\n`);
NODE

log_info "PostgreSQL artifact created: $ARTIFACT"
