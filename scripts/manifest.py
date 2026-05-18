#!/usr/bin/env python3
"""Validate and query Keel's small YAML manifest subset."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path


REQUIRED_TOOL_KEYS = {
    "name",
    "role",
    "url",
    "ref",
    "ref_type",
    "required",
    "install_type",
    "visibility",
    "public_status",
    "license",
    "health_check",
}

INSTALL_TYPES = {"python-editable", "python-script", "bun-link", "none"}


def parse_value(raw: str) -> object:
    value = raw.strip()
    if value.lower() == "true":
        return True
    if value.lower() == "false":
        return False
    if (value.startswith('"') and value.endswith('"')) or (
        value.startswith("'") and value.endswith("'")
    ):
        return value[1:-1]
    return value


def strip_comment(line: str) -> str:
    in_single = False
    in_double = False
    for idx, char in enumerate(line):
        if char == "'" and not in_double:
            in_single = not in_single
        elif char == '"' and not in_single:
            in_double = not in_double
        elif char == "#" and not in_single and not in_double:
            return line[:idx]
    return line


def load_manifest(path: Path) -> dict[str, object]:
    root: dict[str, object] = {}
    tools: list[dict[str, object]] = []
    current: dict[str, object] | None = None
    in_tools = False

    for line_no, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = strip_comment(raw).rstrip()
        if not line.strip():
            continue
        stripped = line.strip()

        if not line.startswith(" ") and stripped == "tools:":
            in_tools = True
            continue

        if not in_tools and ":" in stripped:
            key, value = stripped.split(":", 1)
            root[key.strip()] = parse_value(value)
            continue

        if in_tools and stripped.startswith("- "):
            if current is not None:
                tools.append(current)
            current = {}
            item = stripped[2:].strip()
            if item:
                if ":" not in item:
                    raise ValueError(f"{path}:{line_no}: invalid list item")
                key, value = item.split(":", 1)
                current[key.strip()] = parse_value(value)
            continue

        if in_tools and current is not None and ":" in stripped:
            key, value = stripped.split(":", 1)
            current[key.strip()] = parse_value(value)
            continue

        raise ValueError(f"{path}:{line_no}: unsupported manifest syntax")

    if current is not None:
        tools.append(current)
    root["tools"] = tools
    return root


def validate(manifest: dict[str, object]) -> list[str]:
    errors: list[str] = []
    if manifest.get("schema") != "keel_tools_manifest_v1":
        errors.append("schema must be keel_tools_manifest_v1")
    tools = manifest.get("tools")
    if not isinstance(tools, list) or not tools:
        errors.append("tools must be a non-empty list")
        return errors

    seen: set[str] = set()
    for idx, tool in enumerate(tools, 1):
        if not isinstance(tool, dict):
            errors.append(f"tool #{idx} must be a mapping")
            continue
        missing = REQUIRED_TOOL_KEYS.difference(tool)
        if missing:
            errors.append(f"tool #{idx} missing keys: {', '.join(sorted(missing))}")
        name = str(tool.get("name", ""))
        if not name:
            errors.append(f"tool #{idx} has empty name")
        if name in seen:
            errors.append(f"duplicate tool name: {name}")
        seen.add(name)
        if tool.get("install_type") not in INSTALL_TYPES:
            errors.append(f"{name}: invalid install_type {tool.get('install_type')!r}")
        if not isinstance(tool.get("required"), bool):
            errors.append(f"{name}: required must be true or false")
        if not str(tool.get("url", "")).startswith("https://github.com/"):
            errors.append(f"{name}: url must be an https GitHub URL")
    return errors


def selected_tools(
    manifest: dict[str, object], include: set[str], all_optional: bool
) -> list[dict[str, object]]:
    tools = manifest["tools"]
    assert isinstance(tools, list)
    selected = []
    for tool in tools:
        assert isinstance(tool, dict)
        if bool(tool["required"]) or all_optional or str(tool["name"]) in include:
            selected.append(tool)
    return selected


def cmd_validate(args: argparse.Namespace) -> int:
    manifest = load_manifest(Path(args.manifest))
    errors = validate(manifest)
    if errors:
        for error in errors:
            print(f"manifest error: {error}", file=sys.stderr)
        return 1
    print("manifest ok")
    return 0


def cmd_list(args: argparse.Namespace) -> int:
    manifest = load_manifest(Path(args.manifest))
    errors = validate(manifest)
    if errors:
        for error in errors:
            print(f"manifest error: {error}", file=sys.stderr)
        return 1
    include = set(args.include or [])
    fields = [
        "name",
        "required",
        "url",
        "ref",
        "install_type",
        "health_check",
        "visibility",
        "public_status",
    ]
    for tool in selected_tools(manifest, include, args.all_optional):
        values = [str(tool.get(field, "")).replace("\t", " ") for field in fields]
        print("\t".join(values))
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", default="tools.manifest.yaml")
    subparsers = parser.add_subparsers(dest="command", required=True)

    validate_parser = subparsers.add_parser("validate")
    validate_parser.set_defaults(func=cmd_validate)

    list_parser = subparsers.add_parser("list")
    list_parser.add_argument("--include", action="append", default=[])
    list_parser.add_argument("--all-optional", action="store_true")
    list_parser.set_defaults(func=cmd_list)

    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
