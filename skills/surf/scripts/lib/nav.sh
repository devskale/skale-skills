# surf/lib/nav.sh — tabs, here, open/new/reload/back/fwd/close. Sourced by surf.sh.

cmd_tabs() {
  if _want_json "$@"; then
    _surf_tabs_json_for "$APP"
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

# Tabs of ANY app as JSON (app-parameterized cmd_tabs) — the seam under
# multi-instance reuse: _surf_running_apps iterates instances, each search
# needs that instance's tab list without touching the global $APP.
_surf_tabs_json_for() {
  local _app="$1"
  osascript <<APPLESCRIPT | python3 -c 'import sys,json;print(json.dumps([{"window":int(a),"tab":int(b),"url":c,"title":d} for a,b,c,d in (l.rstrip("\n").split("\t") for l in sys.stdin if l.strip())],ensure_ascii=False))'
tell application "$_app"
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

cmd_open() {
  local url="" force_new=false
  while [ $# -gt 0 ]; do
    case "$1" in
      --new) force_new=true; shift ;;
      -*) die "open: unknown flag $1 (try: surf help open)" ;;
      *) [ -z "$url" ] && url="$1" || die "open: unexpected argument '$1'"; shift ;;
    esac
  done
  [ -n "$url" ] || die "open needs a url"

  # Reuse by default — two tiers, tried in order (--new skips both), each
  # searching EVERY running Chromium-family instance ($APP first, then any
  # other running Chrome/Beta/Chromium/Brave/Edge/… — see _surf_running_apps).
  # A hit in another instance switches $APP for this invocation AND the pin
  # records the app ("App|W T url"), so subsequent surf ops drive that tab.
  #   1. exact URL match (trailing slash ignored)
  #   2. same-origin path-segment prefix: the request path is a prefix of an
  #      open tab's path at a "/" boundary — e.g. open "localhost:3000/dashboard"
  #      reuses a tab at "localhost:3000/dashboard/ai-chat". Lands on the deeper
  #      (already logged-in) page instead of duplicating.
  if ! $force_new; then
    local hit W T taburl app
    # Tier 1: exact.
    hit="$(_surf_find_tab_by_url "$url")"
    if [ -n "$hit" ]; then
      IFS=$'\t' read -r app W T <<<"$hit"
      _surf_attach_app "$app"
      _surf_pin_target "$W" "$T" "$url"
      echo "reuse: w$W.t$T  $url"
      return 0
    fi
    # Tier 2: same-origin path-segment prefix.
    hit="$(_surf_find_tab_by_prefix "$url")"
    if [ -n "$hit" ]; then
      IFS=$'\t' read -r app W T taburl <<<"$hit"
      _surf_attach_app "$app"
      _surf_pin_target "$W" "$T" "$taburl"
      echo "reuse: w$W.t$T  $url  →  $taburl"
      return 0
    fi
  fi

  # No reusable tab: navigate the target tab (current behavior).
  local tgt W T; tgt="$(get_target)"
  if [ "$tgt" = "front" ]; then
    osascript -e "tell application \"$APP\" to set URL of active tab of front window to $(as_str "$url")" >/dev/null && echo "ok: $url"
  else
    W="$(echo "$tgt" | cut -d' ' -f1)"; T="$(echo "$tgt" | cut -d' ' -f2)"
    osascript -e "tell application \"$APP\" to set URL of tab $T of window $W to $(as_str "$url")" >/dev/null && echo "ok (w$W.t$T): $url"
  fi
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
  osascript -e "tell application \"$APP\" to tell front window to make new tab with properties {URL:$(as_str "$u")}" >/dev/null && echo "new tab: $u"
  # Pin the new tab as the target: the caller almost always works on it next
  # (here/text/eval read the pin, not the front tab). Best-effort — if the
  # lookup fails, the previous target stays and the caller can select manually.
  local W T NU
  W=$(osascript -e "tell application \"$APP\" to get index of front window" 2>/dev/null) || return 0
  T=$(osascript -e "tell application \"$APP\" to get active tab index of front window" 2>/dev/null) || return 0
  NU=$(osascript -e "tell application \"$APP\" to get URL of active tab of front window" 2>/dev/null) || return 0
  _surf_pin_target "$W" "$T" "$NU" 2>/dev/null || true
}
cmd_reload() { local tgt W T; tgt="$(get_target)"
  if [ "$tgt" = "front" ]; then osascript -e "tell application \"$APP\" to reload active tab of front window" >/dev/null && echo "reloaded"
  else W=$(echo "$tgt"|cut -d' ' -f1); T=$(echo "$tgt"|cut -d' ' -f2); osascript -e "tell application \"$APP\" to reload tab $T of window $W" >/dev/null && echo "reloaded (w$W.t$T)"; fi
}
cmd_back()   { run_js 'history.back(); "ok"'; }
cmd_fwd()    { run_js 'history.forward(); "ok"'; }

