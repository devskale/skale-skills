#!/usr/bin/env bash
# pdf2md test suite
#   bash tests/pdf2md/test.sh
# Live conversion needs a reachable API + token (credgoo FETCH_URL_BEARER);
# without them those checks WARN honestly. The llamaparse scan path uploads
# the document to LlamaCloud and costs credits — opt in: PDF2MD_TEST_SCAN=1.
set -uo pipefail
cd "$(dirname "$0")/../.."
ROOT=$(pwd)

SKILL=skills/pdf2md
SCRIPT="$SKILL/pdf2md"
PY="$SKILL/scripts/pdf2md.py"
PASS=0; FAIL=0; WARN=0

ok()   { PASS=$((PASS+1)); }
bad()  { FAIL=$((FAIL+1)); echo "  FAIL: $1" >&2; }
warn() { WARN=$((WARN+1)); echo "  WARN (network-dependent, skipped honestly): $1" >&2; }

check() { # check <desc> <expected-exit> <cmd...>
    local desc="$1" want="$2"; shift 2
    "$@" >/tmp/pdf2md.out 2>&1
    local got=$?
    if [ "$got" -eq "$want" ]; then ok; else bad "$desc (want exit $want, got $got)"; fi
}

echo "pdf2md tests"
echo "-------------"

# structure (house convention: SKILL.md, install.sh, install.bat, .gitignore, launcher)
[ -f "$SKILL/SKILL.md" ] && ok || bad "SKILL.md missing"
[ -f "$SKILL/install.sh" ] && ok || bad "install.sh missing"
[ -f "$SKILL/install.bat" ] && ok || bad "install.bat missing"
[ -f "$SKILL/.gitignore" ] && ok || bad ".gitignore missing"
[ -f "$SKILL/pyproject.toml" ] && ok || bad "pyproject.toml missing"
[ -f "$PY" ] && ok || bad "scripts/pdf2md.py missing"
[ -x "$SCRIPT" ] && ok || bad "launcher not executable"

# frontmatter: name + version, version aligned with pyproject
head -1 "$SKILL/SKILL.md" | grep -q '^---$' && ok || bad "SKILL.md missing frontmatter"
grep -q '^name: pdf2md' "$SKILL/SKILL.md" && ok || bad "frontmatter name: pdf2md"
grep -q '^description:' "$SKILL/SKILL.md" && ok || bad "frontmatter description missing"
FMV=$(grep -m1 '^version:' "$SKILL/SKILL.md" | grep -o '[0-9][0-9.]*')
PYV=$(grep -m1 '^version' "$SKILL/pyproject.toml" | grep -o '[0-9][0-9.]*')
[ -n "$FMV" ] && [ "$FMV" = "$PYV" ] && ok || bad "version mismatch SKILL.md($FMV) vs pyproject($PYV)"

# progressive disclosure: lean SKILL.md, details in linked references/
LINES=$(wc -l < "$SKILL/SKILL.md")
[ "$LINES" -le 100 ] && ok || bad "SKILL.md too long: $LINES lines (house rule: <100)"
[ -f "$SKILL/references/api.md" ] && ok || bad "references/api.md missing"
grep -q 'references/api.md' "$SKILL/SKILL.md" && ok || bad "SKILL.md does not link references/api.md"

# gitignore guards the venv (pi package updates run git clean -fdx)
grep -q '^\.venv/$' "$SKILL/.gitignore" && ok || bad ".gitignore misses .venv/"
grep -q '^\.last-update$' "$SKILL/.gitignore" && ok || bad ".gitignore misses .last-update"
git check-ignore -q "$SKILL/.last-update" && ok || bad ".last-update not ignored"

# usage / error exits (offline-safe: file check runs before token resolve)
check "no args → exit 2" 2 "$SCRIPT"
check "--help → exit 0" 0 "$SCRIPT" --help
check "missing file → exit 1" 1 "$SCRIPT" /nonexistent.pdf
check "unknown flag → exit 2" 2 "$SCRIPT" --bogus /nonexistent.pdf

# path handling: relative paths + ~ expansion resolve against the caller's cwd
( cd /tmp && "$ROOT/$SCRIPT" pdf2md-rel-missing.pdf >/tmp/pdf2md.out 2>&1 )
[ $? -eq 1 ] && ok || bad "missing relative file → exit 1"
"$SCRIPT" '~/pdf2md-nonexistent.pdf' >/tmp/pdf2md.out 2>&1
[ $? -eq 1 ] && grep -q "$HOME/pdf2md-nonexistent.pdf" /tmp/pdf2md.out && ok \
    || bad "~/ in arguments not expanded"

