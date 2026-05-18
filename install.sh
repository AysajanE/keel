#!/usr/bin/env bash
set -euo pipefail

KEEL_ROOT="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$KEEL_ROOT/tools.manifest.yaml"
KEEL_PYTHON_MINIMUM="3.10"

include_tools=()
all_optional=0
public_only=0
skip_tools=0
update_tools=0
check_only=0
release_gate=0

usage() {
  cat <<'EOF'
usage: ./install.sh [options]

Options:
  --with <tool>       Install an optional tool from tools.manifest.yaml.
  --all-optional      Install every optional tool.
  --public-only       Install only public tools from the manifest.
  --skip-tools        Only write local Keel env/lock files; do not clone tools.
  --update-tools      Fetch and checkout manifest refs for clean existing tools.
  --check             Validate scripts and manifest only; do not write or clone.
  --release-gate      Enforce release-quality manifest constraints during validation.
  -h, --help          Show this help.

Examples:
  ./install.sh
  ./install.sh --with gbrain
  ./install.sh --skip-tools
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --with)
      [ "$#" -ge 2 ] || { echo "--with requires a tool name" >&2; exit 2; }
      include_tools+=("$2")
      shift 2
      ;;
    --all-optional)
      all_optional=1
      shift
      ;;
    --public-only)
      public_only=1
      shift
      ;;
    --skip-tools)
      skip_tools=1
      shift
      ;;
    --update-tools)
      update_tools=1
      shift
      ;;
    --check)
      check_only=1
      shift
      ;;
    --release-gate)
      release_gate=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

