#!/usr/bin/env python3
"""Offline synthetic contract tests; never call the network or production."""
import json
import os
from pathlib import Path
import subprocess
import sys
import unittest

SCRIPT = Path(__file__).with_name("validate-release-capabilities.py")
FULL = {
    "taskDueSchema": 1,
    "taskDueKinds": ["none", "date", "datetime", "legacy"],
    "requiresExplicitDueForModernTasks": True,
    "noteRestoreSchema": 1,
    "timeBlockSchema": 1,
    "timeBlocksSchema": 1,
    "recurrenceSchema": 1,
    "syncOperationFingerprintSchema": 1,
}


def run(value, *, strict=False, blocks=False, intent=False, attachments=False, sharing=False, editor=False, calendars=False, reminder=False):
    env = os.environ.copy()
    env["REQUIRE_FULL_SCHEMA"] = "1" if strict else "0"
    env["REQUIRE_TIME_BLOCK_SCHEMA"] = "1" if blocks else "0"
    env["REQUIRE_SYNC_OPERATION_FINGERPRINT_SCHEMA"] = "1" if intent else "0"
    env["REQUIRE_ATTACHMENT_STORAGE"] = "1" if attachments else "0"
    env["REQUIRE_SHARING_READ_SCHEMA"] = "1" if sharing else "0"
    env["REQUIRE_SHARING_EDITOR_SCHEMA"] = "1" if editor else "0"
    env["REQUIRE_CALENDAR_READ_SCHEMA"] = "1" if calendars else "0"
    env["REQUIRE_SERVER_REMINDER_SCHEMA"] = "1" if reminder else "0"
    return subprocess.run(
        [sys.executable, str(SCRIPT)],
        input=json.dumps(value), text=True, capture_output=True, env=env,
        check=False, timeout=5,
    )


