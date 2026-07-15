# surf/lib/assert.sh — exists / visible / assert. Sourced by surf.sh.

cmd_exists() {
  [ "${1-}" ] || die "exists needs a selector"
  local r; r="$(run_js "$(printf 'String(document.querySelector(%s)!==null)' "$(js_str "$1")")")"
  [ "$r" = "true" ] && { echo "exists: $1"; return 0; }
  echo "surf: not found: $1" >&2; return 1
}

cmd_visible() {
  [ "${1-}" ] || die "visible needs a selector"
  local r; r="$(run_js "$(printf '(function(){var e=document.querySelector(%s);if(!e)return"absent";var s=getComputedStyle(e);if(s.display==="none"||s.visibility==="hidden"||s.opacity==="0")return"hidden";if(e.offsetParent===null&&s.position!=="fixed")return"hidden";return"visible"})()' "$(js_str "$1")")")"
  case "$r" in
    visible) echo "visible: $1"; return 0 ;;
    absent)  echo "surf: not found: $1" >&2; return 1 ;;
    *)       echo "surf: not visible ($r): $1" >&2; return 1 ;;
  esac
}

cmd_assert() {
  [ "${1-}" ] || die "assert needs a JS expression (optional expected value)"
  local js="$1" expected="${2-}" got
  got="$(run_js "String($js)" 2>/dev/null || true)"
  if [ -n "$expected" ]; then
    [ "$got" = "$expected" ] && { echo "assert ok: $js == $expected"; return 0; }
    echo "surf: assert FAIL: $js -> '$got' (expected '$expected')" >&2; return 1
  fi
  case "$got" in ""|"false"|"0"|"null"|"undefined"|"NaN") echo "surf: assert FAIL: $js -> '$got'" >&2; return 1 ;; esac
  echo "assert ok: $js ($got)"; return 0
}
