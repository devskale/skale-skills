# surf/lib/read.sh — title/url/text/html/attr/count/list/eval. Sourced by surf.sh.

cmd_title()  { run_js 'document.title'; }
cmd_url()    { run_js 'location.href'; }

cmd_text() {
  [ "${1-}" ] || die "text needs a selector"
  local sel
  for a in "$@"; do [ "$a" != "--json" ] && sel="$a"; done
  if _want_json "$@"; then
    run_js "$(printf '(function(){var s=%s;var e=document.querySelector(s);return JSON.stringify({selector:s,found:!!e,text:e?String(e.textContent).trim().slice(0,10000):null})})()' "$(js_str "$sel")")"
    return
  fi
  run_js "$(printf '(function(){var e=document.querySelector(%s);return e?String(e.textContent).trim().slice(0,10000):"NOT_FOUND"})()' "$(js_str "$sel")")"
}
cmd_html()  { [ "${1-}" ] || die "html needs a selector"; run_js "$(printf '(function(){var e=document.querySelector(%s);return e?e.outerHTML:"NOT_FOUND"})()' "$(js_str "$1")")"; }
cmd_count() {
  [ "${1-}" ] || die "count needs a selector"
  local sel
  for a in "$@"; do [ "$a" != "--json" ] && sel="$a"; done
  if _want_json "$@"; then
    run_js "$(printf 'JSON.stringify({selector:%s,count:document.querySelectorAll(%s).length})' "$(js_str "$sel")" "$(js_str "$sel")")"
    return
  fi
  run_js "$(printf '(function(){return String(document.querySelectorAll(%s).length)})()' "$(js_str "$sel")")"
}
cmd_attr()  { [ "${1-}" ] && [ "${2-}" ] || die "attr needs <selector> <name>"; run_js "$(printf '(function(){var e=document.querySelector(%s);return e?String(e.getAttribute(%s)):"NOT_FOUND"})()' "$(js_str "$1")" "$(js_str "$2")")"; }
cmd_list() {
  [ "${1-}" ] || die "list needs a selector"
  run_js "$(printf 'JSON.stringify(Array.prototype.slice.call(document.querySelectorAll(%s),0,1000).map(function(e){return String(e.textContent).trim().slice(0,500)}))' "$(js_str "$1")")"
}
cmd_eval()  { [ "${1-}" ] || die "eval needs js"; run_js "$1"; }
