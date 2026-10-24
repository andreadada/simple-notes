#!/usr/bin/env bash
set -euo pipefail

# Restores only into an ephemeral container with no network or published ports.
# Never names or connects to an existing production database.
if [[ "$#" -ne 1 || ! -r "$1" ]]; then
  echo "Usage: $0 /path/to/simple-notes-backup.dump" >&2; exit 2
fi
for cmd in docker sha256sum openssl awk mktemp; do
  command -v "$cmd" >/dev/null || { echo "Missing $cmd" >&2; exit 2; }
done
archive="$(cd -- "$(dirname -- "$1")" && pwd -P)/$(basename -- "$1")"
if [[ ! -s "$archive" || "$(head -c 5 "$archive")" != "PGDMP" ]]; then
  echo "REFUSED: invalid PostgreSQL custom archive." >&2; exit 2
fi
if [[ ! -f "$archive.sha256" ]]; then
  echo "REFUSED: matching .sha256 manifest required." >&2; exit 2
fi
hash="$(sha256sum -- "$archive" | awk '{print $1}')"
expected="$(awk 'NR==1 {print $1}' "$archive.sha256")"
if [[ ! "$expected" =~ ^[[:xdigit:]]{64}$ || "${expected,,}" != "$hash" ]]; then
  echo "REFUSED: SHA256 mismatch; cannot restore untrusted archive." >&2; exit 2
fi

name="simple-notes-restore-check-$$-$(openssl rand -hex 4)"
password="$(openssl rand -hex 24)"
temp=""
cleanup() {
  if [[ -n "$temp" ]]; then rm -f -- "$temp"; fi
  docker rm -f "$name" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# Never mount live volumes or use the production Docker network.
docker run --rm -d --network none --name "$name" \
  -e POSTGRES_PASSWORD="$password" postgres:17-alpine >/dev/null
ready=0
for i in $(seq 1 60); do
  if docker logs "$name" 2>&1 | grep -q 'PostgreSQL init process complete' && \
     docker exec "$name" pg_isready -U postgres -d postgres >/dev/null 2>&1; then
    ready=1; break
  fi
  sleep 1
done
if [[ "$ready" != 1 ]]; then
  echo "Isolated PostgreSQL failed readiness check." >&2; exit 1
fi
# No --clean / --create / production target. Entire restore is transactional.
docker exec -i "$name" pg_restore -U postgres -d postgres \
  --exit-on-error --single-transaction --no-owner --no-privileges < "$archive"

declare -A restored_rows
for table in app_user task note sync_change sync_operation; do
  rows="$(docker exec "$name" psql -X -v ON_ERROR_STOP=1 \
    -U postgres -d postgres -Atqc "SELECT COUNT(*) FROM public.$table;")"
  [[ "$rows" =~ ^[0-9]+$ ]] || {
    echo "REFUSED: restore table count query was not numeric." >&2; exit 1
  }
  restored_rows["$table"]="$rows"
done
# A seemingly valid empty schema is not enough for a production upgrade.
# Simple Notes is an existing project with previously synced Google accounts.
if (( restored_rows[app_user] < 1 )); then
  echo "REFUSED: restored snapshot has no existing users." >&2; exit 1
fi
flyway="absent"
has_flyway="$(docker exec "$name" psql -X -v ON_ERROR_STOP=1 \
  -U postgres -d postgres -Atqc \
  "SELECT CASE WHEN to_regclass('public.flyway_schema_history') IS NOT NULL THEN 1 ELSE 0 END")"
if [[ "$has_flyway" == "1" ]]; then
  flyway="$(docker exec "$name" psql -X -v ON_ERROR_STOP=1 \
    -U postgres -d postgres -Atqc \
    "SELECT COALESCE(MAX(installed_rank),0) FROM public.flyway_schema_history WHERE success")"
fi

receipt="$archive.restore-ok"
umask 077
temp="$(mktemp "$(dirname -- "$archive")/.t4-proof.XXXXXXXX")"
{
  printf 'T4_RECEIPT_VERSION=1\n'
  printf 'ARCHIVE_SHA256=%s\n' "$hash"
  printf 'POSTGRES_IMAGE=postgres:17-alpine\n'
  printf 'CORE_TABLES_VERIFIED=app_user,task,note,sync_change,sync_operation\n'
  for table in app_user task note sync_change sync_operation; do
    printf 'ROW_COUNT_%s=%s\n' "$table" "${restored_rows[$table]}"
  done
  printf 'FLYWAY_MAX_INSTALLED_RANK=%s\n' "$flyway"
  printf 'VERIFIED_UTC=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$temp"
chmod 600 "$temp"
mv -- "$temp" "$receipt"
temp=""
echo "SUCCESS: full isolated restore and core table queries passed."
echo "Receipt: $receipt"
echo "NO production database, persistent volume or network was touched."
