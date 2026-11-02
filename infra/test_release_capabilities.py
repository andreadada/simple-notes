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
}


def run(value, *, strict=False, blocks=False):
    env = os.environ.copy()
    env["REQUIRE_FULL_SCHEMA"] = "1" if strict else "0"
    env["REQUIRE_TIME_BLOCK_SCHEMA"] = "1" if blocks else "0"
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