cmd_close() {
  # close [wN.tN] — no arg: close the pinned target (as before)
  local tgt W T
  if [ $# -gt 0 ] && [[ "$1" =~ ^w([0-9]+)\.t([0-9]+)$ ]]; then
    W=${BASH_REMATCH[1]}; T=${BASH_REMATCH[2]}
    osascript -e "tell application \"$APP\" to close tab $T of window $W" >/dev/null && echo "closed w$W.t$T"
    # if this tab was the pin, drop the pin (pin may be app-prefixed: "App|W T url")
    if [ -f "$TARGET_FILE" ]; then
      local pin pW pT
      pin="$(_target_raw)"
      if [ "$pin" != "front" ]; then
        read -r pW pT _ <<<"$pin"
        [ "$pW.$pT" = "$W.$T" ] && rm -f "$TARGET_FILE"
      fi
    fi
    return 0
  fi
  tgt="$(get_target)"
  if [ "$tgt" = "front" ]; then
    osascript -e "tell application \"$APP\" to close active tab of front window" >/dev/null && echo "closed active tab"
  else
    W=$(echo "$tgt"|cut -d' ' -f1); T=$(echo "$tgt"|cut -d' ' -f2)
    osascript -e "tell application \"$APP\" to close tab $T of window $W" >/dev/null && echo "closed w$W.t$T"
    rm -f "$TARGET_FILE"
  fi
}

# ── tab helpers (shared by find-tab and open's reuse path) ─────────────

# Switch this invocation (and, via the pin file, subsequent ones) to $1's
# instance when the reused tab lives in another app. Stdout stays stable;
# the cross-instance attach is a stderr note.
_surf_attach_app() {
  [ "$1" = "$APP" ] && return 0
  APP="$1"
  echo "surf: attached to $APP (page was open there, not in ${_SURF_PICKED_APP:-$APP})" >&2
}

# Bring window W to the front and make tab T its active tab. Best-effort
# (ignore errors — used for focusing a reused/matched tab).
_surf_activate_tab() {
  osascript -e "tell application \"$APP\" to set index of window $1 to 1" >/dev/null 2>&1 || true
  osascript -e "tell application \"$APP\" to set active tab index of window $1 to $2" >/dev/null 2>&1 || true
  osascript -e "tell application \"$APP\" to activate" >/dev/null 2>&1 || true
}

# First tab whose URL exactly matches $1, searching EVERY running instance
# ($APP first). A single trailing slash is ignored on both sides, so
# "https://x.com" matches a tab showing "https://x.com/". Echoes
# "<app>\t<W>\t<T>" of the first match (tab-delimited — app names contain
# spaces); nothing on no match.
_surf_find_tab_by_url() {
  local url="$1" app json res
  while IFS= read -r app; do
    json="$(_surf_tabs_json_for "$app" 2>/dev/null || true)"
    [ -n "$json" ] || continue
    res="$(SURF_URL="$url" python3 -c '
import sys, json, os
def norm(u):
    return u[:-1] if (u and u.endswith("/") and u != "/") else u
want = norm(os.environ["SURF_URL"])
try:
    data = json.loads(sys.argv[1])
except Exception:
    data = []
for t in data:
    if norm(t.get("url", "") or "") == want:
        print("%d\t%d" % (t["window"], t["tab"]))
        break
' "$json" 2>/dev/null || true)"
    if [ -n "$res" ]; then printf '%s\t%s\n' "$app" "$res"; return 0; fi
  done < <(_surf_running_apps)
}

# First tab whose URL is a same-origin path-segment prefix of $1, searching
# EVERY running instance ($APP first): the request's scheme://host:port must
# match, and its path must be a prefix of the tab's path at a "/" boundary. So
# open "localhost:3000/dashboard" reuses a tab at "localhost:3000/dashboard/ai-chat"
# (lands on the deeper logged-in page), but "…/ai-chat" does NOT match
# "…/ai-chat-settings". Echoes "<app>\t<W>\t<T>\t<url>" of the first match;
# nothing on no match.
_surf_find_tab_by_prefix() {
  local url="$1" app json res
  while IFS= read -r app; do
    json="$(_surf_tabs_json_for "$app" 2>/dev/null || true)"
    [ -n "$json" ] || continue
    res="$(SURF_URL="$url" python3 -c '
import sys, json, os
from urllib.parse import urlsplit

def norm_path(p):
    # strip a single trailing slash (but keep root "/") so "/a/" == "/a"
    return p[:-1] if (len(p) > 1 and p.endswith("/")) else p

want = urlsplit(os.environ["SURF_URL"])
want_origin = (want.scheme, want.netloc)
want_path = norm_path(want.path or "")
if not want_path:
    sys.exit(0)  # no path to prefix-match (e.g. bare "https://host")
try:
    data = json.loads(sys.argv[1])
except Exception:
    data = []
for t in data:
    u = t.get("url", "") or ""
    cur = urlsplit(u)
    if (cur.scheme, cur.netloc) != want_origin:
        continue
    cp = norm_path(cur.path or "")
    # prefix at a "/" boundary: cp == want_path, or cp starts with want_path + "/"
    if cp == want_path or cp.startswith(want_path + "/"):
        print("%d\t%d\t%s" % (t["window"], t["tab"], u))
        break
' "$json" 2>/dev/null || true)"
    if [ -n "$res" ]; then printf '%s\t%s\n' "$app" "$res"; return 0; fi
  done < <(_surf_running_apps)
}

# ── find-tab: search open tabs by URL or title (substring, case-insensitive),
# across EVERY running Chromium-family instance. Rows from other instances
# carry an "[App]" prefix so refs stay unambiguous; --activate focuses the
# first match in whichever instance it lives. ──
cmd_find_tab() {
  [ "${1-}" ] || die "find-tab needs a query (matched against URL or title)"
  local q="$1" activate=false app json line searched=""
  local -a rows=()
  [ "${2-}" = "--activate" ] && activate=true
  while IFS= read -r app; do
    searched="${searched:+$searched, }$app"
    json="$(_surf_tabs_json_for "$app" 2>/dev/null || true)"
    [ -n "$json" ] || continue
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      # line: "wN.tN\turl\ttitle" — prefix foreign-instance rows with the app
      if [ "$app" != "${_SURF_PICKED_APP:-$APP}" ]; then
        rows+=("[$app] $line")
      else
        rows+=("$line")
      fi
    done < <(printf '%s' "$json" | SURF_Q="$q" python3 -c '
import sys, json, os
q = os.environ["SURF_Q"].lower()
try: data = json.load(sys.stdin)
except Exception: data = []
for t in data:
    u = t.get("url","") or ""; ti = t.get("title","") or ""
    if q in u.lower() or q in ti.lower():
        print("w%d.t%d\t%s\t%s" % (t["window"], t["tab"], u, ti))
' 2>/dev/null || true)
  done < <(_surf_running_apps)
  [ "${#rows[@]}" -gt 0 ] || { echo "surf: find-tab: no tab matches \"$q\" (searched: $searched)" >&2; return 1; }
  printf '%s\n' "${rows[@]}" | awk -F'\t' '{printf "%s  %s  |  %s\n", $1, $2, $3}'
  if $activate; then
    local first ref W T
    first="${rows[0]}"
    case "$first" in
      "["*"]"*) APP="$(printf '%s' "$first" | sed -n 's/^\[\([^]]*\)\].*/\1/p')"
                 first="${first#*] }" ;;
    esac
    ref="${first%%$'\t'*}"
    [[ "$ref" =~ ^w([0-9]+)\.t([0-9]+)$ ]] || { echo "surf: find-tab: bad row \"$first\"" >&2; return 1; }
    W=${BASH_REMATCH[1]}; T=${BASH_REMATCH[2]}
    _surf_activate_tab "$W" "$T"
    if [ "$APP" != "${_SURF_PICKED_APP:-$APP}" ]; then
      echo "activated: w$W.t$T  [$APP]" >&2
    else
      echo "activated: w$W.t$T" >&2
    fi
  fi
}

# ── bookmarks: read/search Chrome bookmarks (file, not browser — no JS toggle needed) ──
cmd_bookmarks() {
  local query="" profile="Default"
  while [ $# -gt 0 ]; do
    case "$1" in
      --profile) profile="${2-}"; shift 2 ;;
      --json) local bm_json=true; shift ;;
      --*) die "bookmarks: unknown flag $1" ;;
      *) query="$1"; shift ;;
    esac
  done
  local base="$HOME/Library/Application Support/Google/Chrome"
  local file="$base/$profile/Bookmarks"
  [ -f "$file" ] || die "bookmarks: no file at $file (use --profile NAME; e.g. Default, 'Profile 1')"
  SURF_Q="$query" SURF_JSON="${bm_json:-false}" python3 - "$file" <<'PY'
import sys, json, os, signal
try: signal.signal(signal.SIGPIPE, signal.SIG_DFL)  # exit silently when piped to head/grep -q
except (ImportError, AttributeError): pass
path = sys.argv[1]
q = os.environ.get("SURF_Q", "").lower()
want_json = os.environ.get("SURF_JSON") == "true"
with open(path, encoding="utf-8") as f:
    data = json.load(f)
hits = []
def walk(node):
    if isinstance(node, dict):
        if node.get("type") == "url":
            name = node.get("name", "") or ""; url = node.get("url", "") or ""
            if (not q) or q in name.lower() or q in url.lower():
                hits.append({"name": name, "url": url})
        for c in node.get("children", []) or []:
            walk(c)
roots = data.get("roots", {}) or {}
for root in roots.values():
    walk(root)
if want_json:
    print(json.dumps(hits, ensure_ascii=False))
else:
    shown = hits[:1000]
    for h in shown:
        print("%s  |  %s" % (h["name"][:80], h["url"]))
    if len(hits) > len(shown):
        sys.stderr.write("bookmarks: %d more — narrow your query\n" % (len(hits) - len(shown)))
PY
}
