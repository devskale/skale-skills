# surf/lib/meta.sh — doctor / batch / setup. Sourced by surf.sh.

cmd_doctor() {
  # One-shot environment + permission diagnostic. Surfaces the 4 prerequisites
  # (macOS, Chrome running, JS toggle, Screen Recording, Accessibility) that users
  # otherwise discover one failure at a time. Uses non-heuristic probes; the JS
  # toggle is checked against a throwaway about:blank tab (never restricted, unlike
  # x.com/incognito/PWA which block JS even when the toggle is ON).
  local fails=0 probe sr_tmp sr_rc
  echo "surf doctor — environment & permission check"
  echo ""
  if [ "$(uname)" = "Darwin" ]; then echo "  ✓ macOS"; else echo "  ✗ macOS — surf is AppleScript-based"; fails=$((fails+1)); fi
  if osascript -e "application \"$APP\" is running" 2>/dev/null | grep -qi true; then
    echo "  ✓ $APP is running"
  else
    echo "  ✗ $APP is not running — open it, then re-run \`surf doctor\`"; fails=$((fails+1))
  fi
  probe="$(osascript <<OSA 2>&1
tell application "$APP"
  if (count of windows) is 0 then make new window
  set t to make new tab at end of tabs of front window with properties {URL:"about:blank"}
  delay 0.25
  set res to "ERR:unknown"
  try
    set res to execute t javascript "1"
  on error e
    set res to "ERR:" & e
  end try
  try
    close t
  end try
  return res
end tell
OSA
)"
  case "$probe" in
    1) echo "  ✓ JavaScript-from-AppleScript toggle is ON" ;;
    *"Allow JavaScript"*|*"turned off"*)
      echo "  ✗ JavaScript-from-AppleScript is OFF — text/click/fill/eval/here need it"
      echo "    → Chrome menu → View → Developer ▸ → Allow JavaScript from Apple Events (✓)"
      fails=$((fails+1)) ;;
    *) echo "  ? JS toggle inconclusive ($probe) — open a normal site, re-run"; fails=$((fails+1)) ;;
  esac
  sr_tmp="$(mktemp -t surfdoc).png"
  sr_rc=0; screencapture -R 0,0,2,2 -o -x "$sr_tmp" >/dev/null 2>&1 || sr_rc=$?
  if [ $sr_rc -eq 0 ] && [ -s "$sr_tmp" ]; then
    echo "  ✓ Screen Recording (screencapture works — shot/shot-el)"
  else
    echo "  ✗ Screen Recording denied — needed for shot / shot-el"
    echo "    → System Settings → Privacy & Security → Screen Recording → enable your terminal"
    fails=$((fails+1))
  fi
  rm -f "$sr_tmp"
  if osascript -e 'tell application "System Events" to UI elements enabled' 2>/dev/null | grep -qi true; then
    echo "  ✓ Accessibility (UI scripting enabled — press / setup)"
  else
    echo "  ✗ Accessibility denied — needed for press (real keystrokes) & setup"
    echo "    → System Settings → Privacy & Security → Accessibility → enable your terminal"
    fails=$((fails+1))
  fi
  echo ""
  if [ "$fails" -eq 0 ]; then echo "  all green ✓"; return 0; fi
  echo "  $fails check(s) failed — fix above, then re-run \`surf doctor\`"
  return 1
}

