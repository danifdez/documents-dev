# Scripts

## reset-dev.sh

Restores the local development environment to a clean state. This is a **destructive** operation intended for development use only.

### What It Does

1. Starts the `database` and `qdrant` containers (if not already running)
2. Waits for PostgreSQL to be ready
3. Drops all PostgreSQL tables (`DROP SCHEMA public CASCADE`) and recreates the schema
4. Deletes all files in `./documents/`
5. Queries Qdrant for all collections and deletes them via the HTTP API
6. Removes the frontend user config at `~/.config/documents-frontend`
7. Starts `backend` and `models` services
8. Runs TypeORM migrations and seeders

### Usage

```bash
# Interactive — prompts for confirmation (type RESET)
bash ./reset-dev.sh

# Non-interactive — skips confirmation
bash ./reset-dev.sh --yes
```

### Requirements

- Docker Compose (v2 plugin or standalone `docker-compose`) — auto-detected
- `curl` — required for Qdrant collection cleanup (skipped if unavailable)
- `python3` — used to parse the Qdrant collections JSON response

### Notes

- The script is idempotent — safe to run multiple times (`|| true` guards on cleanup steps)
- If the migration step fails, check backend logs: `docker compose logs backend`
- The script detects the available Docker Compose command automatically (`docker compose` or `docker-compose`)
