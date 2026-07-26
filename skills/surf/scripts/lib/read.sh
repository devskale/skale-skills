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

# ── cookie: read document.cookie (JS-readable = non-HttpOnly only) ──────────────
# HttpOnly cookies (sessions, auth) are NOT visible to JS by design — that's the
# browser protecting them, not a surf bug. For those you need a CDP tool.
cmd_cookie() {
  local name="" json=false
  for a in "$@"; do case "$a" in --json) json=true ;; *) name="$a" ;; esac; done
  if [ -n "$name" ]; then
    run_js "$(printf '(function(){var m=document.cookie.split(/;\\s*/);for(var i=0;i<m.length;i++){var p=m[i];var idx=p.indexOf("=");var k=decodeURIComponent(idx<0?p:p.slice(0,idx));if(k===%s)return decodeURIComponent(idx<0?"":p.slice(idx+1))}return "NOT_FOUND"})()' "$(js_str "$name")")"
  elif $json; then
    run_js '(function(){var o={};document.cookie.split(/;\s*/).forEach(function(p){if(!p)return;var idx=p.indexOf("=");var k=decodeURIComponent(idx<0?p:p.slice(0,idx));o[k]=idx<0?"":decodeURIComponent(p.slice(idx+1))});return JSON.stringify(o)})()'
  else
    run_js 'document.cookie || "(no readable cookies — HttpOnly cookies are hidden from JS)"'
  fi
}

# ── localstorage: read window.localStorage (fully JS-accessible) ───────────────
cmd_localstorage() {
  local key="" json=false
  for a in "$@"; do case "$a" in --json) json=true ;; *) key="$a" ;; esac; done
  if [ -n "$key" ]; then
    run_js "$(printf '(function(){var v=localStorage.getItem(%s);return v===null?"NOT_FOUND":v})()' "$(js_str "$key")")"
  else
    # dump all keys; cap each value at 2000 chars to stay agent-friendly
    run_js '(function(){var o={};for(var i=0;i<localStorage.length;i++){var k=localStorage.key(i);var v=localStorage.getItem(k)||"";o[k]=v.length>2000?v.slice(0,2000)+"…[truncated]":v}return JSON.stringify(o)})()'
  fi
}
