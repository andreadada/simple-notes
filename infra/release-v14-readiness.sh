#!/usr/bin/env bash
set -euo pipefail

# V14 post-deploy READ-ONLY. No migrations, object writes, deletes or restore.
: "${DB_CONTAINER:?Specify existing Simple Notes PostgreSQL container}"
: "${T4_BEARER_TOKEN:?Use a short-lived JWT in environment, never in chat}"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
echo "Checking PostgreSQL 17 and exact Flyway V14 (read-only)."
REQUIRE_FLYWAY_VERSION=14 bash "$script_dir/t4-inspect-db.sh"
echo "Checking HTTPS health, JWT capabilities and configured attachment storage."
REQUIRE_FULL_SCHEMA=1 REQUIRE_TIME_BLOCK_SCHEMA=1 \
  REQUIRE_SYNC_OPERATION_FINGERPRINT_SCHEMA=1 REQUIRE_ATTACHMENT_STORAGE=1 \
  bash "$script_dir/t4-check-api.sh"
echo "V14_ATTACHMENTS_READONLY_GATE=PASS"
echo "This does not inspect S3 bucket policies, lifecycle or actual upload/download."
echo "NO bucket operation, migration, restoration or data modification performed."
