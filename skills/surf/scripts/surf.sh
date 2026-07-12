#!/usr/bin/env bash
# surf — drive your REAL, logged-in Chrome from the CLI (macOS, AppleScript).
# Logic script; invoked by the `surf` launcher after symlink resolution.
VERSION="0.1.0"
set -euo pipefail

APP="${SURF_APP:-Google Chrome}"
TARGET_FILE="${SURF_TARGET_FILE:-$HOME/.config/surf/target}"

die() { echo "surf: $*" >&2; exit 1; }

# ── target resolution ───────────────────────────────────────────────
# target is either "front" (active tab of front window) or "W T" (window, tab).
get_target() {
  if [ -f "$TARGET_FILE" ] && [ -s "$TARGET_FILE" ]; then cat "$TARGET_FILE"
  else echo "front"; fi
}

# JS string literal
js_str() {
  local s="${1-}"
  s="${s//\\/\\\\}"; s="${s//\"/\\\"}"
  printf '"%s"' "$s"
}

# execute JS in the target tab; JS written to a temp file to avoid quoting hell
run_js() {
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

# ── commands ────────────────────────────────────────────────────────
cmd_tabs() {
  osascript <<APPLESCRIPT
set out to ""
tell application "$APP"
  set wi to 0
  repeat with w in windows
    set wi to wi + 1
    set ti to 0
    repeat with t in tabs of w
      set ti to ti + 1
      set out to out & "w" & wi & ".t" & ti & "  " & (URL of t) & "  |  " & (title of t) & linefeed
    end repeat
  end repeat
end tell
return out
APPLESCRIPT
}

cmd_here() {
  local tgt W T
  tgt="$(get_target)"
  if [ "$tgt" = "front" ]; then
    osascript -e "tell application \"$APP\" to get (URL of active tab of front window) & \"  |  \" & (title of active tab of front window)"
  else
    W=$(echo "$tgt" | cut -d' ' -f1); T=$(echo "$tgt" | cut -d' ' -f2)
    osascript -e "tell application \"$APP\" to get (URL of tab $T of window $W) & \"  |  \" & (title of tab $T of window $W)"
  fi
}

cmd_open()   { [ "${1-}" ] || die "open needs a url"; local tgt W T; tgt="$(get_target)"
  if [ "$tgt" = "front" ]; then osascript -e "tell application \"$APP\" to set URL of active tab of front window to \"$1\"" >/dev/null && echo "ok: $1"
  else W=$(echo "$tgt"|cut -d' ' -f1); T=$(echo "$tgt"|cut -d' ' -f2); osascript -e "tell application \"$APP\" to set URL of tab $T of window $W to \"$1\"" >/dev/null && echo "ok (w$W.t$T): $1"; fi
}
cmd_new()    { local u="${1-about:blank}"; osascript -e "tell application \"$APP\" to tell front window to make new tab with properties {URL:\"$u\"}" >/dev/null && echo "new tab: $u"; }
cmd_reload() { local tgt W T; tgt="$(get_target)"
  if [ "$tgt" = "front" ]; then osascript -e "tell application \"$APP\" to reload active tab of front window" >/dev/null && echo "reloaded"
  else W=$(echo "$tgt"|cut -d' ' -f1); T=$(echo "$tgt"|cut -d' ' -f2); osascript -e "tell application \"$APP\" to reload tab $T of window $W" >/dev/null && echo "reloaded (w$W.t$T)"; fi
}
cmd_back()   { run_js 'history.back(); "ok"'; }
cmd_fwd()    { run_js 'history.forward(); "ok"'; }
cmd_title()  { run_js 'document.title'; }
cmd_url()    { run_js 'location.href'; }

cmd_text()  { [ "${1-}" ] || die "text needs a selector"; run_js "$(printf '(function(){var e=document.querySelector(%s);return e?String(e.textContent).trim().slice(0,10000):"NOT_FOUND"})()' "$(js_str "$1")")"; }
cmd_html()  { [ "${1-}" ] || die "html needs a selector"; run_js "$(printf '(function(){var e=document.querySelector(%s);return e?e.outerHTML:"NOT_FOUND"})()' "$(js_str "$1")")"; }
cmd_count() { [ "${1-}" ] || die "count needs a selector"; run_js "$(printf '(function(){return String(document.querySelectorAll(%s).length)})()' "$(js_str "$1")")"; }
cmd_attr()  { [ "${1-}" ] && [ "${2-}" ] || die "attr needs <selector> <name>"; run_js "$(printf '(function(){var e=document.querySelector(%s);return e?String(e.getAttribute(%s)):"NOT_FOUND"})()' "$(js_str "$1")" "$(js_str "$2")")"; }
cmd_click() { [ "${1-}" ] || die "click needs a selector"
  run_js "$(printf '(function(){var e=document.querySelector(%s);if(!e)return JSON.stringify({ok:false,err:"not_found"});try{e.scrollIntoView({block:"center"})}catch(x){}e.click();return JSON.stringify({ok:true,tag:e.tagName})})()' "$(js_str "$1")")"; }
cmd_fill()  { [ "${1-}" ] && [ "${2-}" ] || die "fill needs <selector> <value>"
  run_js "$(printf '(function(){var e=document.querySelector(%s);if(!e)return JSON.stringify({ok:false,err:"not_found"});e.focus();e.value=%s;e.dispatchEvent(new Event("input",{bubbles:true}));e.dispatchEvent(new Event("change",{bubbles:true}));return JSON.stringify({ok:true,tag:e.tagName})})()' "$(js_str "$1")" "$(js_str "$2")")"; }
cmd_eval()  { [ "${1-}" ] || die "eval needs js"; run_js "$1"; }

cmd_close() {
  local tgt W T; tgt="$(get_target)"
  if [ "$tgt" = "front" ]; then
    osascript -e "tell application \"$APP\" to close active tab of front window" >/dev/null && echo "closed active tab"
  else
    W=$(echo "$tgt"|cut -d' ' -f1); T=$(echo "$tgt"|cut -d' ' -f2)
    osascript -e "tell application \"$APP\" to close tab $T of window $W" >/dev/null && echo "closed w$W.t$T"
    rm -f "$TARGET_FILE"
  fi
}

cmd_select() {
  local arg="${1-}"
  if [ -z "$arg" ] || [ "$arg" = "show" ]; then
    if [ -f "$TARGET_FILE" ] && [ -s "$TARGET_FILE" ]; then echo "target: $(cat "$TARGET_FILE") (window tab)"
    else echo "target: none (active tab of front window)"; fi
    return
  fi
  if [ "$arg" = "reset" ] || [ "$arg" = "active" ] || [ "$arg" = "-" ]; then
    rm -f "$TARGET_FILE"; echo "target reset → active tab of front window"; return
  fi
  if [[ "$arg" =~ ^w([0-9]+)\.t([0-9]+)$ ]]; then
    mkdir -p "$(dirname "$TARGET_FILE")"
    echo "${BASH_REMATCH[1]} ${BASH_REMATCH[2]}" > "$TARGET_FILE"
    echo "target → window ${BASH_REMATCH[1]}, tab ${BASH_REMATCH[2]}"
  else
    die "select: expected wN.tN (e.g. w1.t3), reset, or blank. List refs with: surf tabs"
  fi
}

cmd_shot() {
  local out="${1:-./surf-shot.png}" tgt W T bounds x1 y1 x2 y2 w h err rc
  tgt="$(get_target)"
  if [ "$tgt" = "front" ]; then W=1; else W=$(echo "$tgt"|cut -d' ' -f1); T=$(echo "$tgt"|cut -d' ' -f2)
    osascript -e "tell application \"$APP\" to set active tab index of window $W to $T" >/dev/null 2>&1 || true
  fi
  osascript -e "tell application \"$APP\" to set index of window $W to 1" >/dev/null 2>&1 || true  # bring window to front
  sleep 0.2
  bounds="$(osascript -e "tell application \"$APP\" to get bounds of window 1" 2>&1)"
  if ! echo "$bounds" | grep -qE '^[0-9]+,[[:space:]]*[0-9]+'; then die "could not read window bounds: $bounds"; fi
  x1=$(echo "$bounds"|awk -F', ' '{print $1}'); y1=$(echo "$bounds"|awk -F', ' '{print $2}')
  x2=$(echo "$bounds"|awk -F', ' '{print $3}'); y2=$(echo "$bounds"|awk -F', ' '{print $4}')
  w=$((x2 - x1)); h=$((y2 - y1))
  err=$(screencapture -R "$x1,$y1,$w,$h" -o -x "$out" 2>&1); rc=$?
  if [ $rc -ne 0 ]; then
    echo "surf: screencapture failed ($err)" >&2
    if echo "$err" | grep -qi "could not create image"; then
      echo "   → macOS needs Screen Recording permission for your terminal." >&2
      open "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture" 2>/dev/null || true
      echo "   → Enable Ghostty in System Settings → Privacy & Security → Screen Recording, then re-run." >&2
    fi
    return 1
  fi
  echo "shot → $out (${w}x${h})"
}

