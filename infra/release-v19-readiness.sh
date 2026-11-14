#!/usr/bin/env bash
set -euo pipefail

# Read-only V19 database + authenticated capability gate. Never deploys.
: "${DB_CONTAINER:?Identify the CURRENT Simple Notes PostgreSQL 17 container}"
: "${T4_BEARER_TOKEN:?Set a temporary Simple Notes application access JWT in your shell}"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
echo "Checking exact Flyway V19 PostgreSQL schema."
REQUIRE_FLYWAY_VERSION=19 bash "$script_dir/t4-inspect-db.sh"
echo "Checking HTTPS/health/authenticated API schemas."
REQUIRE_FULL_SCHEMA=1 REQUIRE_TIME_BLOCK_SCHEMA=1 \
  REQUIRE_SYNC_OPERATION_FINGERPRINT_SCHEMA=1 \
  REQUIRE_SHARING_READ_SCHEMA=1 REQUIRE_SHARING_EDITOR_SCHEMA=1 \
  REQUIRE_CALENDAR_READ_SCHEMA=1 REQUIRE_SERVER_REMINDER_SCHEMA=1 \
  bash "$script_dir/t4-check-api.sh"
echo "V19_SERVER_REMINDER_READONLY_GATE=PASS"
echo "No reminder preferences, OAuth grants, task data, deploy or restore changed."
echo "Device delivery/push and real OAuth provider consent are NOT tested."
