#!/usr/bin/env bash
# improve-ux test suite
#   bash tests/improve-ux/test.sh
set -uo pipefail
cd "$(dirname "$0")/../.."

SKILL=skills/improve-ux
SCRIPT="$SKILL/improve-ux"
PASS=0; FAIL=0; WARN=0

ok()   { PASS=$((PASS+1)); }
bad()  { FAIL=$((FAIL+1)); echo "  FAIL: $1" >&2; }
warn() { WARN=$((WARN+1)); echo "  WARN: $1" >&2; }

check() { # check <desc> <expected-exit> <cmd...>
    local desc="$1" want="$2"; shift 2
    "$@" >/tmp/improve-ux.out 2>&1
    local got=$?
    if [ "$got" -eq "$want" ]; then ok; else bad "$desc (want exit $want, got $got)"; fi
}

echo "improve-ux tests"
echo "---------------"

# structure
[ -f "$SKILL/SKILL.md" ] && ok || bad "SKILL.md missing"
[ -x "$SCRIPT" ] && ok || bad "improve-ux launcher not executable"
grep -q 'GIT_ROOT=' "$SCRIPT" && ok || bad "launcher must resolve enclosing git root (GIT_ROOT)"
grep -q 'GIT_ROOT/.git' "$SCRIPT" && ok || bad "auto-update guard must use GIT_ROOT/.git"
[ -f "$SKILL/install.sh" ] && ok || bad "install.sh missing"
[ -f "$SKILL/install.bat" ] && ok || bad "install.bat missing"
[ -f "$SKILL/.gitignore" ] && ok || bad ".gitignore missing"
for f in references/SITES.md references/verify.md references/ledger.md \
         references/deep-review.md references/discovery-queries.txt \
         references/sota/a11y.md references/sota/motion.md \
         references/sota/tokens.md references/sota/states.md \
         references/sota/tooling.md; do
    [ -f "$SKILL/$f" ] && ok || bad "$f missing"
done
[ ! -f "$SKILL/references/SOTA.md" ] && ok || bad "old monolithic SOTA.md still present — should be sota/"

# frontmatter
head -6 "$SKILL/SKILL.md" | grep -q '^name: improve-ux' && ok || bad "frontmatter name"
head -6 "$SKILL/SKILL.md" | grep -q '^version:' && ok || bad "frontmatter version"
[ "$(wc -l < "$SKILL/SKILL.md" | tr -d ' ')" -le 99 ] && ok || bad "SKILL.md over 99 lines"

# body size (convention: under 100 lines)
lines=$(wc -l < "$SKILL/SKILL.md" | tr -d ' ')
[ "$lines" -le 100 ] && ok || bad "SKILL.md is $lines lines (convention: <100)"

# progressive disclosure: every reference file linked from SKILL.md (no orphans)
while IFS= read -r f; do
    grep -qF "$f" "$SKILL/SKILL.md" && ok || bad "unlinked reference: $f"
done < <(cd "$SKILL" && find references -type f | sort)

# every relative link in SKILL.md resolves
for p in $(grep -oE '\]\((references/[^)#]+)\)' "$SKILL/SKILL.md" | sed 's/](//; s/)$//' | sort -u); do
    [ -f "$SKILL/$p" ] && ok || bad "broken link in SKILL.md: $p"
done

# usage / errors
check "no args → exit 2" 2 "$SCRIPT"
check "unknown cmd → exit 2" 2 "$SCRIPT" bogus
check "--help → exit 0" 0 "$SCRIPT" --help
check "--selfcheck → exit 0" 0 "$SCRIPT" --selfcheck
grep -q "improve-ux v" /tmp/improve-ux.out && ok || bad "selfcheck shows version"
grep -q "web-search:" /tmp/improve-ux.out && ok || bad "selfcheck shows web-search dep"
grep -qi "syntax error" /tmp/improve-ux.out && bad "selfcheck emits bash syntax errors" || ok
check "--update → exit 0" 0 "$SCRIPT" --update
grep -q "Updated" /tmp/improve-ux.out && ok || bad "--update reports Updated"
[ -f "$SKILL/.last-update" ] && ok || bad "stamp file created"

