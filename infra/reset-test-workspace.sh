#!/usr/bin/env bash
set -euo pipefail
# Destructive TEST workspace reset. Never drops the database, users,
# authentication sessions, Flyway metadata, or other app volumes.
: "${DB_CONTAINER:?Set the verified Simple Notes PostgreSQL container}"
EXPECTED_POSTGRES_DB="${EXPECTED_POSTGRES_DB:-simplenotes}"
MODE="${1:---preview}"
[[ "$MODE" == "--preview" || "$MODE" == "--execute" ]] || {
  echo 'Usage: reset-test-workspace.sh --preview|--execute' >&2; exit 2
}
command -v docker >/dev/null || { echo 'docker required' >&2; exit 2; }
db_name="$(docker exec "$DB_CONTAINER" sh -c 'printf "%s" "${POSTGRES_DB:-}"')"
[[ "$db_name" == "$EXPECTED_POSTGRES_DB" && "$db_name" == simplenotes ]] || {
  echo 'REFUSED: unexpected DB/container' >&2; exit 2
}
[[ "$(docker inspect --format '{{.State.Running}}' "$DB_CONTAINER")" == true ]] || {
  echo 'REFUSED: PostgreSQL container not running' >&2; exit 2
}
psql_read() {
  docker exec "$DB_CONTAINER" sh -eu -c \
    'export PGOPTIONS="-c default_transaction_read_only=on -c statement_timeout=10000"; exec psql -X -v ON_ERROR_STOP=1 -Atq -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "$1"' \
    _ "$1"
}
version="$(psql_read 'SHOW server_version_num')"
[[ "$version" =~ ^[0-9]+$ && $((version / 10000)) -eq 17 ]] || {
  echo 'REFUSED: expected PostgreSQL 17' >&2; exit 2
}
table_count="$(psql_read "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_name IN ('app_user','task','task_list','note','sync_operation','sync_change','auth_refresh_session','flyway_schema_history')")"
[[ "$table_count" == 8 ]] || { echo 'REFUSED: schema incomplete' >&2; exit 2; }
user_count="$(psql_read 'SELECT COUNT(*) FROM public.app_user')"
[[ "$user_count" == 1 ]] || {
  echo "REFUSED: expected one TEST account; found $user_count" >&2; exit 2
}
echo 'TARGET: simplenotes PostgreSQL 17, one account'
echo 'PRESERVE: app_user, auth_refresh_session, Flyway history, schema, other apps'
echo 'ERASE: all task/list/note rows (including tombstones) and sync logs'
for table in task task_list note sync_change sync_operation; do
  count="$(psql_read "SELECT COUNT(*) FROM public.$table")"
  printf '%-20s %s\n' "$table" "$count"
done
if [[ "$MODE" == "--preview" ]]; then
  echo 'PREVIEW_ONLY: no writes. Close BOTH app instances before --execute.'
  exit 0
fi
[[ "${ERASE_TEST_WORKSPACE:-}" == ERASE_SIMPLE_NOTES_TEST_WORKSPACE &&
    "${CLIENTS_CLOSED:-}" == YES ]] || {
  echo 'REFUSED: set ERASE_TEST_WORKSPACE=ERASE_SIMPLE_NOTES_TEST_WORKSPACE and CLIENTS_CLOSED=YES' >&2
  exit 2
}
# Same per-account lock as SyncService, atomic PostgreSQL transaction.
docker exec -i "$DB_CONTAINER" sh -eu -c \
  'exec psql -X -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"' <<'SQL'
BEGIN;
SET LOCAL lock_timeout = '10s';
SET LOCAL statement_timeout = '30s';
DO $$
BEGIN
  IF (SELECT COUNT(*) FROM public.app_user) <> 1 THEN
    RAISE EXCEPTION 'Refused: account count changed';
  END IF;
END;
$$;
SELECT pg_advisory_xact_lock(hashtext(id::text)) FROM public.app_user;
DELETE FROM public.sync_operation;
DELETE FROM public.sync_change;
DELETE FROM public.note;
DELETE FROM public.task;
DELETE FROM public.task_list;
COMMIT;
SQL
echo 'SERVER_WORKSPACE_ERASED: clear local SQLite on BOTH devices before opening them.'
