#!/usr/bin/env bash
set -euo pipefail

# T4 READ-ONLY source database inspection. NEVER migrates or restarts anything.
# Run ON the VPS using the explicitly inspected Simple Notes container.
: "${DB_CONTAINER:?Set DB_CONTAINER to the Simple Notes PostgreSQL container}"
EXPECTED_POSTGRES_DB="${EXPECTED_POSTGRES_DB:-simplenotes}"
# Optional exact-version gate for cumulative V10–V13 releases.
# Empty keeps historical T4 inspections backward-compatible/read-only.
REQUIRE_FLYWAY_VERSION="${REQUIRE_FLYWAY_VERSION:-}"
if [[ -n "$REQUIRE_FLYWAY_VERSION" &&
      ! "$REQUIRE_FLYWAY_VERSION" =~ ^([1-9]|1[0-3])$ ]]; then
  echo "REFUSED: REQUIRE_FLYWAY_VERSION must be an integer from 1 to 13" >&2
  exit 2
fi
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
[[ "$latest" =~ ^[0-9]+$ && "$latest" -ge 1 && "$latest" -le 13 ]] || {
  echo "REFUSED: unknown, unsupported or unexpected Flyway version" >&2; exit 2
}
due_columns="$(query "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema='public' AND table_name='task' AND column_name IN ('due_kind','due_date','due_time','due_timezone','due_offset_seconds')")"
[[ "$due_columns" == "0" || "$due_columns" == "5" ]] || {
  echo "REFUSED: partially migrated task due columns" >&2; exit 2
}
if [[ "$latest" -ge 7 && "$due_columns" != "5" ]]; then
  echo "REFUSED: Flyway V7+ present but due columns are missing" >&2; exit 2
fi
if [[ "$latest" -lt 7 && "$due_columns" != "0" ]]; then
  echo "REFUSED: typed due columns exist before Flyway V7" >&2; exit 2
fi
block_columns="$(query "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema='public' AND table_name='task' AND column_name IN ('block_start_at','block_end_at','block_timezone')")"
[[ "$block_columns" == "0" || "$block_columns" == "3" ]] || {
  echo "REFUSED: incomplete time-block migration columns" >&2; exit 2
}
if [[ "$latest" -ge 8 && "$block_columns" != "3" ]]; then
  echo "REFUSED: Flyway V8+ present but time-block columns missing" >&2; exit 2
fi
if [[ "$latest" -lt 8 && "$block_columns" != "0" ]]; then
  echo "REFUSED: V8 columns present before successful Flyway V8" >&2; exit 2
fi
blocks_json_columns="$(query "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema='public' AND table_name='task' AND column_name='blocks_json'")"
if [[ "$latest" -ge 9 && "$blocks_json_columns" != "1" ]]; then
  echo "REFUSED: Flyway V9 missing time block collection column" >&2; exit 2
fi
if [[ "$latest" -lt 9 && "$blocks_json_columns" != "0" ]]; then
  echo "REFUSED: V9 column present before successful migration" >&2; exit 2
fi
recurrence_columns="$(query "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema='public' AND table_name='task' AND column_name='recurrence_json'")"
if [[ "$latest" -ge 10 && "$recurrence_columns" != "1" ]]; then
  echo "REFUSED: Flyway V10 missing recurrence column" >&2; exit 2
fi
if [[ "$latest" -lt 10 && "$recurrence_columns" != "0" ]]; then
  echo "REFUSED: V10 column present before successful migration" >&2; exit 2
fi
# Flyway V11 is an additive nullable fingerprint on sync_operation.
# Validate presence, shape and stored format only; never return actual values.
fingerprint_columns="$(query "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema='public' AND table_name='sync_operation' AND column_name='request_fingerprint'")"
if [[ "$latest" -ge 11 ]]; then
  [[ "$fingerprint_columns" == "1" ]] || {
    echo "REFUSED: V11 history has no fingerprint column" >&2; exit 2
  }
  fingerprint_schema="$(query "SELECT CASE WHEN data_type='character varying' AND character_maximum_length=64 AND is_nullable='YES' THEN 'PASS' ELSE 'INVALID' END FROM information_schema.columns WHERE table_schema='public' AND table_name='sync_operation' AND column_name='request_fingerprint'")"
  [[ "$fingerprint_schema" == "PASS" ]] || {
    echo "REFUSED: incompatible V11 fingerprint column shape" >&2; exit 2
  }
  invalid_fingerprints="$(query "SELECT COUNT(*) FROM public.sync_operation WHERE request_fingerprint IS NOT NULL AND request_fingerprint !~ '^[0-9a-f]{64}$'")"
  [[ "$invalid_fingerprints" == "0" ]] || {
    echo "REFUSED: unexpected stored fingerprint format" >&2; exit 2
  }
else
  [[ "$fingerprint_columns" == "0" ]] || {
    echo "REFUSED: V11 column exists without successful Flyway V11 history" >&2; exit 2
  }
fi

# V12 and V13 are separate account-scoped catalogs, no task migrations.
# Check table presence and the exact required field set read-only.
for schema in "12:task_action_catalog" "13:user_template_catalog"; do
  version_required="${schema%%:*}"
  name="${schema#*:}"
  table_exists="$(query "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_name='$name' AND table_type='BASE TABLE'")"
  columns="$(query "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema='public' AND table_name='$name' AND column_name IN ('owner_id','payload_json','version','updated_at')")"
  if [[ "$latest" -ge "$version_required" ]]; then
    [[ "$table_exists" == "1" && "$columns" == "4" ]] || {
      echo "REFUSED: Flyway V$version_required catalog schema incomplete" >&2
      exit 2
    }
  else
    [[ "$table_exists" == "0" && "$columns" == "0" ]] || {
      echo "REFUSED: catalog from future Flyway history present" >&2
      exit 2
    }
  fi
done

if [[ -n "$REQUIRE_FLYWAY_VERSION" &&
      "$latest" != "$REQUIRE_FLYWAY_VERSION" ]]; then
  echo "REFUSED: expected Flyway V$REQUIRE_FLYWAY_VERSION, found V$latest" >&2
  exit 2
fi

printf 'T4_SOURCE_INSPECTION=PASS\n'
printf 'DB_NAME=%s\nPOSTGRES_MAJOR=%s\nFLYWAY_LATEST=%s\n' \
  "$actual_db" "$major" "$latest"
printf 'DUE_COLUMNS=%s\nBLOCK_COLUMNS=%s\nBLOCKS_JSON_COLUMNS=%s\nRECURRENCE_COLUMNS=%s\nFAILED_MIGRATIONS=0\n' "$due_columns" "$block_columns" "$blocks_json_columns" "$recurrence_columns"
printf 'FINGERPRINT_COLUMNS=%s\n' "$fingerprint_columns"
if [[ -n "$REQUIRE_FLYWAY_VERSION" ]]; then
  printf 'FLYWAY_REQUIREMENT=PASS (V%s)\n' "$REQUIRE_FLYWAY_VERSION"
fi
for table in app_user task note sync_change sync_operation; do
  count="$(query "SELECT COUNT(*) FROM public.$table")"
  [[ "$count" =~ ^[0-9]+$ ]] || { echo "REFUSED: invalid row count" >&2; exit 2; }
  printf 'ROW_COUNT_%s=%s\n' "$table" "$count"
done
echo "Read-only source inspection complete. NO backup, restore or deploy performed."
