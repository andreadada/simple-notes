#!/usr/bin/env bash
set -euo pipefail

# Cumulative release VERIFY-only gate: no migration, backup, deploy, restore,
# application installation, database writes or local device changes.
# Run on the VPS after a separately authorized, non-destructive server upgrade.
# DB_CONTAINER and T4_BEARER_TOKEN must be supplied explicitly at runtime.
: "${DB_CONTAINER:?Specify the existing Simple Notes PostgreSQL container}"
: "${T4_BEARER_TOKEN:?Supply a short-lived user JWT in the process environment}"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
[[ -f "$script_dir/t4-inspect-db.sh" &&
   -f "$script_dir/t4-check-api.sh" ]] || {
  echo "REFUSED: required read-only inspector scripts not found." >&2
  exit 2
}
echo "Checking database schema and metadata (READ ONLY)."
REQUIRE_FLYWAY_VERSION=10 bash "$script_dir/t4-inspect-db.sh"
echo "Checking public health and authenticated API contract (READ ONLY)."
REQUIRE_TIME_BLOCK_SCHEMA=1 REQUIRE_FULL_SCHEMA=1 \
  bash "$script_dir/t4-check-api.sh"
echo "RELEASE_SERVER_GATE=PASS"
echo "This only verifies V10 schema + health + capability; it does NOT approve"
echo "a deploy, a restore, an installation, or Windows/Android acceptance tests."
