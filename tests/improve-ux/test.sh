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

echo "---------------"
echo "PASS: $PASS  FAIL: $FAIL  WARN: $WARN"
[ "$FAIL" -eq 0 ]
