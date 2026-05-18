#!/usr/bin/env bash
set -euo pipefail

KEEL_ROOT="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
remove_tools=0

usage() {
  cat <<'EOF'
usage: ./uninstall.sh [--remove-tools]

Removes generated local Keel files. Tool checkouts are preserved by default.

To remove tool checkouts too:

  KEEL_CONFIRM_REMOVE_TOOLS=remove-tools ./uninstall.sh --remove-tools
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --remove-tools)
      remove_tools=1
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

rm -f "$KEEL_ROOT/keel.env" "$KEEL_ROOT/tools.lock"
echo "keel: removed generated env/lock files"

if [ "$remove_tools" = "1" ]; then
  if [ "${KEEL_CONFIRM_REMOVE_TOOLS:-}" != "remove-tools" ]; then
    echo "keel: refusing to remove tools without KEEL_CONFIRM_REMOVE_TOOLS=remove-tools" >&2
    exit 2
  fi
  rm -rf "$KEEL_ROOT/tools"
  mkdir -p "$KEEL_ROOT/tools"
  touch "$KEEL_ROOT/tools/.gitkeep"
  echo "keel: removed tool checkouts"
fi
