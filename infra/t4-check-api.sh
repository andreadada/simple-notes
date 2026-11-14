#!/usr/bin/env bash
set -euo pipefail
# HTTPS-only READ-ONLY post-deployment probe. Does not modify application data.
# API_BASE_URL=https://api.notes.ddone.it T4_BEARER_TOKEN=<short-lived token> \
#   bash infra/t4-check-api.sh
API_BASE_URL="${API_BASE_URL:-https://api.notes.ddone.it}"
# Keep the T4/V7 probe useful before the release, but allow an explicit
# strict V8 assertion after Coolify is upgraded.
REQUIRE_TIME_BLOCK_SCHEMA="${REQUIRE_TIME_BLOCK_SCHEMA:-0}"
REQUIRE_FULL_SCHEMA="${REQUIRE_FULL_SCHEMA:-0}"
REQUIRE_SYNC_OPERATION_FINGERPRINT_SCHEMA="${REQUIRE_SYNC_OPERATION_FINGERPRINT_SCHEMA:-0}"
REQUIRE_ATTACHMENT_STORAGE="${REQUIRE_ATTACHMENT_STORAGE:-0}"
REQUIRE_SHARING_READ_SCHEMA="${REQUIRE_SHARING_READ_SCHEMA:-0}"
REQUIRE_SHARING_EDITOR_SCHEMA="${REQUIRE_SHARING_EDITOR_SCHEMA:-0}"
REQUIRE_CALENDAR_READ_SCHEMA="${REQUIRE_CALENDAR_READ_SCHEMA:-0}"
REQUIRE_SERVER_REMINDER_SCHEMA="${REQUIRE_SERVER_REMINDER_SCHEMA:-0}"
[[ "$REQUIRE_SERVER_REMINDER_SCHEMA" == 0 || "$REQUIRE_SERVER_REMINDER_SCHEMA" == 1 ]] || {
  echo "REFUSED: REQUIRE_SERVER_REMINDER_SCHEMA must be 0 or 1" >&2; exit 2
}
[[ "$REQUIRE_CALENDAR_READ_SCHEMA" == 0 || "$REQUIRE_CALENDAR_READ_SCHEMA" == 1 ]] || {
  echo "REFUSED: REQUIRE_CALENDAR_READ_SCHEMA must be 0 or 1" >&2; exit 2
}
[[ "$REQUIRE_TIME_BLOCK_SCHEMA" == 0 || "$REQUIRE_TIME_BLOCK_SCHEMA" == 1 ]] || {
  echo "REFUSED: REQUIRE_TIME_BLOCK_SCHEMA must be 0 or 1" >&2; exit 2
}
[[ "$REQUIRE_FULL_SCHEMA" == 0 || "$REQUIRE_FULL_SCHEMA" == 1 ]] || {
  echo "REFUSED: REQUIRE_FULL_SCHEMA must be 0 or 1" >&2; exit 2
}
[[ "$REQUIRE_SYNC_OPERATION_FINGERPRINT_SCHEMA" == 0 ||
   "$REQUIRE_SYNC_OPERATION_FINGERPRINT_SCHEMA" == 1 ]] || {
  echo "REFUSED: REQUIRE_SYNC_OPERATION_FINGERPRINT_SCHEMA must be 0 or 1" >&2
  exit 2
}
[[ "$REQUIRE_SHARING_EDITOR_SCHEMA" == 0 || "$REQUIRE_SHARING_EDITOR_SCHEMA" == 1 ]] || {
  echo "REFUSED: REQUIRE_SHARING_EDITOR_SCHEMA must be 0 or 1" >&2; exit 2
}
[[ "$REQUIRE_SHARING_READ_SCHEMA" == 0 || "$REQUIRE_SHARING_READ_SCHEMA" == 1 ]] || {
  echo "REFUSED: REQUIRE_SHARING_READ_SCHEMA must be 0 or 1" >&2; exit 2
}
[[ "$REQUIRE_ATTACHMENT_STORAGE" == 0 || "$REQUIRE_ATTACHMENT_STORAGE" == 1 ]] || {
  echo "REFUSED: REQUIRE_ATTACHMENT_STORAGE must be 0 or 1" >&2; exit 2
}
: "${T4_BEARER_TOKEN:?A real authenticated user access token is required}"
for command in curl python3; do
  command -v "$command" >/dev/null || { echo "Missing $command" >&2; exit 2; }
done
[[ "$API_BASE_URL" =~ ^https://[a-zA-Z0-9.-]+(:443)?/?$ ]] || {
  echo "REFUSED: API_BASE_URL must be a normal HTTPS origin (no query/path)." >&2
  exit 2
}
base="${API_BASE_URL%/}"
health="$(curl --silent --show-error --fail \
  --proto '=https' --tlsv1.2 --connect-timeout 5 --max-time 20 \
  "$base/actuator/health")"
printf '%s' "$health" | python3 -c '
import json,sys
assert json.load(sys.stdin).get("status") == "UP", "health != UP"
' || { echo "REFUSED: API health is not UP." >&2; exit 1; }
# curl config is supplied on stdin rather than placing the JWT on the command
# line where process inspection could reveal it. Never echo the token.
capabilities="$(
  printf 'header = "Authorization: Bearer %s"\n' "$T4_BEARER_TOKEN" |
    curl --silent --show-error --fail --config - \
      --proto '=https' --tlsv1.2 --connect-timeout 5 --max-time 20 \
      "$base/api/v1/capabilities"
)"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
if ! printf '%s' "$capabilities" |
    REQUIRE_TIME_BLOCK_SCHEMA="$REQUIRE_TIME_BLOCK_SCHEMA" \
    REQUIRE_FULL_SCHEMA="$REQUIRE_FULL_SCHEMA" \
    REQUIRE_SYNC_OPERATION_FINGERPRINT_SCHEMA="$REQUIRE_SYNC_OPERATION_FINGERPRINT_SCHEMA" \
    REQUIRE_ATTACHMENT_STORAGE="$REQUIRE_ATTACHMENT_STORAGE" \
    REQUIRE_SHARING_READ_SCHEMA="$REQUIRE_SHARING_READ_SCHEMA" \
    REQUIRE_SHARING_EDITOR_SCHEMA="$REQUIRE_SHARING_EDITOR_SCHEMA" \
    REQUIRE_CALENDAR_READ_SCHEMA="$REQUIRE_CALENDAR_READ_SCHEMA" \
    REQUIRE_SERVER_REMINDER_SCHEMA="$REQUIRE_SERVER_REMINDER_SCHEMA" \
    python3 "$script_dir/validate-release-capabilities.py"; then
  echo "REFUSED: backend capability contract is incompatible." >&2
  exit 1
fi
echo "PASS: HTTPS health UP and authenticated API capability contract verified."
echo "Required: due=1, time-block=$REQUIRE_TIME_BLOCK_SCHEMA, full=$REQUIRE_FULL_SCHEMA, operation-fingerprint=$REQUIRE_SYNC_OPERATION_FINGERPRINT_SCHEMA, attachments=$REQUIRE_ATTACHMENT_STORAGE, sharing=$REQUIRE_SHARING_READ_SCHEMA, sharing-editor=$REQUIRE_SHARING_EDITOR_SCHEMA, calendar-read=$REQUIRE_CALENDAR_READ_SCHEMA."
echo "This does NOT prove the client sync round-trip or real backup readiness."
