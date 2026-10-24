#!/usr/bin/env bash
set -euo pipefail

# Read-only pg_dump of the explicitly selected Simple Notes PostgreSQL.
# NEVER runs migrations, restarts containers, or deletes a database.
: "${DB_CONTAINER:?Select the exact Simple Notes PostgreSQL container name or ID}"
EXPECTED_POSTGRES_DB="${EXPECTED_POSTGRES_DB:-simplenotes}"
BACKUP_DIR="${BACKUP_DIR:-./backups}"
for cmd in docker sha256sum mktemp; do
  command -v "$cmd" >/dev/null || { echo "Missing $cmd" >&2; exit 2; }
done
actual_db="$(docker exec "$DB_CONTAINER" sh -c 'printf "%s" "${POSTGRES_DB:-}"')"
if [[ -z "$actual_db" || "$actual_db" != "$EXPECTED_POSTGRES_DB" ]]; then
  echo "REFUSED: selected database name does not match EXPECTED_POSTGRES_DB." >&2
  exit 2
fi
# Protect against accidentally backing up a similarly named, unrelated DB.
docker exec "$DB_CONTAINER" sh -eu -c '
  exec psql -X -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atqc \
    "SELECT CASE WHEN to_regclass('\''public.task'\'') IS NOT NULL
      AND to_regclass('\''public.note'\'') IS NOT NULL
      AND to_regclass('\''public.sync_operation'\'') IS NOT NULL
      THEN 1 ELSE 0 END"
' | grep -qx '1' || {
  echo "REFUSED: missing Simple Notes core schema." >&2; exit 2;
}
umask 077
mkdir -p -- "$BACKUP_DIR"
BACKUP_DIR="$(cd -- "$BACKUP_DIR" && pwd -P)"
filename="simple-notes-$(date -u +%Y%m%dT%H%M%SZ)-$$.dump"
target="$BACKUP_DIR/$filename"
temp="$(mktemp "$BACKUP_DIR/.simple-notes.XXXXXXXX")"
trap 'rm -f -- "$temp"' EXIT
echo "Exporting confirmed PostgreSQL database '$actual_db' (read only)."
docker exec "$DB_CONTAINER" sh -eu -c \
  'exec pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" --format=custom --no-owner --no-privileges' \
  > "$temp"
if [[ ! -s "$temp" || "$(head -c 5 "$temp")" != "PGDMP" ]]; then
  echo "REFUSED: empty or non-custom PostgreSQL archive." >&2; exit 1
fi
docker exec -i "$DB_CONTAINER" pg_restore --list < "$temp" >/dev/null
mv -- "$temp" "$target"
(cd -- "$BACKUP_DIR" && sha256sum -- "$filename" > "$filename.sha256")
chmod 600 "$target" "$target.sha256"
echo "Archive and SHA256 manifest: $target"
echo "NEXT: copy securely off-VPS and run infra/verify-restore.sh on the copy."
