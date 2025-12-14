#!/usr/bin/env bash
set -euo pipefail

# Resolve the script directory (works whether script is in scripts/ or repo root)
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

COMPOSE_CMD=""
if docker compose version >/dev/null 2>&1; then
  COMPOSE_CMD="docker compose"
elif docker-compose version >/dev/null 2>&1; then
  COMPOSE_CMD="docker-compose"
else
  echo "Docker Compose not found (requires 'docker compose' or 'docker-compose')." >&2
  exit 1
fi

YES=0
for arg in "$@"; do
  case "$arg" in
    --yes) YES=1 ;;
    *) ;;
  esac
done

if [ "$YES" -ne 1 ]; then
  echo "This will PERMANENTLY DELETE project data (documents, DB tables, Qdrant collections, frontend settings)."
  read -p "Type RESET to continue: " confirm
  if [ "$confirm" != "RESET" ]; then
    echo "Aborted. To force the reset run: $0 --yes"
    exit 1
  fi
fi

echo "==> Reset started"

echo "-- Bringing up database and qdrant containers"
$COMPOSE_CMD up -d database qdrant

echo "-- Waiting for Postgres to be ready"
until $COMPOSE_CMD exec database pg_isready -U postgres >/dev/null 2>&1; do
  sleep 1
done

echo "-- Dropping all tables (DROP SCHEMA public CASCADE; CREATE SCHEMA public;)"
$COMPOSE_CMD exec -T database psql -U postgres -d documents -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"

echo "-- Removing document files in ./documents"
if [ -d "$ROOT_DIR/documents" ]; then
  rm -rf "$ROOT_DIR/documents"/* || true
fi

echo "-- Clearing all Qdrant collections"
# Ensure qdrant is up and reachable on localhost:6333
if command -v curl >/dev/null 2>&1; then
  collections_json="$(curl -sS http://localhost:6333/collections || echo '')"
  if [ -n "$collections_json" ]; then
    names=$(printf "%s" "$collections_json" | python3 -c 'import sys,json; r=json.load(sys.stdin); print("\n".join([c["name"] for c in r.get("collections",[])]))' || true)
    if [ -n "$names" ]; then
      echo "Found Qdrant collections:"
      printf "%s\n" "$names"
      while IFS= read -r name; do
        [ -z "$name" ] && continue
        echo "Deleting collection: $name"
        curl -sS -X DELETE "http://localhost:6333/collections/$name" || true
      done <<< "$names"
    else
      echo "No Qdrant collections found."
    fi
  else
    echo "Failed to query Qdrant collections. Skipping Qdrant cleanup." >&2
  fi
else
  echo "curl not available; skipping Qdrant cleanup." >&2
fi

echo "-- Removing frontend user settings (~/.config/documents-frontend)"
CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/documents-frontend"
if [ -d "$CFG_DIR" ]; then
  rm -rf "$CFG_DIR"
  echo "Removed $CFG_DIR"
else
  echo "No frontend config dir found at $CFG_DIR"
fi

echo "-- Starting backend and models and running migrations"
$COMPOSE_CMD up -d backend models

echo "-- Waiting a few seconds for backend to start"
sleep 3

echo "-- Running TypeORM migrations (this will also run seeders)"
$COMPOSE_CMD exec backend yarn migration:run || {
  echo "Migration command failed. Check backend logs: docker compose logs backend" >&2
  exit 1
}

echo "==> Reset completed successfully"
