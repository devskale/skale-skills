# surf/lib/assert.sh — exists / visible / assert (each supports --json; exit codes preserved). Sourced by surf.sh.

cmd_exists() {
  [ "${1-}" ] || die "exists needs a selector"
  local sel; for a in "$@"; do [ "$a" != "--json" ] && sel="$a"; done
  local r; r="$(run_js "$(printf 'String(document.querySelector(%s)!==null)' "$(js_str "$sel")")")"
  if _want_json "$@"; then
    printf '{"selector":%s,"exists":%s}\n' "$(js_str "$sel")" "$r"
  elif [ "$r" = "true" ]; then
    echo "exists: $sel"
  else
    echo "surf: not found: $sel" >&2
  fi
  [ "$r" = "true" ] && return 0 || return 1
}

cmd_visible() {
  [ "${1-}" ] || die "visible needs a selector"
  local sel; for a in "$@"; do [ "$a" != "--json" ] && sel="$a"; done
  local r; r="$(run_js "$(printf '(function(){var e=document.querySelector(%s);if(!e)return"absent";var s=getComputedStyle(e);if(s.display==="none"||s.visibility==="hidden"||s.opacity==="0")return"hidden";if(e.offsetParent===null&&s.position!=="fixed")return"hidden";return"visible"})()' "$(js_str "$sel")")")"
  if _want_json "$@"; then
    local b; [ "$r" = "visible" ] && b=true || b=false
    printf '{"selector":%s,"visible":%s,"reason":"%s"}\n' "$(js_str "$sel")" "$b" "$r"
  elif [ "$r" = "visible" ]; then
    echo "visible: $sel"
  else
    echo "surf: not visible ($r): $sel" >&2
  fi
  [ "$r" = "visible" ] && return 0 || return 1
}

cmd_assert() {
  [ "${1-}" ] || die "assert needs a JS expression (optional expected value)"
  local js="" expected="" got pass want_json=false seen_js=false a
  for a in "$@"; do
    case "$a" in
      --json) want_json=true ;;
      *) if ! $seen_js; then js="$a"; seen_js=true; else [ -z "$expected" ] && expected="$a"; fi ;;
    esac
  done
  got="$(run_js "String($js)" 2>/dev/null || true)"
  if [ -n "$expected" ]; then
    [ "$got" = "$expected" ] && pass=true || pass=false
  else
    case "$got" in ""|"false"|"0"|"null"|"undefined"|"NaN") pass=false ;; *) pass=true ;; esac
  fi
  if $want_json; then
    printf '{"js":%s,"expected":%s,"got":%s,"pass":%s}\n' "$(js_str "$js")" "$(js_str "$expected")" "$(js_str "$got")" "$pass"
  elif $pass; then
    if [ -n "$expected" ]; then echo "assert ok: $js == $expected"; else echo "assert ok: $js ($got)"; fi
  else
    if [ -n "$expected" ]; then echo "surf: assert FAIL: $js -> '$got' (expected '$expected')" >&2; else echo "surf: assert FAIL: $js -> '$got'" >&2; fi
  fi
  $pass && return 0 || return 1
}
