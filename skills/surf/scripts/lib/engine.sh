# surf/lib/engine.sh — app pick, error/util helpers, JS execution. Sourced by surf.sh.

# ── browser selection ─────────────────────────────────────────────
# An explicit SURF_APP override always wins. Otherwise drive the browser
# you're actually in: prefer a RUNNING Google Chrome; if only Google Chrome
# Beta is running, use Beta; if neither is running, fall back to stable
# Chrome (the first `tell application` launches it). Keeps surf from driving
# a browser you didn't open, while still defaulting to Chrome.
_surf_pick_app() {
  [ -n "${SURF_APP:-}" ] && { printf '%s' "$SURF_APP"; return; }
  local chrome beta
  chrome=$(osascript -e 'application "Google Chrome" is running' 2>/dev/null || true)
  beta=$(osascript -e 'application "Google Chrome Beta" is running' 2>/dev/null || true)
  if [ "$chrome" = "true" ]; then
    printf '%s' "Google Chrome"
  elif [ "$beta" = "true" ]; then
    printf '%s' "Google Chrome Beta"
  else
    printf '%s' "Google Chrome"
  fi
}

die() { echo "surf: $*" >&2; exit 1; }

# JS string literal
js_str() {
  local s="${1-}"
  s="${s//\\/\\\\}"; s="${s//\"/\\\"}"
  printf '"%s"' "$s"
}

_want_json() { for a in "$@"; do [ "$a" = "--json" ] && return 0; done; return 1; }

# execute JS in the target tab; JS written to a temp file to avoid quoting hell. Raw (no error classification).
_run_js_raw() {
  local js="$1" tmp tgt W T
  tmp="$(mktemp -t surf).js"
  printf '%s' "$js" > "$tmp"
  tgt="$(get_target)"
  if [ "$tgt" = "front" ]; then
    osascript -l AppleScript <<APPLESCRIPT 2>&1
tell application "$APP"
  return execute active tab of front window javascript (read POSIX file "$tmp" as «class utf8»)
end tell
APPLESCRIPT
  else
    W=$(echo "$tgt" | cut -d' ' -f1); T=$(echo "$tgt" | cut -d' ' -f2)
    osascript -l AppleScript <<APPLESCRIPT 2>&1
tell application "$APP"
  return execute (tab $T of window $W) javascript (read POSIX file "$tmp" as «class utf8»)
end tell
APPLESCRIPT
  fi
  local rc=$?
  rm -f "$tmp"
  return $rc
}

# Print an actionable reason for a "turned off"-style JS failure to stderr.
# Distinguishes: global toggle off vs incognito window vs restricted tab (x.com / app-PWA).
_explain_js_failure() {
  local tgt W mode any wt
  tgt="$(get_target)"
  W=1; [ "$tgt" != "front" ] && W="$(echo "$tgt" | cut -d' ' -f1)"
  mode="$(osascript -e "tell application \"$APP\" to get mode of window $W" 2>/dev/null || true)"
  if [ "$mode" = "incognito" ]; then
    echo "surf: window $W is incognito — JS-from-AppleScript is blocked there. Use a normal window." >&2
    return 0
  fi
  # Probe other tabs: if ANY allows JS, the toggle is ON and this tab/site/window is the restriction.
  any=false
  while read -r ref; do
    [ -z "$ref" ] && continue
    wt="$(echo "$ref" | sed 's#w##; s#\.t# #')"   # "w2.t1" -> "2 1"
    if osascript -e "tell application \"$APP\" to execute (tab $(echo "$wt" | cut -d' ' -f2) of window $(echo "$wt" | cut -d' ' -f1)) javascript \"1\"" >/dev/null 2>&1; then
      any=true; break
    fi
  done < <(surf tabs 2>/dev/null | grep -oE 'w[0-9]+\.t[0-9]+' | head -10)
  if $any; then
    echo "surf: this tab/window blocks JS (common: x.com, a Chrome app/PWA window, or a restricted site) — though the global toggle is ON. 'surf select' a normal-site tab and retry." >&2
  else
    echo "surf: JavaScript-from-AppleScript is OFF. Fix: Chrome menu → View → Developer ▸ → Allow JavaScript from Apple Events (✓), then retry." >&2
  fi
}

# Public JS runner: classifies "turned off" failures into an actionable message.
run_js() {
  local out
  out="$(_run_js_raw "$1" 2>/dev/null || true)"
  case "$out" in
    *"Allow JavaScript from Apple Events"*|*"turned off"*) _explain_js_failure; return 1 ;;
  esac
  printf '%s\n' "$out"
}
