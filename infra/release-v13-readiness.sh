#!/usr/bin/env bash
set -euo pipefail

# Read-only post-deployment gate for V13; does NOT deploy/migrate/restore.
: "${DB_CONTAINER:?Use existing Simple Notes PostgreSQL container}"
: "${T4_BEARER_TOKEN:?Use a short-lived JWT in the environment}"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
API_BASE_URL="${API_BASE_URL:-https://api.notes.ddone.it}"
[[ "$API_BASE_URL" =~ ^https://[a-zA-Z0-9.-]+(:443)?/?$ ]] || {
  echo "REFUSED: HTTPS API origin required" >&2; exit 2
}
for utility in curl python3; do
  command -v "$utility" >/dev/null || { echo "Missing $utility" >&2; exit 2; }
done

echo "Checking exact PostgreSQL 17/Flyway V13 schema (read-only)."
REQUIRE_FLYWAY_VERSION=13 bash "$script_dir/t4-inspect-db.sh"
echo "Checking authenticated capabilities and HTTPS health (read-only)."
REQUIRE_TIME_BLOCK_SCHEMA=1 REQUIRE_FULL_SCHEMA=1 \
  REQUIRE_SYNC_OPERATION_FINGERPRINT_SCHEMA=1 \
  bash "$script_dir/t4-check-api.sh"
echo "Checking GET template catalog (read-only; JWT never printed)."
response="$(
  printf 'header = "Authorization: Bearer %s"\n' "$T4_BEARER_TOKEN" |
    curl --silent --show-error --fail --config - \
      --proto '=https' --tlsv1.2 --connect-timeout 5 --max-time 20 \
      "${API_BASE_URL%/}/api/v1/templates/catalog"
)"
printf '%s' "$response" | python3 -c '
import json,sys
obj=json.load(sys.stdin)
assert type(obj) is dict and set(obj)=={"version","catalog"}
assert type(obj["version"]) is int and obj["version"] >= 0
cat=obj["catalog"]
assert type(cat) is dict and set(cat)=={"schema","templates"}
assert type(cat["schema"]) is int and cat["schema"]==1
assert type(cat["templates"]) is list and len(cat["templates"])<=50
' || { echo "REFUSED: template catalog API incompatible" >&2; exit 1; }
echo "V13_TEMPLATE_CATALOG_READONLY_GATE=PASS"
echo "No data was modified; this does not prove PUT, device sync or release readiness."
