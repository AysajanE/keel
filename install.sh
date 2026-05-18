#!/usr/bin/env bash
set -euo pipefail

KEEL_ROOT="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$KEEL_ROOT/tools.manifest.yaml"
PYTHON_BIN="${KEEL_PYTHON:-python3}"

include_tools=()
all_optional=0
skip_tools=0
update_tools=0
check_only=0

usage() {
  cat <<'EOF'
usage: ./install.sh [options]

Options:
  --with <tool>       Install an optional tool from tools.manifest.yaml.
  --all-optional      Install every optional tool.
  --skip-tools        Only write local Keel env/lock files; do not clone tools.
  --update-tools      Fetch and checkout manifest refs for clean existing tools.
  --check             Validate scripts and manifest only; do not write or clone.
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

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing required command: $1" >&2
    exit 1
  }
}

run_check() {
  require_cmd "$PYTHON_BIN"
  "$PYTHON_BIN" "$KEEL_ROOT/scripts/manifest.py" --manifest "$MANIFEST" validate
  "$PYTHON_BIN" "$KEEL_ROOT/scripts/public_hygiene.py"
  bash -n "$KEEL_ROOT"/bin/keel-* "$KEEL_ROOT/install.sh" "$KEEL_ROOT/uninstall.sh"
}

install_python_editable() {
  local dir="$1"
  if [ ! -f "$dir/pyproject.toml" ] && [ ! -f "$dir/setup.py" ]; then
    echo "keel: $dir has no Python package metadata; skipping editable install"
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
    git clone "$url" "$dest"
    git -C "$dest" fetch --tags origin
    git -C "$dest" checkout "$ref"
  fi

  install_tool_deps "$name" "$dest" "$install_type"
  if [ -n "$health_check" ]; then
    echo "keel: health check for $name"
    (cd "$dest" && sh -c "$health_check" >/dev/null)
  fi
}

write_env() {
  cp "$KEEL_ROOT/keel.env.template" "$KEEL_ROOT/keel.env"
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
      if [ -d "$dest/.git" ]; then
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