# add — offline behavior via temp copy + --force
TMP=$(mktemp -d)
cp "$SKILL/references/SITES.md" "$TMP/s.md"
check "add without args → exit 2" 2 "$SCRIPT" add
check "add bad url → exit 2" 2 "$SCRIPT" add "notaurl" "focus" --file "$TMP/s.md" --force
check "add unreachable (no --force) → exit 1" 1 "$SCRIPT" add "http://127.0.0.1:1/x" "focus" --file "$TMP/s.md"
check "add to temp file → exit 0" 0 "$SCRIPT" add "https://newsite.example.org/" "test focus" --group "Craft, motion & taste" --file "$TMP/s.md" --force
grep -q 'newsite.example.org' "$TMP/s.md" && ok || bad "added row not found in temp SITES.md"
# row must come AFTER the group's table separator, not before it
awk '/^## Craft, motion & taste/{sec=1} sec && /newsite\.example\.org/{print NR; exit}' "$TMP/s.md" | grep -q . && ok || bad "row not inside group section"
sep_line=$(grep -n '^|------|-------|$' "$TMP/s.md" | head -2 | tail -1 | cut -d: -f1)
row_line=$(grep -n 'newsite.example.org' "$TMP/s.md" | cut -d: -f1)
[ "${row_line:-0}" -gt "${sep_line:-0}" ] && ok || bad "row inserted before table separator"
check "add duplicate domain → exit 1" 1 "$SCRIPT" add "https://newsite.example.org/other" "dup" --file "$TMP/s.md" --force
check "add new group creates heading → exit 0" 0 "$SCRIPT" add "https://other.example.net/" "another" --group "Brand new group" --file "$TMP/s.md" --force
grep -q '^## Brand new group$' "$TMP/s.md" && ok || bad "new group heading missing"
grep -q 'other.example.net' "$TMP/s.md" && ok || bad "row missing in new group"

# discovery queries file is usable
[ -s "$SKILL/references/discovery-queries.txt" ] && ok || bad "discovery-queries.txt empty"
grep -cvE '^[[:space:]]*(#|$)' "$SKILL/references/discovery-queries.txt" | grep -q '[1-9]' && ok || bad "no queries in discovery-queries.txt"

# live: discover (needs web-search + python3 + network) — honest skip otherwise
if command -v web-search >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
    if curl -sf --max-time 10 -o /dev/null -I "https://cdn.jsdelivr.net/npm/axe-core@4/axe.min.js"; then
        check "discover live → exit 0" 0 "$SCRIPT" discover -n 3
        grep -q "Discovered" /tmp/improve-ux.out && ok || bad "discover prints candidate table"
        check "discover unknown flag → exit 2" 2 "$SCRIPT" discover --bogus
    else
        warn "network unreachable — skipped live discover (structure checks still ran)"
    fi
else
    warn "web-search/python3 missing — skipped live discover"
fi

rm -rf "$TMP"

# rate command (isolated cache — never touches the real ratings.json)
TMPR=$(mktemp -d)
check "rate: no args → exit 2" 2 env XDG_CACHE_HOME="$TMPR" "$SCRIPT" rate
check "rate: records use+helped" 0 env XDG_CACHE_HOME="$TMPR" "$SCRIPT" rate ui.shadcn.com --helped --note "shadcn stacks"
RATINGS="$TMPR/skale-skills/improve-ux/ratings.json"
[ -f "$RATINGS" ] && ok || bad "rate: ratings.json created"
grep -q '"uses": 1' "$RATINGS" && ok || bad "rate: uses=1"
grep -q '"helped": 1' "$RATINGS" && ok || bad "rate: helped=1 (kept)"
grep -q '"note": "shadcn stacks"' "$RATINGS" && ok || bad "rate: note stored"
check "rate: second use without --helped" 0 env XDG_CACHE_HOME="$TMPR" "$SCRIPT" rate ui.shadcn.com
grep -q '"uses": 2' "$RATINGS" && ok || bad "rate: uses=2 after second call"
grep -q '"helped": 1' "$RATINGS" && ok || bad "rate: helped stays 1 without --helped"
check "rate: URL input normalized to domain" 0 env XDG_CACHE_HOME="$TMPR" "$SCRIPT" rate "https://emilkowal.ski/sect" --helped
grep -q '"emilkowal.ski"' "$RATINGS" && ok || bad "rate: domain normalization"
check "rate: --top lists rated sites" 0 env XDG_CACHE_HOME="$TMPR" "$SCRIPT" rate --top
grep -q "ui.shadcn.com" /tmp/improve-ux.out && ok || bad "rate: --top prints site"
check "rate: unknown flag → exit 2" 2 env XDG_CACHE_HOME="$TMPR" "$SCRIPT" rate example.com --bogus
rm -rf "$TMPR"

