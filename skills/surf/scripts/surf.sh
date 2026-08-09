#!/usr/bin/env bash
# surf — drive your REAL, logged-in Chrome from the CLI (macOS, AppleScript).
# Entry point: invoked by the `surf` launcher after symlink resolution.
# Sources lib/*.sh (engine, target, nav, read, wait, interact, assert, shot,
# meta, help-overview, help-command, main), sets globals, and dispatches.
set -euo pipefail
VERSION="1.4.7"
SURF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd "$SURF_DIR/.." && pwd)"

# Source all modules. Order-independent: files define functions only; no
# top-level execution. (main.sh defines main(); it must NOT call it.)
for __surf_lib in "$SURF_DIR"/lib/*.sh; do
  # shellcheck disable=SC1090
  source "$__surf_lib"
done

# ── THE SEAM ──────────────────────────────────────────────────────────
# surf's architecture: command files (nav/read/wait/interact/shot/meta) are
# CALLERS. They route through two load-bearing interfaces, nothing else:
#
#   run_js <js>        engine.sh — execute JS in the target tab, classifying the
#                      "JavaScript-from-AppleScript off" failure into an actionable
#                      message (run_js -> _run_js_raw -> _explain_js_failure).
#   get_target         target.sh — resolve the pinned tab ("front" | "W T"),
#                      verifying/re-pinning on drift; cached per-process.
#
# $APP and $TARGET_FILE below are the SHARED CONFIG every command reads — set
# once here, read-only thereafter. New commands should route through run_js /
# get_target and read these two globals; they must not reach around the seam
# (e.g. calling osascript directly to run JS, or re-deriving the target).
# ──────────────────────────────────────────────────────────────────────
APP="$(_surf_pick_app)"
TARGET_FILE="${SURF_TARGET_FILE:-$HOME/.config/surf/target}"

main "$@"
