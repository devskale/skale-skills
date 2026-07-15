#!/usr/bin/env bash
# surf — drive your REAL, logged-in Chrome from the CLI (macOS, AppleScript).
# Entry point: invoked by the `surf` launcher after symlink resolution.
# Sources lib/*.sh (engine, target, nav, read, wait, interact, assert, shot,
# meta, main), sets globals, and dispatches.
set -euo pipefail
VERSION="1.3.1"
SURF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source all modules. Order-independent: files define functions only; no
# top-level execution. (main.sh defines main(); it must NOT call it.)
for __surf_lib in "$SURF_DIR"/lib/*.sh; do
  # shellcheck disable=SC1090
  source "$__surf_lib"
done

# ── globals (used by every cmd_ via $APP / $TARGET_FILE) ────────────
APP="$(_surf_pick_app)"
TARGET_FILE="${SURF_TARGET_FILE:-$HOME/.config/surf/target}"

main "$@"
