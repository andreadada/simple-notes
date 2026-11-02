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
        if obj.get("taskDueSchema") != 1:
            refuse()
        kinds = obj.get("taskDueKinds")
        if not isinstance(kinds, list) or not all(isinstance(x, str) for x in kinds):
            refuse()
        if not {"none", "date", "datetime", "legacy"}.issubset(set(kinds)):
            refuse()
        if obj.get("requiresExplicitDueForModernTasks") is not True:
            refuse()
        strict = os.environ.get("REQUIRE_FULL_SCHEMA", "0")
        time_block = os.environ.get("REQUIRE_TIME_BLOCK_SCHEMA", "0")
        if strict not in ("0", "1") or time_block not in ("0", "1"):
            refuse()
        if strict == "1" or time_block == "1":
            if obj.get("timeBlockSchema") != 1 or obj.get("noteRestoreSchema") != 1:
                refuse()
        if strict == "1":
            if obj.get("timeBlocksSchema") != 1 or obj.get("recurrenceSchema") != 1:
                refuse()
    except (ValueError, TypeError, KeyError, OverflowError):
        refuse()
    print("PASS: authenticated capability response matches requested schemas.")


if __name__ == "__main__":
    run()
