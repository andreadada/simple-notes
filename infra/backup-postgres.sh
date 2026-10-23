#!/usr/bin/env bash
set -euo pipefail

# Create a portable, consistent pg_dump from the explicitly selected
# PostgreSQL container. No data is deleted or modified.
# Run on the VPS, not on a local machine without Docker access.
: "${DB_CONTAINER:?Set DB_CONTAINER to the running Simple Notes PostgreSQL container name or ID}"
BACKUP_DIR="${BACKUP_DIR:-./backups}"
umask 077
mkdir -p -- "$BACKUP_DIR"
filename="simple-notes-$(date -u +%Y%m%dT%H%M%SZ).dump"
target="$BACKUP_DIR/$filename"
temp="$(mktemp "$BACKUP_DIR/.simple-notes.XXXXXXXX")"
trap 'rm -f -- "$temp"' EXIT

echo "Dumping PostgreSQL from explicitly selected container: $DB_CONTAINER"
docker exec "$DB_CONTAINER" sh -c \
  'exec pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" --format=custom --no-owner --no-privileges' \
  > "$temp"

if [[ ! -s "$temp" ]]; then
  echo "Backup is empty; refusing to publish it." >&2
  exit 1
fi
# Validate the archive catalog inside the container without restoring it.
docker exec -i "$DB_CONTAINER" pg_restore --list >/dev/null < "$temp"
mv -- "$temp" "$target"
sha256sum "$target" > "$target.sha256"
echo "Archive catalog validated: $target"
echo "IMPORTANT: move this file off the VPS and run the isolated restore test."
