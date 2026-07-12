#!/usr/bin/env bash
# surf — drive your REAL, logged-in Chrome from the CLI (macOS, AppleScript).
# Logic script; invoked by the `surf` launcher after symlink resolution.
VERSION="0.2.0"
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
cmd_new()    {
  local u="${1-about:blank}"
  # bring a JS-capable window to front (skips incognito AND app/PWA windows that block JS)
  osascript <<'OSA' >/dev/null 2>&1 || true
tell application "Google Chrome"
  repeat with i from 1 to count of windows
    if (count of tabs of window i) is greater than 0 then
      try
        execute (tab 1 of window i) javascript "1"
        set index of window i to 1
        exit repeat
      end try
    end if
  end repeat
end tell
OSA
  osascript -e "tell application \"$APP\" to tell front window to make new tab with properties {URL:\"$u\"}" >/dev/null && echo "new tab: $u"
}
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

cmd_wait() {
  local sel="" to="${SURF_WAIT_TIMEOUT:-15}" js deadline res
  while [ $# -gt 0 ]; do
    case "$1" in
      --timeout) to="$2"; shift 2 ;;
      --timeout=*) to="${1#--timeout=}"; shift ;;
      *) sel="$1"; shift ;;
    esac
  done
  [ -n "$sel" ] || die "wait needs a selector. e.g. surf wait \"h1\"  (variants: wait-url, wait-stable)"
  js="$(printf '(function(){return document.querySelector(%s)?"FOUND":"pending"})()' "$(js_str "$sel")")"
  deadline=$(( $(date +%s) + to ))
  while :; do
    res="$(_run_js_raw "$js" 2>/dev/null || true)"
    [ "$res" = "FOUND" ] && { echo "found: $sel"; return 0; }
    [ "$(date +%s)" -ge "$deadline" ] && { echo "surf: wait timeout (${to}s): $sel" >&2; return 1; }
    sleep "${SURF_WAIT_INTERVAL:-0.3}"
  done
}

cmd_wait_url() {
  local sub="" to="${SURF_WAIT_TIMEOUT:-15}" deadline href
  while [ $# -gt 0 ]; do
    case "$1" in --timeout) to="$2"; shift 2 ;; --timeout=*) to="${1#*=}"; shift ;; *) sub="$1"; shift ;; esac
  done
  [ -n "$sub" ] || die "wait-url needs a substring"
  deadline=$(( $(date +%s) + to ))
  while :; do
    href="$(_run_js_raw 'location.href' 2>/dev/null || true)"
    case "$href" in *"$sub"*) echo "ok: $href"; return 0 ;; esac
    [ "$(date +%s)" -ge "$deadline" ] && { echo "surf: wait-url timeout (${to}s): still $href" >&2; return 1; }
    sleep "${SURF_WAIT_INTERVAL:-0.3}"
  done
}

cmd_wait_stable() {
  local to="${SURF_WAIT_TIMEOUT:-15}" iv="${SURF_WAIT_INTERVAL:-0.4}" deadline l1 l2
  while [ $# -gt 0 ]; do
    case "$1" in --timeout) to="$2"; shift 2 ;; --timeout=*) to="${1#*=}"; shift ;; *) shift ;; esac
  done
  deadline=$(( $(date +%s) + to ))
  l1="$(_run_js_raw 'String(document.body && document.body.innerHTML.length||0)' 2>/dev/null || true)"
  while :; do
    sleep "$iv"
    l2="$(_run_js_raw 'String(document.body && document.body.innerHTML.length||0)' 2>/dev/null || true)"
    [ "$l1" = "$l2" ] && { echo "stable: ${l2} bytes"; return 0; }
    l1="$l2"
    [ "$(date +%s)" -ge "$deadline" ] && { echo "surf: wait-stable timeout (${to}s): still changing" >&2; return 1; }
  done
}