# ledger command (isolated cache)
TMPL=$(mktemp -d)
LED="env XDG_CACHE_HOME=$TMPL $SCRIPT ledger"
check "ledger: unknown sub → exit 2" 2 env XDG_CACHE_HOME="$TMPL" "$SCRIPT" ledger bogus
check "ledger: init" 0 env XDG_CACHE_HOME="$TMPL" "$SCRIPT" ledger init "Demo target" --stack "React + Tailwind"
LEDGER="$TMPL/skale-skills/improve-ux/targets/demo-target.json"
[ -f "$LEDGER" ] && ok || bad "ledger: slugified file created"
check "ledger: init twice → exit 1" 1 env XDG_CACHE_HOME="$TMPL" "$SCRIPT" ledger init "Demo target"
check "ledger: add finding" 0 env XDG_CACHE_HOME="$TMPL" "$SCRIPT" ledger add "submit button 32×20px" --severity blocker --citation "WCAG 2.5.5" --fix "padded to 44×44" --status fixed
grep -q '"id": "F1"' "$LEDGER" && ok || bad "ledger: F1 assigned"
grep -q '"severity": "blocker"' "$LEDGER" && ok || bad "ledger: severity stored"
grep -q '"status": "fixed"' "$LEDGER" && ok || bad "ledger: status stored"
check "ledger: add second finding" 0 env XDG_CACHE_HOME="$TMPL" "$SCRIPT" ledger add "drawer 400ms linear" --topic motion
grep -q '"id": "F2"' "$LEDGER" && ok || bad "ledger: F2 monotonic"
grep -q '"status": "open"' "$LEDGER" && ok || bad "ledger: default status open"
check "ledger: bad severity → exit 2" 2 env XDG_CACHE_HOME="$TMPL" "$SCRIPT" ledger add "x" --severity huge
check "ledger: show prints findings" 0 env XDG_CACHE_HOME="$TMPL" "$SCRIPT" ledger show "Demo target"
grep -q "F1" /tmp/improve-ux.out && grep -q "open item" /tmp/improve-ux.out && ok || bad "ledger: show lists findings + open count"
check "ledger: show missing target → exit 1" 1 env XDG_CACHE_HOME="$TMPL" "$SCRIPT" ledger show "does-not-exist"
# cap warning: push the current pass over the ~7-changes cap (F2..F10 → 10 findings)
for i in 3 4 5 6 7 8 9 10; do
    env XDG_CACHE_HOME="$TMPL" "$SCRIPT" ledger add "filler finding $i" >/dev/null 2>&1
done
grep -q "~7 kept-changes cap" "$LEDGER" 2>/dev/null && bad "ledger: cap text must not be written into JSON" || ok
env XDG_CACHE_HOME="$TMPL" "$SCRIPT" ledger show "Demo target" >/tmp/improve-ux-cap.out 2>&1
grep -q "~7 kept-changes cap" /tmp/improve-ux-cap.out && ok || bad "ledger: cap warning printed on show"
rm -rf "$TMPL"

echo "---------------"
echo "PASS: $PASS  FAIL: $FAIL  WARN: $WARN"
[ "$FAIL" -eq 0 ]
