#!/bin/bash
set -euo pipefail
: "${DB_CONTAINER:?Identify the CURRENT Simple Notes PostgreSQL container}"
: "${T4_BEARER_TOKEN:?Set a temporary application JWT}"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REQUIRE_FLYWAY_VERSION=20 bash "$script_dir/t4-inspect-db.sh"
REQUIRE_FULL_SCHEMA=1 REQUIRE_SYNC_OPERATION_FINGERPRINT_SCHEMA=1 REQUIRE_SHARING_EDITOR_SCHEMA=1 REQUIRE_CALENDAR_READ_SCHEMA=1 REQUIRE_SERVER_REMINDER_SCHEMA=1 REQUIRE_WEB_PREFERENCES_SCHEMA=1 REQUIRE_PORTABLE_IMPORT_SCHEMA=1 bash "$script_dir/t4-check-api.sh"
echo "V20_WEB_READONLY_GATE=PASS"
