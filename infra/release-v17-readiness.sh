#!/usr/bin/env bash
set -euo pipefail

# Exact V17 post-deploy READ-ONLY gate. No invitations or writes.
: "${DB_CONTAINER:?Specify current Simple Notes PostgreSQL container}"
: "${T4_BEARER_TOKEN:?Keep the JWT only in your administrative shell}"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
echo "Checking PostgreSQL 17, exact Flyway V17, EDITOR role and audit schema."
REQUIRE_FLYWAY_VERSION=17 bash "$script_dir/t4-inspect-db.sh"
echo "Checking HTTPS/JWT capability for EDITOR, without modifying data."
REQUIRE_FULL_SCHEMA=1 REQUIRE_TIME_BLOCK_SCHEMA=1 \
  REQUIRE_SYNC_OPERATION_FINGERPRINT_SCHEMA=1 \
  REQUIRE_SHARING_READ_SCHEMA=1 REQUIRE_SHARING_EDITOR_SCHEMA=1 \
  bash "$script_dir/t4-check-api.sh"
echo "V17_SHARING_EDITOR_READONLY_GATE=PASS"
echo "No live permissions, edits, device tests, deploy or restore performed."