cmd_hover() {
  [ "${1-}" ] || die "hover needs a selector"
  run_js "$(printf '(function(){var e=document.querySelector(%s);if(!e)return JSON.stringify({ok:false,err:"not_found"});try{e.scrollIntoView({block:"center"})}catch(x){}e.dispatchEvent(new MouseEvent("mouseover",{bubbles:true}));e.dispatchEvent(new MouseEvent("mousemove",{bubbles:true}));e.dispatchEvent(new MouseEvent("mouseenter",{bubbles:true}));return JSON.stringify({ok:true,tag:e.tagName})})()' "$(js_str "$1")")"
}

cmd_select_option() {
  [ "${1-}" ] && [ "${2-}" ] || die "select-option needs <selector> <value>"
  run_js "$(printf '(function(){var e=document.querySelector(%s);if(!e)return JSON.stringify({ok:false,err:"not_found"});if(e.tagName!=="SELECT")return JSON.stringify({ok:false,err:"not_select",tag:e.tagName});e.value=%s;e.dispatchEvent(new Event("input",{bubbles:true}));e.dispatchEvent(new Event("change",{bubbles:true}));return JSON.stringify({ok:true,value:e.value})})()' "$(js_str "$1")" "$(js_str "$2")")"
}

cmd_submit() {
  [ "${1-}" ] || die "submit needs a selector (a form, or an element inside a form)"
  run_js "$(printf '(function(){var e=document.querySelector(%s);if(!e)return JSON.stringify({ok:false,err:"not_found"});var f=(e.tagName==="FORM")?e:(e.form||e.closest("form"));if(!f)return JSON.stringify({ok:false,err:"no_form"});if(typeof f.requestSubmit==="function"){f.requestSubmit()}else{f.submit()}return JSON.stringify({ok:true})})()' "$(js_str "$1")")"
}

cmd_scroll() {
  local dir="${1-}" n="${2-1}" sel js
  [ -n "$dir" ] || die "scroll needs: down|up|top|bottom [N]  or  to \"<sel>\""
  case "$dir" in
    down)   [[ "$n" =~ ^[0-9]+$ ]] || n=1; js="window.scrollBy(0, window.innerHeight*$n); 'ok'" ;;
    up)     [[ "$n" =~ ^[0-9]+$ ]] || n=1; js="window.scrollBy(0, -window.innerHeight*$n); 'ok'" ;;
    top)    js="window.scrollTo(0, 0); 'ok'" ;;
    bottom) js="window.scrollTo(0, document.documentElement.scrollHeight); 'ok'" ;;
    to)     sel="${2-}"; [ -n "$sel" ] || die "scroll to needs a selector"
            js="$(printf '(function(){var e=document.querySelector(%s);if(!e)return JSON.stringify({ok:false,err:"not_found"});e.scrollIntoView({block:"center",behavior:"instant"});return JSON.stringify({ok:true})})()' "$(js_str "$sel")")" ;;
    *) die "scroll: unknown '$dir'. Use down|up|top|bottom [N] or to \"<sel>\"" ;;
  esac
  run_js "$js"
}

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
  surf wait  "<sel>" [--timeout N] poll until element exists (exit 1 on timeout)
  surf wait-url "<sub>" [--timeout N]  poll until URL contains substring
  surf wait-stable [--timeout N]      poll until DOM stops changing
  surf scroll down|up|top|bottom [N]  scroll by N viewport-heights (default 1)
  surf scroll-to "<sel>"              scroll element into view (center)
  surf hover "<sel>"                  fire mouseover/mouseenter on first match
  surf select-option "<sel>" "<val>"  set a <select> value + fire change
  surf submit "<sel>"                 submit the enclosing form (requestSubmit)
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
    wait)   cmd_wait "$@" ;;
    wait-url) cmd_wait_url "$@" ;;
    wait-stable) cmd_wait_stable "$@" ;;
    scroll)      cmd_scroll "$@" ;;
    scroll-to)   cmd_scroll to "$@" ;;
    hover)       cmd_hover "$@" ;;
    select-option) cmd_select_option "$@" ;;
    submit)      cmd_submit "$@" ;;
    shot)        cmd_shot "$@" ;;
    setup)  cmd_setup ;;
    ""|help|-h|--help) usage ;;
    *) die "unknown command: $sub (try: surf help)" ;;
  esac
}

main "$@"
