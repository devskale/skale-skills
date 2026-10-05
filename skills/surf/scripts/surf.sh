#!/usr/bin/env bash
# surf — drive your REAL, logged-in Chrome from the CLI (macOS, AppleScript).
# Entry point: invoked by the `surf` launcher after symlink resolution.
# Sources lib/*.sh (engine, target, nav, read, wait, interact, assert, shot,
# meta, help-overview, help-command, main), sets globals, and dispatches.
set -euo pipefail
VERSION="1.6.0"
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
# Parse --session <name> from ANY position (before main dispatch): routes the
# target pin to ~/.config/surf/target-<name> so parallel surf sessions each
# own their pinned tab instead of stepping on the shared ~/.config/surf/target.
# Equivalent to SURF_TARGET_FILE=~/.config/surf/target-<name>.
_surf_session=""
_args=()
while [ $# -gt 0 ]; do
  case "$1" in
    --session)
      [ $# -ge 2 ] || { echo "surf: --session needs a name" >&2; exit 1; }
      _surf_session="$2"; shift 2 ;;
    *) _args+=("$1"); shift ;;
  esac
done
set -- ${_args[@]+"${_args[@]}"}

APP="$(_surf_pick_app)"
_SURF_PICKED_APP="$APP"   # startup pick — cross-instance attach notes diff against it
if [ -n "$_surf_session" ]; then
  TARGET_FILE="$HOME/.config/surf/target-$_surf_session"
else
  TARGET_FILE="${SURF_TARGET_FILE:-$HOME/.config/surf/target}"
fi

# Multi-instance (v2 pins): the pin may name the instance its tab lives in
# ("App|W T url", written by open's cross-instance reuse). Honor it — every op
# of THIS invocation drives that browser — but only when that instance is
# running (never launch a browser the user didn't open) and SURF_APP isn't
# explicitly forcing a single app. A stale pin for a closed instance falls
# back to the picked app; drift re-pinning then re-resolves by URL.
if [ -z "${SURF_APP:-}" ] && [ -f "$TARGET_FILE" ] && [ -s "$TARGET_FILE" ]; then
  _surf_pin_raw="$(cat "$TARGET_FILE" 2>/dev/null || true)"
  case "$_surf_pin_raw" in
    *"|"*) _surf_pin_app="${_surf_pin_raw%%|*}"
           if [ -n "$_surf_pin_app" ] && [ "$_surf_pin_app" != "$APP" ] && \
              [ "$(osascript -e "application $(as_str "$_surf_pin_app") is running" 2>/dev/null || true)" = "true" ]; then
             APP="$_surf_pin_app"
           fi ;;
  esac
fi

main "$@"
