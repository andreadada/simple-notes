#!/usr/bin/env bash
set -euo pipefail
# T4.2 missing-note investigation. Production DB is STRICTLY read-only.
# No note titles, bodies, emails, access tokens or raw entity/user UUIDs printed.
: "${DB_CONTAINER:?Set DB_CONTAINER to the verified Simple Notes PostgreSQL container}"
EXPECTED_POSTGRES_DB="${EXPECTED_POSTGRES_DB:-simplenotes}"
command -v docker >/dev/null || { echo "docker is required" >&2; exit 2; }
db_name="$(docker exec "$DB_CONTAINER" sh -c 'printf "%s" "${POSTGRES_DB:-}"')"
[[ "$db_name" == "$EXPECTED_POSTGRES_DB" && -n "$db_name" ]] || {
  echo "REFUSED: unexpected PostgreSQL database/container" >&2
  exit 2
}
running="$(docker inspect --format '{{.State.Running}}' "$DB_CONTAINER")"
[[ "$running" == true ]] || { echo "REFUSED: selected PostgreSQL container not running" >&2; exit 2; }
# Make every psql connection read-only, including accidental future edits.
# Queries below contain SELECT/SHOW only. 10s statement timeout, no file writes.
sql() {
  docker exec "$DB_CONTAINER" sh -eu -c \
    'export PGOPTIONS="-c default_transaction_read_only=on -c statement_timeout=10000"; exec psql -X -v ON_ERROR_STOP=1 -P pager=off -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "$1"' \
    _ "$1"
}
scalar() {
  docker exec "$DB_CONTAINER" sh -eu -c \
    'export PGOPTIONS="-c default_transaction_read_only=on -c statement_timeout=10000"; exec psql -X -v ON_ERROR_STOP=1 -Atq -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "$1"' \
    _ "$1"
}
[[ "$(scalar 'SHOW default_transaction_read_only')" == on ]] || {
  echo "REFUSED: read-only SQL mode not active" >&2
  exit 2
}
major_version="$(scalar 'SHOW server_version_num')"
[[ "$major_version" =~ ^[0-9]+$ && $((major_version / 10000)) -eq 17 ]] || {
  echo "REFUSED: expected PostgreSQL major 17" >&2
  exit 2
}
required="$(scalar "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_name IN ('app_user','note','sync_change','sync_operation')")"
[[ "$required" == 4 ]] || { echo "REFUSED: unexpected database schema" >&2; exit 2; }
echo 'T4_NOTE_AUDIT=READ_ONLY'
printf 'DB_NAME=%s\nPOSTGRES_MAJOR=17\n' "$db_name"
echo '--- Note status (per account pseudonym; no titles/body) ---'
sql "SELECT LEFT(MD5(owner_id::text), 10) AS owner_ref,
  COUNT(*) AS total_rows,
  COUNT(*) FILTER (WHERE deleted_at IS NULL) AS visible_rows,
  COUNT(*) FILTER (WHERE deleted_at IS NOT NULL) AS soft_deleted_rows
FROM public.note GROUP BY owner_id ORDER BY owner_ref"
echo '--- Current note rows (pseudonymous stable note refs; NO CONTENT) ---'
sql "SELECT LEFT(MD5(owner_id::text),10) AS owner_ref,
  LEFT(MD5(id::text),10) AS note_ref,
  CASE WHEN deleted_at IS NULL THEN 'visible' ELSE 'soft_deleted' END AS status,
  version,
  created_at AT TIME ZONE 'UTC' AS created_utc,
  deleted_at AT TIME ZONE 'UTC' AS deleted_utc
FROM public.note ORDER BY created_at DESC LIMIT 100"
echo '--- Note change history (up to 100 latest; NO CONTENT) ---'
sql "SELECT id AS cursor_event,
  LEFT(MD5(owner_id::text),10) AS owner_ref,
  LEFT(MD5(entity_id::text),10) AS note_ref,
  CASE WHEN deleted THEN 'DELETE' ELSE 'UPSERT' END AS operation,
  version,
  created_at AT TIME ZONE 'UTC' AS event_utc
FROM (SELECT * FROM public.sync_change
      WHERE entity_type = 'note' ORDER BY id DESC LIMIT 100) note_events
ORDER BY id ASC"
echo '--- All sync events in the observed cursor gap: 25 -> 34 (NO CONTENT) ---'
sql "SELECT id AS cursor_event,
  LEFT(MD5(owner_id::text),10) AS owner_ref,
  entity_type,
  CASE WHEN deleted THEN 'DELETE' ELSE 'UPSERT' END AS operation,
  LEFT(MD5(entity_id::text),10) AS entity_ref,
  version,
  created_at AT TIME ZONE 'UTC' AS event_utc
FROM public.sync_change WHERE id > 25 AND id <= 34 ORDER BY id ASC"
echo 'AUDIT_DONE=READ_ONLY'
echo 'No database writes, exports, restores, migrations or deployments were performed.'
echo 'This audit cannot identify the device that created an event (no device ID in the sync log).'
