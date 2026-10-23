#!/usr/bin/env bash
set -euo pipefail

# DISPOSABLE validation database. Never point pg_restore at production.
# Usage: ./infra/verify-restore.sh /safe/offsite/backup.dump
if [[ "$#" -ne 1 || ! -r "$1" ]]; then
  echo "Usage: $0 /path/to/simple-notes-backup.dump" >&2
  exit 2
fi
archive="$1"
name="simple-notes-restore-check-$$"
password="$(openssl rand -hex 24)"
cleanup() {
  docker rm -f "$name" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker run --rm -d --name "$name" \
  -e POSTGRES_PASSWORD="$password" \
  postgres:17-alpine >/dev/null

ready=0
for i in $(seq 1 45); do
  # Ignore temporary bootstrap server: wait until entrypoint finishes init.
  if docker logs "$name" 2>&1 | grep -q 'PostgreSQL init process complete' && \
      docker exec "$name" pg_isready -U postgres -d postgres >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 1
done
if [[ "$ready" != 1 ]]; then
  echo "Isolated test Postgres did not become healthy." >&2
  exit 1
fi

docker exec -i "$name" pg_restore \
  -U postgres -d postgres \
  --exit-on-error --single-transaction --no-owner --no-privileges \
  < "$archive"

# Verify at least that the core schema exists and can be queried.
for table in app_user task note sync_change sync_operation; do
  docker exec "$name" psql -U postgres -d postgres -Atqc \
    "SELECT COUNT(*) FROM $table;" >/dev/null
done
echo "Isolated restore succeeded; production DB was never touched."
