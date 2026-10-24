#!/usr/bin/env bash
set -euo pipefail

# Gate only, NEVER deploys anything. Refuse missing/incorrect evidence.
# T4_ARCHIVE=/secure/backups/foo.dump T4_OFFSITE_CONFIRMED=yes \
# T4_APPROVED_COMMIT=<full-40-char-sha> bash infra/t4-preflight.sh
: "${T4_ARCHIVE:?Set T4_ARCHIVE}"
: "${T4_OFFSITE_CONFIRMED:?Set yes only after checking an encrypted offsite copy}"
: "${T4_APPROVED_COMMIT:?Explicitly approve the exact Git commit}"
fail() { echo "NOT READY: $*" >&2; exit 2; }
[[ "$T4_OFFSITE_CONFIRMED" == "yes" ]] || fail "off-server copy not confirmed"
[[ "$T4_APPROVED_COMMIT" =~ ^[[:xdigit:]]{40}$ ]] || fail "full Git SHA required"
for cmd in sha256sum awk git; do
  command -v "$cmd" >/dev/null || fail "missing $cmd"
done
[[ -r "$T4_ARCHIVE" && -r "$T4_ARCHIVE.sha256" &&
   -r "$T4_ARCHIVE.restore-ok" ]] || fail "archive, checksum or restore receipt missing"
actual="$(sha256sum -- "$T4_ARCHIVE" | awk '{print $1}')"
manifest="$(awk 'NR==1 {print $1}' "$T4_ARCHIVE.sha256")"
restored="$(awk -F= '$1=="ARCHIVE_SHA256" {print $2}' "$T4_ARCHIVE.restore-ok")"
tables="$(awk -F= '$1=="CORE_TABLES_VERIFIED" {print $2}' "$T4_ARCHIVE.restore-ok")"
version="$(awk -F= '$1=="T4_RECEIPT_VERSION" {print $2}' "$T4_ARCHIVE.restore-ok")"
[[ "$actual" == "$manifest" && "$actual" == "$restored" ]] ||
  fail "checksum and restore receipt disagree"
[[ "$version" == "1" && "$tables" == "app_user,task,note,sync_change,sync_operation" ]] ||
  fail "restore evidence is missing required checks"
# A stale restore proof must not authorize a future deployment. Re-run the
# isolated restore shortly before the maintenance window.
command -v date >/dev/null || fail "missing date"
T4_MAX_RESTORE_AGE_HOURS="${T4_MAX_RESTORE_AGE_HOURS:-24}"
[[ "$T4_MAX_RESTORE_AGE_HOURS" =~ ^[0-9]+$ ]] ||
  fail "max age must be a positive integer"
(( T4_MAX_RESTORE_AGE_HOURS >= 1 && T4_MAX_RESTORE_AGE_HOURS <= 168 )) ||
  fail "max age must be 1..168 hours"
verified_utc="$(awk -F= '$1=="VERIFIED_UTC" {print $2}' "$T4_ARCHIVE.restore-ok")"
[[ "$verified_utc" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] ||
  fail "restore proof is missing a valid UTC verification time"
verified_epoch="$(date -u -d "$verified_utc" +%s 2>/dev/null)" ||
  fail "could not parse restore time"
now_epoch="$(date -u +%s)"
age_seconds=$(( now_epoch - verified_epoch ))
(( age_seconds >= -120 && age_seconds <= T4_MAX_RESTORE_AGE_HOURS * 3600 )) ||
  fail "restore proof is stale or dated in the future; repeat restore test"
for table in app_user task note sync_change sync_operation; do
  rows="$(awk -F= -v key="ROW_COUNT_$table" '$1==key {print $2}' "$T4_ARCHIVE.restore-ok")"
  [[ "$rows" =~ ^[0-9]+$ ]] || fail "missing numeric restored row count: $table"
  if [[ "$table" == "app_user" ]]; then
    (( rows >= 1 )) || fail "empty restored user table"
  fi
done
head="$(git rev-parse HEAD)"
[[ "${T4_APPROVED_COMMIT,,}" == "${head,,}" ]] ||
  fail "approved commit differs from checked-out HEAD"
[[ -z "$(git status --porcelain)" ]] ||
  fail "working tree is dirty"
echo "PASS: verified local snapshot/restore + manually attested offsite copy."
echo "Commit: $head"
echo "Archive SHA256: $actual"
echo "THIS CHECK DOES NOT DEPLOY, MIGRATE OR VERIFY LIVE API READINESS."
echo "Next MANUAL gate: Coolify deploy and Flyway V7/health/capability validation."