class ReleaseCapabilityContract(unittest.TestCase):
    def test_full_v10_is_accepted(self):
        result = run(FULL, strict=True, blocks=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("PASS:", result.stdout)

    def test_v11_fingerprint_contract_is_strictly_opt_in(self):
        self.assertEqual(run(FULL, strict=True, intent=True).returncode, 0)
        older = FULL.copy()
        older.pop("syncOperationFingerprintSchema")
        # Old V10 clients/gates still accept the old schema.
        self.assertEqual(run(older, strict=True).returncode, 0)
        self.assertNotEqual(run(older, strict=True, intent=True).returncode, 0)
        for invalid in (0, "1", True, None, 2, [], {}):
            with self.subTest(value=invalid):
                changed = {**FULL, "syncOperationFingerprintSchema": invalid}
                self.assertNotEqual(
                    run(changed, strict=True, intent=True).returncode, 0
                )
        noisy = {**FULL, "syncOperationFingerprintSchema": "PRIVATE-BODY"}
        result = run(noisy, strict=True, intent=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("PRIVATE-BODY", result.stdout + result.stderr)

    def test_incompatible_version_or_missing_feature_is_refused(self):
        for key in ("taskDueSchema", "timeBlockSchema", "timeBlocksSchema",
                    "recurrenceSchema", "noteRestoreSchema"):
            modified = FULL.copy()
            modified[key] = 0
            with self.subTest(key=key):
                self.assertNotEqual(run(modified, strict=True).returncode, 0)
        modified = FULL.copy()
        del modified["recurrenceSchema"]
        self.assertNotEqual(run(modified, strict=True).returncode, 0)

    def test_old_t4_probe_still_accepts_historical_contract(self):
        old = {key: FULL[key] for key in (
            "taskDueSchema", "taskDueKinds", "requiresExplicitDueForModernTasks")}
        self.assertEqual(run(old).returncode, 0)
        self.assertNotEqual(run(old, strict=True).returncode, 0)
        self.assertNotEqual(run(old, blocks=True).returncode, 0)

    def test_v14_attachment_storage_must_be_enabled_to_pass_strict_gate(self):
        enabled = {**FULL, "attachmentSchema": 1, "attachmentStorageEnabled": True}
        self.assertEqual(run(enabled, strict=True, attachments=True).returncode, 0)
        # Earlier release gates remain compatible with no attachment capability.
        self.assertEqual(run(FULL, strict=True).returncode, 0)
        for value in (False, 0, 1, "true", None):
            with self.subTest(value=value):
                bad = {**enabled, "attachmentStorageEnabled": value}
                self.assertNotEqual(
                    run(bad, strict=True, attachments=True).returncode, 0)
        for value in (True, 0, 2, "1", None):
            with self.subTest(schema=value):
                bad = {**enabled, "attachmentSchema": value}
                self.assertNotEqual(
                    run(bad, strict=True, attachments=True).returncode, 0)

    def test_v16_sharing_capability_is_strictly_opt_in(self):
        enabled = {**FULL, "sharingReadSchema": 1}
        self.assertEqual(run(enabled, strict=True, sharing=True).returncode, 0)
        self.assertEqual(run(FULL, strict=True).returncode, 0)
        self.assertNotEqual(run(FULL, strict=True, sharing=True).returncode, 0)
        for invalid in (0, True, "1", 2, [], None):
            with self.subTest(value=invalid):
                self.assertNotEqual(
                    run({**FULL, "sharingReadSchema": invalid},
                        strict=True, sharing=True).returncode, 0
                )

    def test_v17_editor_capability_requires_both_schemas(self):
        enabled = {**FULL, "sharingReadSchema": 1, "sharingEditorSchema": 1}
        self.assertEqual(run(enabled, strict=True, editor=True).returncode, 0)
        self.assertEqual(run(FULL, strict=True).returncode, 0)
        for invalid in (0, True, "1", 2, [], None):
            with self.subTest(value=invalid):
                self.assertNotEqual(
                    run({**enabled, "sharingEditorSchema": invalid},
                        strict=True, editor=True).returncode, 0
                )
        self.assertNotEqual(
            run({**FULL, "sharingEditorSchema": 1},
                strict=True, editor=True).returncode, 0
        )

    def test_v18_calendars_capability_is_opt_in(self):
        enabled = {**FULL, "calendarReadSchema": 1}
        self.assertEqual(run(enabled, strict=True, calendars=True).returncode, 0)
        self.assertEqual(run(FULL, strict=True).returncode, 0)
        self.assertNotEqual(run(FULL, strict=True, calendars=True).returncode, 0)
        for invalid in (True, None, "1", 0, 2, []):
            self.assertNotEqual(run({**FULL, "calendarReadSchema": invalid},
                                    strict=True, calendars=True).returncode, 0)

    def test_v19_server_reminder_capability_opt_in(self):
        enabled = {**FULL, "serverReminderSchema": 1}
        self.assertEqual(run(enabled, strict=True, reminder=True).returncode, 0)
        self.assertEqual(run(FULL, strict=True).returncode, 0)
        self.assertNotEqual(run(FULL, strict=True, reminder=True).returncode, 0)
        for invalid in (True, None, "1", 0, 2, []):
            self.assertNotEqual(run({**FULL, "serverReminderSchema": invalid},
                                    strict=True, reminder=True).returncode, 0)

    def test_unexpected_types_and_missing_due_kinds_fail_closed(self):
        for input_value in (
            None, {}, [], {"taskDueSchema": True}, {**FULL, "taskDueSchema": True},
            {**FULL, "taskDueKinds": "date"},
            {**FULL, "taskDueKinds": ["none", "date", "datetime", "legacy", 1]},
            {**FULL, "requiresExplicitDueForModernTasks": 1},
            {**FULL, "timeBlocksSchema": "1"},
        ):
            with self.subTest(value=input_value):
                self.assertNotEqual(run(input_value, strict=True).returncode, 0)

    def test_invalid_or_sensitive_payload_is_not_echoed(self):
        data = {**FULL, "recurrenceSchema": 2,
                "debug": "SECRET-DO-NOT-LEAK"}
        result = run(data, strict=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("SECRET-DO-NOT-LEAK", result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
