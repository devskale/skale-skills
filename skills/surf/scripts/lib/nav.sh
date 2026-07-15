# surf/lib/nav.sh — tabs, here, open/new/reload/back/fwd/close. Sourced by surf.sh.

cmd_tabs() {
  if _want_json "$@"; then
    osascript <<APPLESCRIPT | python3 -c 'import sys,json;print(json.dumps([{"window":int(a),"tab":int(b),"url":c,"title":d} for a,b,c,d in (l.rstrip("\n").split("\t") for l in sys.stdin if l.strip())],ensure_ascii=False))'
tell application "$APP"
  set out to ""
  repeat with wi from 1 to count of windows
    repeat with ti from 1 to count of tabs of window wi
      set t to tab ti of window wi
      set out to out & (wi as text) & (character id 9) & (ti as text) & (character id 9) & (URL of t) & (character id 9) & (title of t) & linefeed
    end repeat
  end repeat
  return out
end tell
APPLESCRIPT
    return
  fi
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
  if _want_json "$@"; then
    if [ "$tgt" = "front" ]; then
      run_js 'JSON.stringify({url:location.href,title:document.title})'
    else
      W=$(echo "$tgt" | cut -d' ' -f1); T=$(echo "$tgt" | cut -d' ' -f2)
      run_js "JSON.stringify({window:$W,tab:$T,url:location.href,title:document.title})"
    fi
    return
  fi
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
  osascript <<OSA >/dev/null 2>&1 || true
tell application "$APP"
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
