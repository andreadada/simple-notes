#!/usr/bin/env python3
"""Validate relative links in Markdown without network access."""
from __future__ import annotations

import re
import sys
from pathlib import Path
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parent.parent
LINK = re.compile(r"\]\(([^)\s]+)(?:\s+[\"'][^\"']*[\"'])?\)")
FENCE = re.compile(r"^\s*(\\x60{3,}|~{3,})")
IGNORE_SCHEME = ("http:", "https:", "mailto:", "tel:", "data:", "sandbox:")


def strip_fences(text: str) -> str:
    output = []
    open_mark = ""
    for line in text.splitlines():
        match = FENCE.match(line)
        if match:
            token = match.group(1)
            if not open_mark:
                open_mark = token
            elif token[0] == open_mark[0] and len(token) >= len(open_mark):
                open_mark = ""
            continue
        if not open_mark:
            output.append(line)
    return "\n".join(output)


def check() -> int:
    failures: list[str] = []
    checked = 0
    for doc in sorted(ROOT.rglob("*.md")):
        if any(p in {".git", "build", ".dart_tool", ".gradle"} for p in
               doc.relative_to(ROOT).parts):
            continue
        checked += 1
        contents = strip_fences(doc.read_text(encoding="utf-8"))
        for match in LINK.finditer(contents):
            raw = match.group(1)
            if raw.startswith(("#", "//", "/")) or raw.lower().startswith(IGNORE_SCHEME):
                continue
            if re.match(r"^[a-zA-Z][a-zA-Z0-9+.-]*:", raw):
                continue
            target = unquote(raw.split("#", 1)[0].split("?", 1)[0])
            if not target:
                continue
            resolved = (doc.parent / target).resolve()
            if not resolved.is_relative_to(ROOT) or not resolved.exists():
                failures.append(f"{doc.relative_to(ROOT)}: {raw}")
    if failures:
        print(f"FAILED: {len(failures)} broken relative links:")
        for failure in failures:
            print(f"  {failure}")
        return 1
    print(f"PASS: {checked} Markdown files; relative links resolve.")
    return 0


if __name__ == "__main__":
    sys.exit(check())
