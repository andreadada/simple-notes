#!/usr/bin/env python3
"""Validate authenticated API capability JSON without logging any payload.

STDIN is untrusted response data. The program prints only a stable PASS or a
generic REFUSED message; never echoes token, response content, or user data.
"""
import json
import os
import sys


def refuse() -> None:
    print("REFUSED: authenticated backend capability contract is incompatible.", file=sys.stderr)
    raise SystemExit(1)


def run() -> None:
    try:
        obj = json.load(sys.stdin)
        if not isinstance(obj, dict):
            refuse()
        def has_version_one(key: str) -> bool:
            value = obj.get(key)
            return type(value) is int and value == 1

        if not has_version_one("taskDueSchema"):
            refuse()
        kinds = obj.get("taskDueKinds")
        if not isinstance(kinds, list) or not all(isinstance(x, str) for x in kinds):
            refuse()
        if not {"none", "date", "datetime", "legacy"}.issubset(set(kinds)):
            refuse()
        if obj.get("requiresExplicitDueForModernTasks") is not True:
            refuse()
        intent = os.environ.get("REQUIRE_SYNC_OPERATION_FINGERPRINT_SCHEMA", "0")
        if intent not in ("0", "1"):
            refuse()
        if intent == "1" and not has_version_one("syncOperationFingerprintSchema"):
            refuse()
        attachment = os.environ.get("REQUIRE_ATTACHMENT_STORAGE", "0")
        if attachment not in ("0", "1"):
            refuse()
        if attachment == "1":
            if not has_version_one("attachmentSchema") or obj.get("attachmentStorageEnabled") is not True:
                refuse()
        sharing = os.environ.get("REQUIRE_SHARING_READ_SCHEMA", "0")
        if sharing not in ("0", "1"):
            refuse()
        if sharing == "1" and not has_version_one("sharingReadSchema"):
            refuse()
        editor = os.environ.get("REQUIRE_SHARING_EDITOR_SCHEMA", "0")
        if editor not in ("0", "1"):
            refuse()
        if editor == "1" and (
            not has_version_one("sharingReadSchema")
            or not has_version_one("sharingEditorSchema")
        ):
            refuse()
        calendars = os.environ.get("REQUIRE_CALENDAR_READ_SCHEMA", "0")
        if calendars not in ("0", "1"):
            refuse()
        if calendars == "1" and not has_version_one("calendarReadSchema"):
            refuse()
        inbox = os.environ.get("REQUIRE_SERVER_REMINDER_SCHEMA", "0")
        if inbox not in ("0", "1"):
            refuse()
        if inbox == "1" and not has_version_one("serverReminderSchema"):
            refuse()
        strict = os.environ.get("REQUIRE_FULL_SCHEMA", "0")
        time_block = os.environ.get("REQUIRE_TIME_BLOCK_SCHEMA", "0")
        if strict not in ("0", "1") or time_block not in ("0", "1"):
            refuse()
        if strict == "1" or time_block == "1":
            if not has_version_one("timeBlockSchema") or not has_version_one("noteRestoreSchema"):
                refuse()
        if strict == "1":
            if not has_version_one("timeBlocksSchema") or not has_version_one("recurrenceSchema"):
                refuse()
    except (ValueError, TypeError, KeyError, OverflowError):
        refuse()
    print("PASS: authenticated capability response matches requested schemas.")


if __name__ == "__main__":
    run()
