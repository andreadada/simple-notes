#!/usr/bin/env bash
set -euo pipefail

# P2.4B2P: post-deploy V11 verification ONLY.
# This does not deploy, migrate, dump, restore, create users or change data.
: "${DB_CONTAINER:?Specify the existing Simple Notes PostgreSQL container}"
: "${T4_BEARER_TOKEN:?Set a short-lived JWT in the process environment, never in chat}"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
[[ -f "$script_dir/t4-inspect-db.sh" && -f "$script_dir/t4-check-api.sh" ]] || {
  echo "REFUSED: read-only inspection scripts are missing" >&2; exit 2
}
echo "Verifying exact Flyway V11 / PostgreSQL 17 schema (READ ONLY)."
REQUIRE_FLYWAY_VERSION=11 bash "$script_dir/t4-inspect-db.sh"
echo "Verifying HTTPS health and authenticated capability contract (READ ONLY)."
REQUIRE_TIME_BLOCK_SCHEMA=1 REQUIRE_FULL_SCHEMA=1 bash "$script_dir/t4-check-api.sh"
echo "V11_SERVER_READONLY_GATE=PASS"
echo "CAUTION: this does not prove runtime intent hashing, live sync, device E2E,"
echo "authorization for restore, or release approval. No data was modified."
