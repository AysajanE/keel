#!/usr/bin/env python3
"""Check that the public Keel surface does not contain local/private residue."""

from __future__ import annotations

import sys
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
IGNORED_DIRS = {
    ".git",
    ".venv",
    "__pycache__",
    "node_modules",
    "private",
    "tools",
}
TEXT_SUFFIXES = {
    ".bash",
    ".css",
    ".html",
    ".js",
    ".json",
    ".md",
    ".py",
    ".sh",
    ".txt",
    ".yaml",
    ".yml",
}
BANNED_PATTERNS = [
    (re.compile(r"\bshipyard\b", re.IGNORECASE), "legacy project name"),
    (re.compile(r"~/shipyard"), "legacy home path"),
    (re.compile(r"/Users/aeziz-local/shipyard"), "legacy local absolute path"),
    (re.compile(r"\bsy-(compile|run|doctor|swr|cli)\b"), "legacy wrapper name"),
]


def is_ignored(path: Path) -> bool:
    rel = path.relative_to(ROOT)
    return any(part in IGNORED_DIRS for part in rel.parts)


def main() -> int:
    errors: list[str] = []
    for path in ROOT.rglob("*"):
        if is_ignored(path):
            continue
        rel = path.relative_to(ROOT)
        if path.name == ".DS_Store":
            errors.append(f"{rel}: .DS_Store must not be present")
        if path.name == ".env" or path.name.startswith(".env."):
            errors.append(f"{rel}: env files must not be present")
        if path.is_file() and path.suffix in TEXT_SUFFIXES:
            if rel == Path("scripts/public_hygiene.py"):
                continue
            text = path.read_text(encoding="utf-8", errors="ignore")
            for pattern, label in BANNED_PATTERNS:
                if pattern.search(text):
                    errors.append(f"{rel}: banned legacy reference: {label}")
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1
    print("public hygiene ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
