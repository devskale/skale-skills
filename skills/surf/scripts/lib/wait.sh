# surf/lib/wait.sh — wait / wait-url / wait-stable. Sourced by surf.sh.

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
  # MutationObserver quiet-window. The old innerHTML.length-diff never settled on
  # pages with ads/spinners/clocks (continuous mutation → guaranteed timeout).
  # The observer persists on `window` across discrete `execute javascript` calls
  # (same tab, no navigation), so we install once, poll the time since the last
  # mutation, and disconnect on exit (success or timeout).
  local to="${SURF_WAIT_TIMEOUT:-15}" iv="${SURF_WAIT_INTERVAL:-0.4}" quiet="${SURF_STABLE_QUIET_MS:-700}" deadline delta inst cleanup
  while [ $# -gt 0 ]; do
    case "$1" in --timeout) to="$2"; shift 2 ;; --timeout=*) to="${1#*=}"; shift ;; *) shift ;; esac
  done
  cleanup='(function(){if(window.__surfStableObs){window.__surfStableObs.disconnect();delete window.__surfStableObs;delete window.__surfLastMut}return 1})()'
  inst="$(_run_js_raw '(function(){if(window.__surfStableObs)return"exists";window.__surfLastMut=Date.now();window.__surfStableObs=new MutationObserver(function(){window.__surfLastMut=Date.now()});window.__surfStableObs.observe(document.documentElement,{childList:true,subtree:true,attributes:true,characterData:true});return"installed"})()' 2>/dev/null || true)"
  [ -n "$inst" ] || { echo "surf: wait-stable: could not install observer (JS-from-AppleScript off? run: surf doctor)" >&2; return 1; }
  deadline=$(( $(date +%s) + to ))
  while :; do
    delta="$(_run_js_raw 'String(Date.now()-(window.__surfLastMut||0))' 2>/dev/null || true)"
    if [ "${delta:-999999}" -ge "$quiet" ] 2>/dev/null; then
      _run_js_raw "$cleanup" >/dev/null 2>&1 || true
      echo "stable: quiet for ${delta}ms"
      return 0
    fi
    [ "$(date +%s)" -ge "$deadline" ] && {
      _run_js_raw "$cleanup" >/dev/null 2>&1 || true
      echo "surf: wait-stable timeout (${to}s): DOM still mutating (last change ${delta:-?}ms ago)" >&2; return 1; }
    sleep "$iv"
  done
}
