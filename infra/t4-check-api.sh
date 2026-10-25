#!/usr/bin/env bash
set -euo pipefail
# HTTPS-only READ-ONLY post-deployment probe. Does not modify application data.
# API_BASE_URL=https://api.notes.ddone.it T4_BEARER_TOKEN=<short-lived token> \
#   bash infra/t4-check-api.sh
API_BASE_URL="${API_BASE_URL:-https://api.notes.ddone.it}"
# Keep the T4/V7 probe useful before the release, but allow an explicit
# strict V8 assertion after Coolify is upgraded.
REQUIRE_TIME_BLOCK_SCHEMA="${REQUIRE_TIME_BLOCK_SCHEMA:-0}"
[[ "$REQUIRE_TIME_BLOCK_SCHEMA" == 0 || "$REQUIRE_TIME_BLOCK_SCHEMA" == 1 ]] || {
  echo "REFUSED: REQUIRE_TIME_BLOCK_SCHEMA must be 0 or 1" >&2; exit 2
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
printf '%s' "$capabilities" | REQUIRE_TIME_BLOCK_SCHEMA="$REQUIRE_TIME_BLOCK_SCHEMA" python3 -c '
import json,sys,os
obj=json.load(sys.stdin)
assert obj.get("taskDueSchema") == 1, "backend missing taskDueSchema:1"
kinds=set(obj.get("taskDueKinds",[]))
assert {"none","date","datetime","legacy"}.issubset(kinds), "missing due kinds"
assert obj.get("requiresExplicitDueForModernTasks") is True, "missing upgrade protection"
if os.environ["REQUIRE_TIME_BLOCK_SCHEMA"] == "1":
    assert obj.get("timeBlockSchema") == 1, "backend missing timeBlockSchema:1"
    assert obj.get("noteRestoreSchema") == 1, "backend missing noteRestoreSchema:1"
' || { echo "REFUSED: backend capability contract is incompatible." >&2; exit 1; }
echo "PASS: HTTPS health UP and authenticated taskDueSchema=1 validated (require time blocks: $REQUIRE_TIME_BLOCK_SCHEMA)."
echo "This does NOT prove the client sync round-trip or real backup readiness."
