#!/usr/bin/env bash
set -euo pipefail

# Exact V18 database + authenticated API inspection. Strictly READ ONLY.
# This never creates OAuth grants, fetches external events or changes data.
: "${DB_CONTAINER:?Identify the current Simple Notes PostgreSQL 17 container}"
: "${T4_BEARER_TOKEN:?Use a temporary Simple Notes access JWT in this shell only}"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
echo "Checking PostgreSQL 17, exact Flyway V18 and encrypted calendar link schema."
REQUIRE_FLYWAY_VERSION=18 bash "$script_dir/t4-inspect-db.sh"
echo "Checking HTTPS/JWT authenticated calendar API schema capability."
REQUIRE_FULL_SCHEMA=1 REQUIRE_TIME_BLOCK_SCHEMA=1 \
  REQUIRE_SYNC_OPERATION_FINGERPRINT_SCHEMA=1 \
  REQUIRE_SHARING_READ_SCHEMA=1 REQUIRE_SHARING_EDITOR_SCHEMA=1 \
  REQUIRE_CALENDAR_READ_SCHEMA=1 \
  bash "$script_dir/t4-check-api.sh"
echo "V18_CALENDAR_OAUTH_READONLY_GATE=PASS"
echo "Provider credentials and real consent/event read are NOT validated by this gate."
echo "No live OAuth grants, calendar writes, migrations, deploy or restore performed."
