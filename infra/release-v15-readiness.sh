#!/usr/bin/env bash
set -euo pipefail

# Exact V15 post-deploy gate, READ ONLY. No migration or S3 delete.
: "${DB_CONTAINER:?Specify existing Simple Notes PostgreSQL container}"
: "${T4_BEARER_TOKEN:?Keep a short-lived JWT in the environment only}"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
echo "Checking PostgreSQL 17 and exact Flyway V15, read-only."
REQUIRE_FLYWAY_VERSION=15 bash "$script_dir/t4-inspect-db.sh"
echo "Checking HTTPS health and JWT attachment capability."
REQUIRE_FULL_SCHEMA=1 REQUIRE_TIME_BLOCK_SCHEMA=1 \
  REQUIRE_SYNC_OPERATION_FINGERPRINT_SCHEMA=1 REQUIRE_ATTACHMENT_STORAGE=1 \
  bash "$script_dir/t4-check-api.sh"
echo "V15_ATTACHMENTS_READONLY_GATE=PASS"
echo "This does not certify S3 lifecycle, queue draining or actual uploads."
echo "No migration, bucket deletion, restore or deploy performed."