resolve_cmd() {
  case "$1" in
    */*)
      [ -x "$1" ] && printf '%s\n' "$1"
      ;;
    *)
      command -v "$1"
      ;;
  esac
}

require_cmd() {
  resolve_cmd "$1" >/dev/null 2>&1 || {
    echo "missing required command: $1" >&2
    exit 1
  }
}

python_version_ok() {
  local output
  output="$("$1" --version 2>&1)" || return 1
  case "$output" in
    Python\ *) ;;
    *) return 1 ;;
  esac
  "$1" - "$2" <<'PY'
import sys

minimum = tuple(int(part) for part in sys.argv[1].split("."))
raise SystemExit(0 if sys.version_info[:2] >= minimum else 1)
PY
}

select_python() {
  local minimum="$KEEL_PYTHON_MINIMUM"
  local candidate
  if [ -n "${KEEL_PYTHON:-}" ]; then
    candidate="$KEEL_PYTHON"
    require_cmd "$candidate"
    if python_version_ok "$candidate" "$minimum"; then
      printf '%s\n' "$candidate"
      return
    fi
    echo "keel: KEEL_PYTHON must be Python $minimum or newer: $candidate" >&2
    exit 1
  fi

  for candidate in python3.13 python3.12 python3.11 python3.10 python3; do
    if command -v "$candidate" >/dev/null 2>&1 && python_version_ok "$candidate" "$minimum"; then
      printf '%s\n' "$candidate"
      return
    fi
  done

  echo "keel: Python $minimum or newer is required" >&2
  exit 1
}

PYTHON_BIN="$(select_python)"
PYTHON_BIN="$(resolve_cmd "$PYTHON_BIN")"

run_check() {
  require_cmd "$PYTHON_BIN"
  local manifest_args=("$KEEL_ROOT/scripts/manifest.py" --manifest "$MANIFEST" validate)
  if [ "$release_gate" = "1" ]; then
    manifest_args+=(--release-gate)
  fi
  "$PYTHON_BIN" "${manifest_args[@]}"
  "$PYTHON_BIN" "$KEEL_ROOT/scripts/public_hygiene.py"
  bash -n "$KEEL_ROOT"/bin/keel-* "$KEEL_ROOT/install.sh" "$KEEL_ROOT/uninstall.sh"
}

install_python_editable() {
  local dir="$1"
  if [ ! -f "$dir/pyproject.toml" ] && [ ! -f "$dir/setup.py" ]; then
    echo "keel: warning: $dir has no Python package metadata; skipping editable install" >&2
    return
  fi
  "$PYTHON_BIN" -m venv "$dir/.venv"
  "$dir/.venv/bin/python" -m pip install --upgrade pip
  "$dir/.venv/bin/python" -m pip install -e "$dir"
}

install_tool_deps() {
  local name="$1"
  local dir="$2"
  local install_type="$3"
  case "$install_type" in
    python-editable)
      install_python_editable "$dir"
      ;;
    python-script|none)
      ;;
    bun-link)
      require_cmd bun
      (cd "$dir" && bun install && bun link)
      echo "keel: $name is bun-linked at ~/.bun/bin/$name"
      case ":$PATH:" in
        *":$HOME/.bun/bin:"*) ;;
        *)
          echo "keel: ensure ~/.bun/bin is on PATH; for zsh add:" >&2
          echo '      export PATH="$HOME/.bun/bin:$PATH"' >&2
          ;;
      esac
      ;;
    *)
      echo "keel: unknown install_type for $name: $install_type" >&2
      exit 1
      ;;
  esac
}

clone_or_update_tool() {
  local name="$1"
  local url="$2"
  local ref="$3"
  local install_type="$4"
  local health_check="$5"
  local dest="$KEEL_ROOT/tools/$name"

  if [ -d "$dest" ]; then
    if [ ! -d "$dest/.git" ]; then
      echo "keel: $dest exists but is not a git checkout" >&2
      exit 1
    fi
    if [ "$update_tools" = "1" ]; then
      if [ -n "$(git -C "$dest" status --porcelain)" ]; then
        echo "keel: refusing to update dirty checkout: $dest" >&2
        exit 1
      fi
      git -C "$dest" fetch --tags origin
      git -C "$dest" checkout "$ref"
    else
      echo "keel: using existing checkout $dest"
    fi
  else
    echo "keel: cloning $name"
    GIT_TERMINAL_PROMPT=0 git clone "$url" "$dest"
    GIT_TERMINAL_PROMPT=0 git -C "$dest" fetch --tags origin
    git -C "$dest" checkout "$ref"
  fi

  install_tool_deps "$name" "$dest" "$install_type"
  if [ -n "$health_check" ]; then
    local -a health_parts
    echo "keel: health check for $name"
    read -r -a health_parts <<< "$health_check"
    if [ "${health_parts[0]:-}" = "python3" ]; then
      if [ -x "$dest/.venv/bin/python" ]; then
        health_parts[0]="$dest/.venv/bin/python"
      else
        health_parts[0]="$PYTHON_BIN"
      fi
    fi
    (cd "$dest" && "${health_parts[@]}" >/dev/null)
  fi
}

write_env() {
  cp "$KEEL_ROOT/keel.env.template" "$KEEL_ROOT/keel.env"
  local version="unknown"
  if git -C "$KEEL_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    version="$(git -C "$KEEL_ROOT" describe --tags --always --dirty 2>/dev/null || echo unknown)"
  fi
  {
    echo
    echo "# Generated by install.sh."
    echo "export KEEL_PYTHON=\"$PYTHON_BIN\""
    echo "export KEEL_VERSION=\"$version\""
  } >> "$KEEL_ROOT/keel.env"
  echo "keel: wrote $KEEL_ROOT/keel.env"
}

write_lock() {
  local lock="$KEEL_ROOT/tools.lock"
  {
    echo "schema: keel_tools_lock_v1"
    echo "generated_from: tools.manifest.yaml"
    echo "tools:"
    while IFS=$'\t' read -r name _required url ref _install_type _health _visibility _status; do
      local dest="$KEEL_ROOT/tools/$name"
      local resolved="missing"
      if [ "$skip_tools" = "1" ]; then
        resolved="skipped"
      elif [ -d "$dest/.git" ]; then
        resolved="$(git -C "$dest" rev-parse HEAD)"
      fi
      echo "  $name:"
      echo "    url: $url"
      echo "    ref: $ref"
      echo "    resolved: $resolved"
    done < <(manifest_list)
  } > "$lock"
  echo "keel: wrote $lock"
}

manifest_list() {
  local args=("$KEEL_ROOT/scripts/manifest.py" --manifest "$MANIFEST" list)
  local tool
  if [ "${#include_tools[@]}" -gt 0 ]; then
    for tool in "${include_tools[@]}"; do
      args+=(--include "$tool")
    done
  fi
  if [ "$all_optional" = "1" ]; then
    args+=(--all-optional)
  fi
  if [ "$public_only" = "1" ]; then
    args+=(--public-only)
  fi
  "$PYTHON_BIN" "${args[@]}"
}

run_check

if [ "$check_only" = "1" ]; then
  echo "keel: check complete"
  exit 0
fi

mkdir -p "$KEEL_ROOT/tools"
touch "$KEEL_ROOT/tools/.gitkeep"

if [ "$skip_tools" != "1" ]; then
  require_cmd git
  while IFS=$'\t' read -r name _required url ref install_type health visibility public_status; do
    if [ "$visibility" = "private" ]; then
      echo "keel: note: $name is marked private ($public_status)"
    fi
    clone_or_update_tool "$name" "$url" "$ref" "$install_type" "$health"
  done < <(manifest_list)
else
  echo "keel: skipping tool clone/update"
fi

write_env
write_lock
echo "keel: install complete"
