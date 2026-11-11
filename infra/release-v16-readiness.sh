#!/usr/bin/env bash
set -euo pipefail

# V16 post-deploy READ-ONLY. No migration, invitations or share writes.
: "${DB_CONTAINER:?Specify existing Simple Notes PostgreSQL container}"
: "${T4_BEARER_TOKEN:?Keep a short-lived JWT in environment only}"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
echo "Checking PostgreSQL 17 and exact Flyway V16 (read-only)."
REQUIRE_FLYWAY_VERSION=16 bash "$script_dir/t4-inspect-db.sh"
echo "Checking HTTPS health, JWT and sharing read-schema capability."
REQUIRE_FULL_SCHEMA=1 REQUIRE_TIME_BLOCK_SCHEMA=1 \
  REQUIRE_SYNC_OPERATION_FINGERPRINT_SCHEMA=1 \
  REQUIRE_SHARING_READ_SCHEMA=1 \
  bash "$script_dir/t4-check-api.sh"
echo "V16_SHARING_READONLY_GATE=PASS"
echo "This does not exercise share invitations or permissions end-to-end."
echo "NO migration, account writes, restore, deploy or production action performed."
