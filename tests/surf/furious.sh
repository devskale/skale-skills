#!/usr/bin/env bash
# Surf — furious live validation. Exercises every command, edge cases, the
# background-tab-no-focus guarantee, launcher flags, and pi skill discovery.
# All browser ops happen on throwaway test tabs; your real tabs are untouched.
set -u

PASS=0; FAIL=0; SKIPPED=0
mark() { if [ "$2" = "pass" ]; then PASS=$((PASS+1)); elif [ "$2" = "skip" ]; then SKIPPED=$((SKIPPED+1)); printf "  · %s\n" "$1"; else FAIL=$((FAIL+1)); printf "  ✗ %s\n" "$1"; fi; }
chk() { if eval "$2"; then mark "$1" pass; else mark "$1" FAIL; fi; }
section() { printf "\n── %s ──\n" "$1"; }

# ── tab helpers (surf tabs --json → no regex, no index drift) ─────────
# first wN.tN ref whose URL contains $1
surf_tab() {
  surf tabs --json | python3 -c '
import sys,json
s=sys.argv[1]
for t in json.load(sys.stdin):
    if s in t["url"]:
        print("w%d.t%d"%(t["window"],t["tab"])); break
' "$1" 2>/dev/null
}
# close ALL tabs whose URL contains $1 (re-fetch after each close → index-safe)
surf_close_url() {
  local r
  while :; do r=$(surf_tab "$1"); [ -z "$r" ] && break
    surf select "$r" >/dev/null 2>&1; surf close >/dev/null 2>&1; done
}

REPO="$(realpath "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null)"
[ -z "$REPO" ] && REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SKILL="$REPO/skills/surf"

# ── preconditions ────────────────────────────────────────────────────
if ! command -v surf >/dev/null 2>&1; then echo "surf not on PATH"; exit 2; fi
if [ "$(uname)" != "Darwin" ]; then echo "macOS-only; aborting"; exit 2; fi
# JS-capable check that tolerates a restricted active tab (x.com / app window / incognito
# all return the misleading "turned off" error). Scan open tabs for one that allows JS.
JS_OK=false
for JS_REF in $(surf tabs | grep -oE 'w[0-9]+\.t[0-9]+' | head -12); do
  if surf select "$JS_REF" >/dev/null 2>&1 && surf eval '1' >/dev/null 2>&1; then JS_OK=true; break; fi
done
surf select reset >/dev/null 2>&1 || true
if [ "$JS_OK" = false ]; then
  echo "No JS-capable tab found. Either the toggle is off (View→Developer→Allow JS),"
  echo "or every open tab is restricted (x.com / app window / incognito). Open a normal site, re-run."
  exit 2
fi

# snapshot the user's current tab count so we can prove we left their session alone
TABS_BEFORE=$(surf tabs | wc -l | tr -d ' ')

section "A. pi skill discovery (1st-class)"
chk "discoverable (symlink OR package clone)" "[ -L '$HOME/.pi/agent/skills/surf' ] || [ -f '$HOME/.pi/agent/git/github.com/devskale/skale-skills/skills/surf/SKILL.md' ]"
chk "frontmatter: name: surf"   "grep -q '^name: surf' '$SKILL/SKILL.md'"
chk "frontmatter: description"  "grep -q '^description:' '$SKILL/SKILL.md'"
chk "whitelist has surf"        "grep -q '\"surf\"' '$HOME/.pi/agent/settings.json'"
chk "command on PATH"           "command -v surf >/dev/null"
chk "launcher exec bit"         "[ -x '$SKILL/surf' ]"
chk "logic script exec bit"     "[ -x '$SKILL/scripts/surf.sh' ]"
chk "install.sh present"        "[ -f '$SKILL/install.sh' ]"
chk "references present"        "[ -f '$SKILL/references/commands.md' ]"

section "B. launcher flags"
chk "--version prints"          "surf --version | grep -q 'surf'"
chk "--selfcheck prints dir"    "surf --selfcheck | grep -q 'skills/surf'"
chk "help lists click & fill"   "surf help | grep -q 'surf click' && surf help | grep -q 'surf fill'"

