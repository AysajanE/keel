#!/usr/bin/env python3
"""Validate and query Keel's small YAML manifest subset."""

from __future__ import annotations

import argparse
import re
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
REF_TYPES = {"commit", "tag", "branch"}
VISIBILITIES = {"public", "private"}
PUBLIC_STATUSES = {
    "installable",
    "optional",
    "blocker_until_repository_is_public",
}
HEALTH_CHECK_PATTERNS = [
    re.compile(r"^python3 [A-Za-z0-9_./-]+\.py --help$"),
    re.compile(r"^bun --version$"),
]


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
        if tool.get("ref_type") not in REF_TYPES:
            errors.append(f"{name}: invalid ref_type {tool.get('ref_type')!r}")
        if tool.get("visibility") not in VISIBILITIES:
            errors.append(f"{name}: invalid visibility {tool.get('visibility')!r}")
        if tool.get("public_status") not in PUBLIC_STATUSES:
            errors.append(f"{name}: invalid public_status {tool.get('public_status')!r}")
        if not isinstance(tool.get("required"), bool):
            errors.append(f"{name}: required must be true or false")
        if not str(tool.get("url", "")).startswith("https://github.com/"):
            errors.append(f"{name}: url must be an https GitHub URL")
        health_check = str(tool.get("health_check", ""))
        if "\t" in health_check or "\n" in health_check:
            errors.append(f"{name}: health_check must be a single-line command")
        if not any(pattern.fullmatch(health_check) for pattern in HEALTH_CHECK_PATTERNS):
            errors.append(f"{name}: health_check is not in the allowed command set")
        if ".." in health_check or health_check.startswith("/"):
            errors.append(f"{name}: health_check must not use absolute or parent paths")
    return errors


def selected_tools(
    manifest: dict[str, object],
    include: set[str],
    all_optional: bool,
    public_only: bool = False,
) -> list[dict[str, object]]:
    tools = manifest["tools"]
    if not isinstance(tools, list):
        raise TypeError("tools must be a list")
    selected = []
    for tool in tools:
        if not isinstance(tool, dict):
            raise TypeError("each tool must be a mapping")
        if public_only and tool.get("visibility") != "public":
            continue
        if bool(tool["required"]) or all_optional or str(tool["name"]) in include:
            selected.append(tool)
    return selected


def release_gate_errors(manifest: dict[str, object]) -> list[str]:
    errors: list[str] = []
    tools = manifest.get("tools")
    if not isinstance(tools, list):
        return ["tools must be a list"]
    for tool in tools:
        if not isinstance(tool, dict):
            errors.append("each tool must be a mapping")
            continue
        name = str(tool.get("name", "<unknown>"))
        if tool.get("ref_type") != "tag":
            errors.append(f"{name}: release manifest refs must be tags")
        public_status = str(tool.get("public_status", ""))
        if public_status.startswith("blocker_"):
            errors.append(f"{name}: release manifest cannot contain blocker status")
        if bool(tool.get("required")) and tool.get("visibility") != "public":
            errors.append(f"{name}: required release tools must be public")
    return errors


def cmd_validate(args: argparse.Namespace) -> int:
    manifest = load_manifest(Path(args.manifest))
    errors = validate(manifest)
    if args.release_gate:
        errors.extend(release_gate_errors(manifest))
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
    tools = manifest.get("tools", [])
    if not isinstance(tools, list):
        print("manifest error: tools must be a list", file=sys.stderr)
        return 1
    available = {
        str(tool.get("name"))
        for tool in tools
        if isinstance(tool, dict) and tool.get("name")
    }
    unknown = sorted(include.difference(available))
    if unknown:
        print(f"manifest error: unknown --include tool(s): {', '.join(unknown)}", file=sys.stderr)
        return 1
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
    for tool in selected_tools(manifest, include, args.all_optional, args.public_only):
        values = [str(tool.get(field, "")).replace("\t", " ") for field in fields]
        print("\t".join(values))
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", default="tools.manifest.yaml")
    subparsers = parser.add_subparsers(dest="command", required=True)

    validate_parser = subparsers.add_parser("validate")
    validate_parser.add_argument("--release-gate", action="store_true")
    validate_parser.set_defaults(func=cmd_validate)

    list_parser = subparsers.add_parser("list")
    list_parser.add_argument("--include", action="append", default=[])
    list_parser.add_argument("--all-optional", action="store_true")
    list_parser.add_argument("--public-only", action="store_true")
    list_parser.set_defaults(func=cmd_list)

    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
