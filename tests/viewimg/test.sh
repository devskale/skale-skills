#!/usr/bin/env bash
# viewimg test suite
#   bash tests/viewimg/test.sh
set -uo pipefail
cd "$(dirname "$0")/../.."

SKILL=skills/viewimg
SCRIPT="$SKILL/viewimg"
IMG="generated/generated-1785185007488.jpg"
PASS=0; FAIL=0

ok()   { PASS=$((PASS+1)); }
bad()  { FAIL=$((FAIL+1)); echo "  FAIL: $1" >&2; }

check() { # check <desc> <expected-exit> <cmd...>
    local desc="$1" want="$2"; shift 2
    "$@" >/tmp/viewimg.out 2>&1
    local got=$?
    if [ "$got" -eq "$want" ]; then ok; else bad "$desc (want exit $want, got $got)"; fi
}

echo "viewimg tests"
echo "-------------"

# structure
[ -f "$SKILL/SKILL.md" ] && ok || bad "SKILL.md missing"
[ -f "$SKILL/install.sh" ] && ok || bad "install.sh missing"
[ -f "$SKILL/install.bat" ] && ok || bad "install.bat missing"
[ -x "$SCRIPT" ] && ok || bad "viewimg not executable"

# usage / errors
check "no args → exit 2" 2 "$SCRIPT"
check "missing file → exit 2" 2 "$SCRIPT" /nonexistent.jpg
check "unknown flag → exit 2" 2 "$SCRIPT" --bogus
check "--help → exit 0" 0 "$SCRIPT" --help

# render (chafa present)
if command -v chafa >/dev/null 2>&1; then
    check "render image → exit 0" 0 "$SCRIPT" "$IMG" --size 20x10
    check "render --no-color → exit 0" 0 "$SCRIPT" "$IMG" --size 20x10 --no-color
    check "render multiple → exit 0" 0 "$SCRIPT" "$IMG" "$IMG" --size 20x10
else
    echo "  (skipping render tests: chafa not installed)"
fi

# multiple files in one window (open present on macOS)
if command -v open >/dev/null 2>&1; then
    check "--open multiple → exit 0" 0 "$SCRIPT" "$IMG" "$IMG" --open
else
    echo "  (skipping --open test: open not available)"
fi

echo "-------------"
echo "PASS: $PASS  FAIL: $FAIL"
[ "$FAIL" -eq 0 ]
