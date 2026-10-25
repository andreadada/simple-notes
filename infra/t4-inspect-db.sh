#!/usr/bin/env bash
set -euo pipefail

# T4 READ-ONLY source database inspection. NEVER migrates or restarts anything.
# Run ON the VPS using the explicitly inspected Simple Notes container.
: "${DB_CONTAINER:?Set DB_CONTAINER to the Simple Notes PostgreSQL container}"
EXPECTED_POSTGRES_DB="${EXPECTED_POSTGRES_DB:-simplenotes}"
command -v docker >/dev/null || { echo "docker is required" >&2; exit 2; }

actual_db="$(docker exec "$DB_CONTAINER" sh -c 'printf "%s" "${POSTGRES_DB:-}"')"
[[ "$actual_db" == "$EXPECTED_POSTGRES_DB" && -n "$actual_db" ]] || {
  echo "REFUSED: selected container does not advertise expected DB name" >&2
  exit 2
}
running="$(docker inspect --format '{{.State.Running}}' "$DB_CONTAINER")"
[[ "$running" == "true" ]] || { echo "REFUSED: DB container not running" >&2; exit 2; }

query() {
  docker exec "$DB_CONTAINER" sh -eu -c \
    'exec psql -X -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atqc "$1"' \
    _ "$1"
}

# All SQL queries only SELECT catalog data or COUNT(*).
version="$(query "SELECT current_setting('server_version_num')")"
[[ "$version" =~ ^[0-9]+$ ]] || { echo "REFUSED: DB version unknown" >&2; exit 2; }
major=$(( version / 10000 ))
[[ "$major" -eq 17 ]] || { echo "REFUSED: expected PostgreSQL 17, found $major" >&2; exit 2; }
names="$(query "SELECT COUNT(*) FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relkind IN ('r','p') AND c.relname IN ('app_user','task','note','sync_change','sync_operation','flyway_schema_history')")"
[[ "$names" == "6" ]] || { echo "REFUSED: expected Simple Notes schema tables missing" >&2; exit 2; }
failed="$(query "SELECT COUNT(*) FROM public.flyway_schema_history WHERE NOT success")"
[[ "$failed" == "0" ]] || { echo "REFUSED: Flyway history has failed migrations" >&2; exit 2; }
latest="$(query "SELECT COALESCE((SELECT version FROM public.flyway_schema_history WHERE success AND version IS NOT NULL ORDER BY installed_rank DESC LIMIT 1),'unknown')")"
[[ "$latest" =~ ^[0-9]+$ && "$latest" -ge 1 && "$latest" -le 8 ]] || {
  echo "REFUSED: unknown, unsupported or unexpected Flyway version" >&2; exit 2
}
due_columns="$(query "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema='public' AND table_name='task' AND column_name IN ('due_kind','due_date','due_time','due_timezone','due_offset_seconds')")"
[[ "$due_columns" == "0" || "$due_columns" == "5" ]] || {
  echo "REFUSED: partially migrated task due columns" >&2; exit 2
}
if [[ "$latest" == "7" && "$due_columns" != "5" ]]; then
  echo "REFUSED: V7 is in Flyway history but columns are missing" >&2; exit 2
fi
if [[ "$latest" -lt 7 && "$due_columns" != "0" ]]; then
  echo "REFUSED: typed due columns exist before Flyway V7" >&2; exit 2
fi
block_columns="$(query "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema='public' AND table_name='task' AND column_name IN ('block_start_at','block_end_at','block_timezone')")"
[[ "$block_columns" == "0" || "$block_columns" == "3" ]] || {
  echo "REFUSED: incomplete time-block migration columns" >&2; exit 2
}
if [[ "$latest" == "8" && "$block_columns" != "3" ]]; then
  echo "REFUSED: Flyway V8 present but time-block columns missing" >&2; exit 2
fi
if [[ "$latest" -lt 8 && "$block_columns" != "0" ]]; then
  echo "REFUSED: V8 columns present before successful Flyway V8" >&2; exit 2
fi

printf 'T4_SOURCE_INSPECTION=PASS\n'
printf 'DB_NAME=%s\nPOSTGRES_MAJOR=%s\nFLYWAY_LATEST=%s\n' \
  "$actual_db" "$major" "$latest"
printf 'DUE_COLUMNS=%s\nBLOCK_COLUMNS=%s\nFAILED_MIGRATIONS=0\n' "$due_columns" "$block_columns"
for table in app_user task note sync_change sync_operation; do
  count="$(query "SELECT COUNT(*) FROM public.$table")"
  [[ "$count" =~ ^[0-9]+$ ]] || { echo "REFUSED: invalid row count" >&2; exit 2; }
  printf 'ROW_COUNT_%s=%s\n' "$table" "$count"
done
echo "Read-only source inspection complete. NO backup, restore or deploy performed."