cmd_setup() {
  local out
  out=$(osascript <<'APPLESCRIPT' 2>&1
tell application "Google Chrome" to activate
delay 0.3
tell application "System Events"
  tell process "Google Chrome"
    set theItem to menu item "Allow JavaScript from Apple Events" of menu "Developer" of menu item "Developer" of menu "View" of menu bar item "View" of menu bar 1
    click theItem
    return "clicked"
  end tell
end tell
APPLESCRIPT
  )
  # GUI scripting can't reliably flip Chromium menus; verify via a real JS call.
  if surf title >/dev/null 2>&1; then
    echo "JavaScript-from-AppleScript is enabled. ✓"
  else
    echo "surf: JS still off. GUI-scripting can't flip this Chromium menu item." >&2
    echo "   → Click it manually ONCE:" >&2
    echo "     Chrome menu bar → View → Developer ▸ → Allow JavaScript from Apple Events (✓)" >&2
    echo "   → Also grant Accessibility to your terminal if the click attempt was denied." >&2
    return 1
  fi
}

usage() {
  cat <<'EOF'
surf — drive your real Chrome (macOS, AppleScript). No daemon/port/extension/ack.

  surf tabs                       list windows → tabs (refs like w1.t3)
  surf here                       active/target tab: URL | title
  surf select [wN.tN | reset]     target a tab (op background tabs w/o focus); blank = show
  surf open <url>                 navigate target tab
  surf new [<url>]                new tab (front window)
  surf reload | back | fwd        target-tab controls
  surf close                      close target/active tab
  surf title | url                document.title / location.href
  surf text  "<sel>"              textContent of first match
  surf html  "<sel>"              outerHTML of first match
  surf attr  "<sel>" <name>       attribute value of first match
  surf count "<sel>"              number of matches
  surf click "<sel>"              click first match (scrolls into view)
  surf fill  "<sel>" "<val>"      set value + fire input/change
  surf eval  "<js>"               run JS in target tab, print result
  surf shot  [<path>]             screenshot the window (PNG)
  surf setup                      one-time: enable Chrome JS-from-AppleScript
  surf --version | --selfcheck    version / install info
  surf help                       this message

Selectors are CSS. One-time setup: `surf setup` (or View → Developer → Allow JavaScript from Apple Events).
EOF
}

main() {
  case "${1-}" in
    --version) echo "surf $VERSION"; exit 0 ;;
  esac
  local sub="${1-}"; [ "${1-}" ] && shift || true
  case "$sub" in
    tabs)   cmd_tabs ;;
    here)   cmd_here ;;
    select) cmd_select "$@" ;;
    open)   cmd_open "$@" ;;
    new)    cmd_new "$@" ;;
    reload|refresh) cmd_reload ;;
    back)   cmd_back ;;
    fwd|forward)    cmd_fwd ;;
    close)  cmd_close ;;
    title)  cmd_title ;;
    url)    cmd_url ;;
    text)   cmd_text "$@" ;;
    html)   cmd_html "$@" ;;
    attr)   cmd_attr "$@" ;;
    count)  cmd_count "$@" ;;
    click)  cmd_click "$@" ;;
    fill)   cmd_fill "$@" ;;
    eval)   cmd_eval "$@" ;;
    shot)   cmd_shot "$@" ;;
    setup)  cmd_setup ;;
    ""|help|-h|--help) usage ;;
    *) die "unknown command: $sub (try: surf help)" ;;
  esac
}

main "$@"
