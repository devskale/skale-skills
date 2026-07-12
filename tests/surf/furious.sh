#!/usr/bin/env bash
# Surf — furious live validation. Exercises every command, edge cases, the
# background-tab-no-focus guarantee, launcher flags, and pi skill discovery.
# All browser ops happen on throwaway test tabs; your real tabs are untouched.
set -u

PASS=0; FAIL=0; SKIPPED=0
mark() { if [ "$2" = "pass" ]; then PASS=$((PASS+1)); elif [ "$2" = "skip" ]; then SKIPPED=$((SKIPPED+1)); printf "  · %s\n" "$1"; else FAIL=$((FAIL+1)); printf "  ✗ %s\n" "$1"; fi; }
chk() { if eval "$2"; then mark "$1" pass; else mark "$1" FAIL; fi; }
section() { printf "\n── %s ──\n" "$1"; }

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
EX=$(surf tabs | grep -E 'w[0-9]+\.t[0-9]+ +https://example.com/' | grep -oE 'w[0-9]+\.t[0-9]+' | head -1)
DDG=$(surf tabs | grep -E 'w[0-9]+\.t[0-9]+ +https://html.duckduckgo' | grep -oE 'w[0-9]+\.t[0-9]+' | head -1)
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

section "M. session hygiene (your real tabs untouched)"
TABS_AFTER=$(surf tabs | wc -l | tr -d ' ')
# net change = +2 (our example + ddg tabs, minus any we closed). Should be +2 now.
DIFF=$((TABS_AFTER - TABS_BEFORE))
chk "only +2 tabs added (test tabs)" "[ $DIFF -eq 2 ]"

# ── cleanup: close our throwaway tabs (URL-matched, re-read each pass) ──
for round in 1 2 3 4; do
  for pat in 'https://example.com/' 'https://html.duckduckgo'; do
    REF=$(surf tabs | grep -E "w[0-9]+\.t[0-9]+ +${pat}" | grep -oE 'w[0-9]+\.t[0-9]+' | head -1)
    [ -n "$REF" ] && { surf select "$REF" >/dev/null; surf close >/dev/null 2>&1; }
  done
done
TABS_FINAL=$(surf tabs | wc -l | tr -d ' ')
chk "test tabs cleaned up"     "[ $TABS_FINAL -eq $TABS_BEFORE ]"

printf "\n════════════════════════════════════\n"
printf "  PASS: %-3d   FAIL: %-3d   SKIP: %-3d\n" "$PASS" "$FAIL" "$SKIPPED"
printf "════════════════════════════════════\n"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