cmd_batch() {
  # Run a JSON array of steps in ONE `execute javascript` call and return one
  # JSON array of {op, v}. Cuts per-command osascript launch overhead for agent
  # loops while staying daemon-free. Each step is try/catch-wrapped so one bad
  # selector can't abort the batch. Supported: title, url, text, html, attr,
  # count, list, exists, visible, click, fill, hover, eval. Not batchable
  # (different mechanism): press, shot/shot-el, nav (open/new/reload/back/fwd/
  # close), wait*. JS composed in python3 (json.dumps for every literal).
  local input js
  input="$(cat)" || { echo "surf: batch: could not read steps from stdin" >&2; return 1; }
  if [ -z "$input" ]; then
    cat >&2 <<'EOF'
surf batch — run a JSON steps array in ONE browser call (reads + interactions).
Steps arrive on stdin; result is a JSON array of {"op":..,"v":..}.

  surf batch <<'EOF'
  [{"op":"text","sel":"h1"},{"op":"count","sel":"a"},{"op":"eval","js":"document.title"}]
  EOF

Ops: title, url, text(sel), html(sel), attr(sel,name), count(sel), list(sel),
     exists(sel), visible(sel), click(sel), fill(sel,val), hover(sel), eval(js).
Not batchable (use standalone): press, shot/shot-el, open/new/reload/back/fwd/close, wait*.
EOF
    return 1
  fi
  if ! js="$(python3 - "$input" <<'PY'
import sys, json
try:
    steps = json.loads(sys.argv[1])
except Exception as e:
    sys.stderr.write("batch: invalid JSON: %s\n" % e); sys.exit(2)
if not isinstance(steps, list):
    sys.stderr.write("batch: input must be a JSON array\n"); sys.exit(2)

def sel(s): return json.dumps(s.get("sel",""))
def expr_for(s):
    op = s.get("op")
    if op == "title":  e = "document.title"
    elif op == "url":  e = "location.href"
    elif op == "text": e = '(function(){var x=document.querySelector(%s);return x?String(x.textContent).trim().slice(0,10000):"NOT_FOUND"})()' % sel(s)
    elif op == "html": e = '(function(){var x=document.querySelector(%s);return x?x.outerHTML:"NOT_FOUND"})()' % sel(s)
    elif op == "attr": e = '(function(){var x=document.querySelector(%s);return x?String(x.getAttribute(%s)):"NOT_FOUND"})()' % (sel(s), json.dumps(s.get("name","")))
    elif op == "count": e = 'document.querySelectorAll(%s).length' % sel(s)
    elif op == "list":  e = 'Array.prototype.slice.call(document.querySelectorAll(%s),0,1000).map(function(x){return String(x.textContent).trim().slice(0,500)})' % sel(s)
    elif op == "exists": e = 'document.querySelector(%s)!==null' % sel(s)
    elif op == "visible": e = '(function(){var x=document.querySelector(%s);if(!x)return"absent";var s=getComputedStyle(x);if(s.display==="none"||s.visibility==="hidden"||s.opacity==="0")return"hidden";if(x.offsetParent===null&&s.position!=="fixed")return"hidden";return"visible"})()' % sel(s)
    elif op == "click": e = '(function(){var x=document.querySelector(%s);if(!x)return JSON.stringify({ok:false,err:"not_found"});try{x.scrollIntoView({block:"center"})}catch(_){}x.click();return JSON.stringify({ok:true,tag:x.tagName})})()' % sel(s)
    elif op == "fill":  e = '(function(){var x=document.querySelector(%s);if(!x)return JSON.stringify({ok:false,err:"not_found"});x.focus();x.value=%s;x.dispatchEvent(new Event("input",{bubbles:true}));x.dispatchEvent(new Event("change",{bubbles:true}));return JSON.stringify({ok:true,tag:x.tagName})})()' % (sel(s), json.dumps(s.get("val","")))
    elif op == "hover": e = '(function(){var x=document.querySelector(%s);if(!x)return JSON.stringify({ok:false,err:"not_found"});try{x.scrollIntoView({block:"center"})}catch(_){}x.dispatchEvent(new MouseEvent("mouseover",{bubbles:true}));x.dispatchEvent(new MouseEvent("mousemove",{bubbles:true}));x.dispatchEvent(new MouseEvent("mouseenter",{bubbles:true}));return JSON.stringify({ok:true,tag:x.tagName})})()' % sel(s)
    elif op == "eval":  e = "(%s)" % s.get("js","undefined")
    else: return None
    return '(function(){try{return (%s)}catch(err){return JSON.stringify({err:String(err&&err.message||err)})}})()' % e

parts = []
for i, s in enumerate(steps):
    if not isinstance(s, dict) or "op" not in s:
        sys.stderr.write("batch: step %d missing 'op'\n" % i); sys.exit(2)
    e = expr_for(s)
    if e is None:
        sys.stderr.write("batch: step %d op '%s' not supported (use standalone)\n" % (i, s.get("op"))); sys.exit(2)
    parts.append('{"op":%s,"v":(%s)}' % (json.dumps(s["op"]), e))
sys.stdout.write("JSON.stringify([%s])" % ",".join(parts))
PY
  )"; then
    echo "surf: batch: could not build steps (see above)" >&2; return 1
  fi
  run_js "$js"
}

cmd_setup() {
  local out
  out=$(osascript <<APPLESCRIPT 2>&1
tell application "$APP" to activate
delay 0.3
tell application "System Events"
  tell process "$APP"
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