# launcher flags (convention: --update/--selfcheck)
check "--selfcheck → exit 0" 0 "$SCRIPT" --selfcheck
grep -q "pdf2md v" /tmp/pdf2md.out && ok || bad "selfcheck shows version"
grep -q "dir:" /tmp/pdf2md.out && ok || bad "selfcheck shows dir"
check "--update → exit 0" 0 "$SCRIPT" --update
grep -q "Updated" /tmp/pdf2md.out && ok || bad "--update reports Updated"
[ -f "$SKILL/.last-update" ] && ok || bad "stamp file created"

# token available? (env wins, then credgoo)
TOKEN=no
[ -n "${PDF2MD_BEARER:-}" ] || [ -n "${FETCH_URL_BEARER:-}" ] && TOKEN=env
if [ "$TOKEN" = no ] && command -v credgoo >/dev/null 2>&1; then
    [ -n "$(credgoo FETCH_URL_BEARER 2>/dev/null | head -1)" ] && TOKEN=credgoo
fi

# live smoke: text-layer PDF via pdfplumber (no cloud OCR cost)
FIXTXT=/tmp/pdf2md-fixture.txt
FIXPDF=/tmp/pdf2md-fixture.pdf
if [ "$TOKEN" = no ]; then
    warn "live conversion skipped (no token: PDF2MD_BEARER/FETCH_URL_BEARER/credgoo)"
else
    printf 'Skale pdf2md Funktionstest\nZeile zwei mit Umlauten: Aoeuess.\n' > "$FIXTXT"
    cupsfilter "$FIXTXT" > "$FIXPDF" 2>/dev/null
    if [ ! -s "$FIXPDF" ]; then
        warn "live conversion skipped (cannot build PDF fixture via cupsfilter)"
    else
        check "live convert → exit 0" 0 "$SCRIPT" "$FIXPDF" --out /tmp/pdf2md-out.md
        if [ -s /tmp/pdf2md-out.md ]; then
            ok
            grep -q "Funktionstest" /tmp/pdf2md-out.md && ok || bad "markdown lacks fixture text"
        else
            bad "live conversion produced empty output"
        fi
        check "live convert --method pdfplumber → exit 0" 0 \
            "$SCRIPT" "$FIXPDF" --method pdfplumber --out /tmp/pdf2md-out2.md

        # relative in+out resolve against the caller's cwd, not the skill dir
        TESTCWD=$(mktemp -d)
        cp "$FIXPDF" "$TESTCWD/rel.pdf"
        ( cd "$TESTCWD" && "$ROOT/$SCRIPT" rel.pdf --out rel-out.md ) >/tmp/pdf2md.out 2>&1
        [ -s "$TESTCWD/rel-out.md" ] && ok || bad "relative paths don't resolve against caller cwd"
        rm -rf "$TESTCWD"

        # robustness: network timeout → clean error, never a traceback
        # (blackhole address + tiny timeout; PDF2MD_URL is a supported override)
        PDF2MD_URL="http://10.255.255.1:9/" timeout 30 \
            "$SCRIPT" "$FIXPDF" --timeout 2 >/tmp/pdf2md.out 2>&1
        got=$?
        [ "$got" -eq 1 ] && ok || bad "blackhole timeout exit (want 1, got $got)"
        grep -q "Traceback" /tmp/pdf2md.out && bad "timeout leaked a traceback" || ok
        grep -q "retry with a higher --timeout" /tmp/pdf2md.out && ok \
            || bad "timeout message lacks retry hint"
    fi
fi

# scan path (llamaparse) — uploads to LlamaCloud + costs credits; opt-in only
if [ "${PDF2MD_TEST_SCAN:-0}" = "1" ]; then
    if [ "$TOKEN" != no ] && [ -s "$FIXPDF" ]; then
        check "live llamaparse → exit 0" 0 "$SCRIPT" "$FIXPDF" --method llamaparse -v
    else
        warn "scan test skipped (no token or fixture)"
    fi
else
    warn "llamaparse scan path not exercised (opt in: PDF2MD_TEST_SCAN=1)"
fi

echo
echo "PASS=$PASS FAIL=$FAIL WARN=$WARN"
[ "$FAIL" -eq 0 ]