section "C. open test tabs (throwaway)"
# bring a JS-capable window to front so `surf new` opens test tabs there (not an app/restricted window)
JS_W=${JS_REF#w}; JS_W=${JS_W%%.*}
osascript -e "tell application \"Google Chrome\" to set index of window $JS_W to 1" >/dev/null 2>&1 || true
sleep 0.3
surf new "https://example.com/" >/dev/null; sleep 1.5
surf new "https://html.duckduckgo.com/html/" >/dev/null; sleep 1.5
EX=$(surf_tab example.com)
DDG=$(surf_tab duckduckgo)
chk "example.com tab opened"    "[ -n '$EX' ]"
chk "duckduckgo tab opened"     "[ -n '$DDG' ]"

section "D. reads on example.com (pinned)"
surf select "$EX" >/dev/null
chk "title = Example Domain"    "[ \"\$(surf title)\" = 'Example Domain' ]"
chk "url contains example.com"  "surf url | grep -q 'example.com'"
chk "text h1 = Example Domain"  "[ \"\$(surf text 'h1')\" = 'Example Domain' ]"
chk "count p = 2"               "[ \"\$(surf count 'p')\" = '2' ]"
chk "count a = 1"               "[ \"\$(surf count 'a')\" = '1' ]"
chk "attr a href is iana"       "surf attr 'a' 'href' | grep -q 'iana'"
HTMLH1=$(surf html 'h1' | head -c 40)
chk "html h1 starts with tag"   "echo \"$HTMLH1\" | grep -q '<h1>'"
chk "here returns example.com"  "surf here | grep -q 'example.com'"
chk "wait h1 found (exit 0)"     "surf wait 'h1' --timeout 5 >/dev/null"
chk "wait missing → timeout exit 1" "surf wait '.zz-nope' --timeout 2 >/dev/null 2>&1; [ \$? -eq 1 ]"
chk "wait-url example (exit 0)"  "surf wait-url 'example' --timeout 4 >/dev/null"
chk "scroll down returns ok"     "surf scroll down >/dev/null"
chk "scroll-to h1 → ok"          "surf scroll-to 'h1' | grep -q '\"ok\":true'"
chk "scroll-to missing → ok:false" "surf scroll-to '.zz-nope' | grep -q '\"ok\":false'"
chk "exists h1 (exit 0)"       "surf exists 'h1' >/dev/null"
chk "exists missing (exit 1)"  "surf exists '.zz-nope' >/dev/null 2>&1; [ \$? -eq 1 ]"
chk "visible h1 (exit 0)"      "surf visible 'h1' >/dev/null"
chk "assert eq ok"             "surf assert '1+1' '2' >/dev/null"
chk "assert eq fail (exit 1)"  "surf assert '1+1' '3' >/dev/null 2>&1; [ \$? -eq 1 ]"
chk "assert truthy"            "surf assert '1' >/dev/null"


section "D2. --json output"
surf select "$EX" >/dev/null
chk "tabs --json valid array"   "surf tabs --json | python3 -m json.tool >/dev/null"
chk "here --json url+title"     "surf here --json | grep -q 'url.:' && surf here --json | grep -q 'title.:'"
chk "text --json found+text"    "surf text 'h1' --json | grep -q 'found.:true' && surf text 'h1' --json | grep -q 'text.:'"
chk "count --json count key"    "surf count 'p' --json | grep -q 'count.:'"
chk "list p valid array"     "surf list 'p' | python3 -m json.tool >/dev/null"
chk "list a has Learn more"  "surf list 'a' | grep -q 'Learn more'"
chk "list missing -> []"     "surf list '.zz-nope' | grep -qE '^\[\]$'"

section "E. navigation: click → iana → back"
chk "click a → ok"              "surf click 'a' | grep -q '\"ok\":true'"
sleep 1.2
chk "navigated to iana"         "surf url | grep -q 'iana'"
chk "back returns to example"   "surf back >/dev/null; sleep 1.5; surf url | grep -q 'example.com'"
chk "fwd → iana again"          "surf fwd >/dev/null; sleep 1.5; surf url | grep -q 'iana'"
surf back >/dev/null; sleep 1.2
chk "reload works"              "surf reload >/dev/null; sleep 1.0; surf title >/dev/null"

section "F. fill on duckduckgo (pinned)"
surf select "$DDG" >/dev/null
chk "fill input sets value"     "surf fill 'input[name=q]' 'skyvern browser agent' | grep -q '\"ok\":true'"
VAL=$(surf eval '(function(){var e=document.querySelector("input[name=q]");return e?e.value:"NONE"})()')
chk "value actually persisted"  "[ \"\$VAL\" = 'skyvern browser agent' ]"
chk "fill fires change (no crash)" "surf eval 'document.querySelector(\"input[name=q]\").value.length>0' | grep -q 'true'"

section "F2. form verbs (hover/select-option/submit) on example.com"
surf select "$EX" >/dev/null
chk "hover h1 ok"               "surf hover 'h1' | grep -q 'ok.:true'"
surf eval '(function(){var s=document.createElement("select");s.id="sf";s.innerHTML="<option value=a>a</option><option value=b>b</option>";document.body.appendChild(s);return 1})()' >/dev/null
chk "select-option sets b"      "surf select-option '#sf' b | grep -q 'ok.:true'"
chk "select-option value is b"  "surf select-option '#sf' b | grep -q 'value.:.b'"
chk "select-option non-select"  "surf select-option 'h1' x | grep -q 'not_select'"
surf eval '(function(){var f=document.createElement("form");f.id="ff";f.addEventListener("submit",function(e){e.preventDefault();window.__s=true});document.body.appendChild(f);return 1})()' >/dev/null
chk "submit fires"              "surf submit '#ff' | grep -q 'ok.:true'"
chk "submit event really fired" "surf eval 'String(window.__s===true)' | grep -q 'true'"
chk "submit missing"            "surf submit '.zz-nope' | grep -q 'not_found'"
chk "press enter (keycode)"   "surf press enter | grep -q 'pressed: enter'"
chk "press escape (keycode)"  "surf press escape | grep -q 'pressed: escape'"

section "G. eval shapes & escaping"
chk "eval math"                 "[ \"\$(surf eval '1+1')\" = '2' ]"
chk "eval JSON round-trip"      "surf eval 'JSON.stringify({a:1,b:[2,3]})' | grep -q '\"b\":\\[2,3\\]'"
chk "eval with double quotes"   "surf eval 'var s=\"hi \\\"there\\\"\"; s' | grep -q 'hi'"
chk "eval returns null-ish"     "surf eval 'String(document.querySelector(\".nope-xyz\")===null)' | grep -q 'true'"

section "H. edge cases & error handling"
chk "text missing → NOT_FOUND"  "[ \"\$(surf text '.does-not-exist-xyz')\" = 'NOT_FOUND' ]"
chk "count missing → 0"         "[ \"\$(surf count '.does-not-exist-xyz')\" = '0' ]"
chk "click missing → ok:false"  "surf click '.does-not-exist-xyz' | grep -q '\"ok\":false'"
chk "fill missing → ok:false"   "surf fill '.does-not-exist-xyz' 'x' | grep -q '\"ok\":false'"
chk "attr missing → NOT_FOUND"  "[ \"\$(surf attr '.does-not-exist-xyz' 'href')\" = 'NOT_FOUND' ]"
surf open "https://example.com/" >/dev/null; sleep 0.8
chk "unknown cmd → exit 1"      "surf bogus-xyz >/dev/null 2>&1; [ \$? -ne 0 ]"
chk "open no-arg → exit 1"      "surf open >/dev/null 2>&1; [ \$? -ne 0 ]"
chk "fill 1-arg → exit 1"       "surf fill 'input' >/dev/null 2>&1; [ \$? -ne 0 ]"

section "I. background-tab no-focus guarantee"
# pin the example tab while ddg (or another) is the front-active tab; operate
# example, then prove the FRONT window's active tab never changed.
surf select "$EX" >/dev/null
FRONT_BEFORE=$(osascript -e 'tell application "Google Chrome" to get URL of active tab of front window')
_=$(surf text 'h1')          # operate the background tab
_=$(surf eval 'document.title')
FRONT_AFTER=$(osascript -e 'tell application "Google Chrome" to get URL of active tab of front window')
chk "front active tab unchanged during bg op" "[ \"\$FRONT_BEFORE\" = \"\$FRONT_AFTER\" ]"
chk "bg tab read returned right title" "[ \"\$(surf title)\" = 'Example Domain' ]"
surf select reset >/dev/null
chk "select reset clears target" "surf select | grep -q 'none'"

section "J. select state + bad refs"
surf select "w1" >/dev/null 2>&1; RC=$?
chk "select malformed ref rejected" "[ $RC -ne 0 ]"
chk "select w1.t1 accepted"   "surf select 'w1.t1' | grep -q 'window 1, tab 1'"
surf select reset >/dev/null

section "K. rapid fire (rodney-style re-entrancy)"
N=0
for i in $(seq 1 8); do
  surf eval 'document.querySelectorAll("a").length' >/dev/null 2>&1 && N=$((N+1))
done
chk "8 rapid evals succeed"     "[ $N -eq 8 ]"

section "L. shot (Screen Recording gate)"
surf shot /tmp/surf-furious.png >/tmp/surf-shot.log 2>&1; RC=$?
if [ $RC -eq 0 ] && [ -f /tmp/surf-furious.png ]; then
  mark "shot produced a PNG" pass
else
  # expected on machines without Screen Recording — must FAIL GRACEFULLY + guide
  chk "shot fails gracefully w/ guidance" "grep -qi 'Screen Recording' /tmp/surf-shot.log"
fi


section "L2. shot-el (element screenshot)"
surf select "$EX" >/dev/null
chk "shot-el h1 -> PNG"       "surf shot-el 'h1' /tmp/surf-el.png >/dev/null 2>&1 && sips -g pixelWidth /tmp/surf-el.png >/dev/null 2>&1"
chk "shot-el missing -> fail" "surf shot-el '.zz-nope' /tmp/x.png >/dev/null 2>&1; [ \$? -ne 0 ]"

section "N. v1.2 — doctor / batch / wait-stable"

# doctor: runs; the JS-toggle line is deterministic given the suite's JS_OK precondition.
DOC=$(surf doctor 2>&1)
chk "doctor prints header"         'echo "$DOC" | grep -q "surf doctor"'
chk "doctor sees JS toggle ON"     'echo "$DOC" | grep -q "JavaScript-from-AppleScript toggle is ON"'

# batch: one call, multiple ops, typed JSON (string/number/bool).
surf select "$EX" >/dev/null
BATCH=$(printf '%s' '[{"op":"title"},{"op":"count","sel":"a"},{"op":"text","sel":"h1"},{"op":"exists","sel":"h1"}]' | surf batch)
chk "batch op:title present"       'echo "$BATCH" | grep -q "\"op\":\"title\""'
chk "batch title = Example Domain"  'echo "$BATCH" | grep -q "Example Domain"'
chk "batch count a is number 1"    'echo "$BATCH" | grep -q "\"op\":\"count\",\"v\":1"'
chk "batch exists is bool true"    'echo "$BATCH" | grep -q "\"op\":\"exists\",\"v\":true"'
chk "batch invalid op rejected"    "printf '%s' '[{\"op\":\"press\"}]' | surf batch >/dev/null 2>&1; [ \$? -eq 1 ]"

# wait-stable: MutationObserver quiet-window + observer cleanup on success.
chk "wait-stable static → exit 0"  "surf wait-stable --timeout 8 | grep -q '^stable:'"
chk "wait-stable cleans observer" "[ \"\$(surf eval 'String(typeof window.__surfStableObs)')\" = 'undefined' ]"

# wait-stable: timeout on a continuously-mutating page. $EX must be FOREGROUND or
# Chrome throttles the setInterval to ~1/sec → false "stable". (Observer fires on
# document.title — ground-truth delta stays ~32ms while mutating vs ~750ms idle.)
EX_W=${EX#w}; EX_W=${EX_W%%.*}; EX_T=${EX#*.t}
osascript -e "tell application \"Google Chrome\" to set active tab index of window $EX_W to $EX_T" >/dev/null 2>&1 || true
surf eval 'window.__m=setInterval(function(){document.title=String(Math.random())},40);1' >/dev/null
chk "wait-stable mutation → exit 1" "surf wait-stable --timeout 3 >/dev/null 2>&1; [ \$? -eq 1 ]"
surf eval 'clearInterval(window.__m);document.title="Example Domain";1' >/dev/null   # reset title

# focus: batch + wait-stable operate a pinned BACKGROUND tab without stealing focus.
# make DDG the visible tab up front, then operate pinned $EX (a different tab) in background.
DDG_W=${DDG#w}; DDG_W=${DDG_W%%.*}; DDG_T=${DDG#*.t}
osascript -e "tell application \"Google Chrome\" to set active tab index of window $DDG_W to $DDG_T" >/dev/null 2>&1 || true
surf select "$EX" >/dev/null
FRONT_B=$(osascript -e 'tell application "Google Chrome" to get URL of active tab of front window')
printf '%s' '[{"op":"title"},{"op":"count","sel":"a"}]' | surf batch >/dev/null
surf wait-stable --timeout 5 >/dev/null 2>&1 || true
FRONT_A=$(osascript -e 'tell application "Google Chrome" to get URL of active tab of front window')
chk "batch+wait-stable keep focus (bg op)" "[ \"\$FRONT_B\" = \"\$FRONT_A\" ]"
chk "bg batch reads right title"   "[ \"\$(surf title)\" = 'Example Domain' ]"

section "M. session hygiene (your real tabs untouched)"
TABS_AFTER=$(surf tabs | wc -l | tr -d ' ')
# net change = +2 (our example + ddg tabs, minus any we closed). Should be +2 now.
DIFF=$((TABS_AFTER - TABS_BEFORE))
chk "only +2 tabs added (test tabs)" "[ $DIFF -eq 2 ]"

# ── cleanup: close our throwaway tabs (JSON URL-match, index-safe) ──
for p in example.com duckduckgo; do surf_close_url "$p"; done
TABS_FINAL=$(surf tabs | wc -l | tr -d ' ')
chk "test tabs cleaned up"     "[ $TABS_FINAL -eq $TABS_BEFORE ]"

printf "\n════════════════════════════════════\n"
printf "  PASS: %-3d   FAIL: %-3d   SKIP: %-3d\n" "$PASS" "$FAIL" "$SKIPPED"
printf "════════════════════════════════════\n"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
