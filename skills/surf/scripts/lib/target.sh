# surf/lib/target.sh — target tab resolution + select. Sourced by surf.sh.
#
# Stale-target resilience: the file stores "W T URL" (URL captured at select
# time). Window/tab indices drift when tabs are reordered or closed, so before
# operating a pinned tab we verify the URL at those indices still matches; on
# mismatch we re-resolve by URL (re-pin) or warn. "front" is never verified
# (zero cost — the default path). Resolution is cached per-process so wait
# loops pay it once, not per-poll.

_target_raw() {  # "front" | "W T [url]" — raw file contents, no verification
  if [ -f "$TARGET_FILE" ] && [ -s "$TARGET_FILE" ]; then cat "$TARGET_FILE"
  else echo "front"; fi
}

# Re-resolve a drifted target by its stored URL.
#   $1=stored_url  $2=W  $3=T  $4=cur_url (maybe empty)
# Echoes the "W T" to use, rewrites the target file, warns on stderr.
_repin() {
  # Re-resolve a drifted target by its stored URL. Bulletproof: NEVER deletes the
  # target on uncertainty (that would silently switch later ops to the front tab).
  # Uses cmd_tabs in-process (no subprocess re-entry) and guards all parsing.
  local url="$1" W="$2" T="$3" cur="$4" tabs_json res nW nT
  tabs_json="$(cmd_tabs --json 2>/dev/null || true)"
  res="$(python3 - "$tabs_json" "$url" 2>/dev/null <<'PY' || true
import sys,json
try: data=json.loads(sys.argv[1])
except Exception: data=[]
u=sys.argv[2]
hits=[(t["window"],t["tab"]) for t in data if t.get("url")==u]
n=len(hits)
print(("1 %d %d" % hits[0]) if n==1 else ("0" if n==0 else "many"))
PY
)"
  case "${res%% *}" in
    1) nW=$(printf '%s' "$res" | awk '{print $2}'); nT=$(printf '%s' "$res" | awk '{print $3}')
       printf '%s %s %s\n' "$nW" "$nT" "$url" > "$TARGET_FILE"
       echo "surf: target drifted (w$W.t$T → w$nW.t$nT); re-pinned by URL" >&2
       echo "$nW $nT" ;;
    many) echo "surf: target ambiguous — $url open in multiple tabs; using w$W.t$T (re-select to pin)" >&2
          printf '%s %s %s\n' "$W" "$T" "$cur" > "$TARGET_FILE"; echo "$W $T" ;;
    *) # 0 (not found) or parse failure. If the tab still lives at W,T it navigated
       # in place → follow it silently (it's the same tab). Only drop to front if gone.
       if [ -n "$cur" ]; then
         printf '%s %s %s\n' "$W" "$T" "$cur" > "$TARGET_FILE"; echo "$W $T"
       else
         echo "surf: target tab w$W.t$T is gone and URL not found — re-select" >&2
         rm -f "$TARGET_FILE"; echo "front"
       fi ;;
  esac
}

# Resolve once: verify the pinned tab's URL, re-pin on drift. → "front" | "W T".
_resolve_target_once() {
  local raw W T stored cur
  raw="$(_target_raw)"
  [ "$raw" = "front" ] && { echo "front"; return; }
  W=$(printf '%s' "$raw" | awk '{print $1}')
  T=$(printf '%s' "$raw" | awk '{print $2}')
  stored=$(printf '%s' "$raw" | cut -d' ' -f3-)   # empty for legacy 2-field files
  cur="$(osascript -e "tell application \"$APP\" to get URL of tab $T of window $W" 2>/dev/null || true)"
  if [ -z "$cur" ]; then
    # tab/window no longer exists at those indices
    if [ -n "$stored" ]; then _repin "$stored" "$W" "$T" ""
    else echo "surf: target tab w$W.t$T no longer exists — re-select" >&2; rm -f "$TARGET_FILE"; echo "front"; fi
    return
  fi
  if [ -z "$stored" ] || [ "$cur" = "$stored" ]; then
    [ -z "$stored" ] && printf '%s %s %s\n' "$W" "$T" "$cur" > "$TARGET_FILE"   # adopt url for legacy files
    echo "$W $T"; return
  fi
  _repin "$stored" "$W" "$T" "$cur"
}

# Resolved target, cached per-process (so wait loops verify once, not per-poll).
get_target() {
  [ -n "${_SURF_RESOLVED:-}" ] && { echo "$_SURF_RESOLVED"; return; }
  _SURF_RESOLVED="$(_resolve_target_once)"
  echo "$_SURF_RESOLVED"
}

cmd_select() {
  local arg="${1-}"
  if [ -z "$arg" ] || [ "$arg" = "show" ]; then
    if [ -f "$TARGET_FILE" ] && [ -s "$TARGET_FILE" ]; then echo "target: $(cat "$TARGET_FILE")"
    else echo "target: none (active tab of front window)"; fi
    return
  fi
  if [ "$arg" = "reset" ] || [ "$arg" = "active" ] || [ "$arg" = "-" ]; then
    rm -f "$TARGET_FILE"; echo "target reset → active tab of front window"; return
  fi
  if [[ "$arg" =~ ^w([0-9]+)\.t([0-9]+)$ ]]; then
    local W=${BASH_REMATCH[1]} T=${BASH_REMATCH[2]} U
    U="$(osascript -e "tell application \"$APP\" to get URL of tab $T of window $W" 2>/dev/null || true)"
    mkdir -p "$(dirname "$TARGET_FILE")"
    printf '%s %s %s\n' "$W" "$T" "$U" > "$TARGET_FILE"
    echo "target → window $W, tab $T  ($U)"
  else
    die "select: expected wN.tN (e.g. w1.t3), reset, or blank. List refs with: surf tabs"
  fi
}
