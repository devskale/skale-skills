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

  # Reuse by default — two tiers, tried in order (--new skips both):
  #   1. exact URL match (trailing slash ignored)
  #   2. same-origin path-segment prefix: the request path is a prefix of an
  #      open tab's path at a "/" boundary — e.g. open "localhost:3000/dashboard"
  #      reuses a tab at "localhost:3000/dashboard/ai-chat". Lands on the deeper
  #      (already logged-in) page instead of duplicating.
  if ! $force_new; then
    local hit W T taburl
    # Tier 1: exact.
    hit="$(_surf_find_tab_by_url "$url")"
    if [ -n "$hit" ]; then
      W="$(printf '%s' "$hit" | awk '{print $1}')"
      T="$(printf '%s' "$hit" | awk '{print $2}')"
      _surf_activate_tab "$W" "$T"
      _surf_pin_target "$W" "$T" "$url"
      echo "reuse: w$W.t$T  $url"
      return 0
    fi
    # Tier 2: same-origin path-segment prefix.
    hit="$(_surf_find_tab_by_prefix "$url")"
    if [ -n "$hit" ]; then
      W="$(printf '%s' "$hit" | cut -f1)"
      T="$(printf '%s' "$hit" | cut -f2)"
      taburl="$(printf '%s' "$hit" | cut -f3-)"
      _surf_activate_tab "$W" "$T"
      _surf_pin_target "$W" "$T" "$taburl"
      echo "reuse: w$W.t$T  $url  →  $taburl"
      return 0
    fi
  fi

  # No reusable tab: navigate the target tab (current behavior).
  local tgt W T; tgt="$(get_target)"
  if [ "$tgt" = "front" ]; then
    osascript -e "tell application \"$APP\" to set URL of active tab of front window to \"$url\"" >/dev/null && echo "ok: $url"
  else
    W="$(echo "$tgt" | cut -d' ' -f1)"; T="$(echo "$tgt" | cut -d' ' -f2)"
    osascript -e "tell application \"$APP\" to set URL of tab $T of window $W to \"$url\"" >/dev/null && echo "ok (w$W.t$T): $url"
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

# ── tab helpers (shared by find-tab and open's reuse path) ─────────────

# Bring window W to the front and make tab T its active tab. Best-effort
# (ignore errors — used for focusing a reused/matched tab).
_surf_activate_tab() {
  osascript -e "tell application \"$APP\" to set index of window $1 to 1" >/dev/null 2>&1 || true
  osascript -e "tell application \"$APP\" to set active tab index of window $1 to $2" >/dev/null 2>&1 || true
  osascript -e "tell application \"$APP\" to activate" >/dev/null 2>&1 || true
}

# First tab whose URL exactly matches $1. A single trailing slash is ignored on
# both sides, so "https://x.com" matches a tab showing "https://x.com/". Echoes
# "W T" on the first match; nothing on no match. Uses cmd_tabs --json (in-process).
# JSON is passed as argv (not stdin) to avoid stdin contention with cmd_tabs'
# internal osascript|python pipe.
_surf_find_tab_by_url() {
  local tabs_json
  tabs_json="$(cmd_tabs --json 2>/dev/null || true)"
  [ -n "$tabs_json" ] || return 0
  SURF_URL="$1" python3 -c '
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
        print("%d %d" % (t["window"], t["tab"]))
        break
' "$tabs_json"
}

# First tab whose URL is a same-origin path-segment prefix of $1: the request's
# scheme://host:port must match, and its path must be a prefix of the tab's path
# at a "/" boundary. So open "localhost:3000/dashboard" reuses a tab at
# "localhost:3000/dashboard/ai-chat" (lands on the deeper logged-in page), but
# "…/ai-chat" does NOT match "…/ai-chat-settings". Echoes "W<TAB>T<TAB>url" of
# the first match; nothing on no match.
_surf_find_tab_by_prefix() {
  local tabs_json
  tabs_json="$(cmd_tabs --json 2>/dev/null || true)"
  [ -n "$tabs_json" ] || return 0
  SURF_URL="$1" python3 -c '
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
' "$tabs_json"
}

# ── find-tab: search open tabs by URL or title (substring, case-insensitive) ──
cmd_find_tab() {
  [ "${1-}" ] || die "find-tab needs a query (matched against URL or title)"
  local q="$1" activate=false rows first W T
  [ "${2-}" = "--activate" ] && activate=true
  rows="$(cmd_tabs --json 2>/dev/null | SURF_Q="$q" python3 -c '
import sys, json, os
q = os.environ["SURF_Q"].lower()
try: data = json.load(sys.stdin)
except Exception: data = []
for t in data:
    u = t.get("url","") or ""; ti = t.get("title","") or ""
    if q in u.lower() or q in ti.lower():
        print("%d\t%d\t%s\t%s" % (t["window"], t["tab"], u, ti))
')"
  [ -n "$rows" ] || { echo "surf: find-tab: no tab matches \"$q\"" >&2; return 1; }
  printf '%s\n' "$rows" | awk -F'\t' '{printf "w%d.t%d  %s  |  %s\n", $1, $2, $3, $4}'
  if $activate; then
    first="$(printf '%s\n' "$rows" | head -1)"
    W="$(printf '%s\n' "$first" | cut -f1)"; T="$(printf '%s\n' "$first" | cut -f2)"
    _surf_activate_tab "$W" "$T"
    echo "activated: w$W.t$T" >&2
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
