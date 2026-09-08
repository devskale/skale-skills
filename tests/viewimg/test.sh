#!/usr/bin/env bash
# viewimg test suite
#   bash tests/viewimg/test.sh
set -uo pipefail
cd "$(dirname "$0")/../.."

SKILL=skills/viewimg
SCRIPT="$SKILL/viewimg"
# Generate the fixture on the fly — a committed generated/*.jpg went stale and
# broke the suite on fresh clones.
IMG="/tmp/viewimg-fixture.png"
python3 -c '
import struct, sys, zlib
def chunk(t, d):
    return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
w = h = 8
raw = b"".join(b"\x00" + b"\xe0\x4a\x3c" * w for _ in range(h))
open(sys.argv[1], "wb").write(
    b"\x89PNG\r\n\x1a\n"
    + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
    + chunk(b"IDAT", zlib.compress(raw))
    + chunk(b"IEND", b""))
' 2>/dev/null || printf 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==' | base64 -d > "$IMG"
[ -f "$IMG" ] || { echo "cannot create test fixture" >&2; exit 1; }
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

# launcher flags (convention: --update/--selfcheck)
check "--selfcheck → exit 0" 0 "$SCRIPT" --selfcheck
grep -q "viewimg v" /tmp/viewimg.out && ok || bad "selfcheck shows version"
grep -q "dir:" /tmp/viewimg.out && ok || bad "selfcheck shows dir"
grep -q "chafa:" /tmp/viewimg.out && ok || bad "selfcheck shows chafa"
check "--update → exit 0" 0 "$SCRIPT" --update
grep -q "Updated" /tmp/viewimg.out && ok || bad "--update reports Updated"
[ -f "$SKILL/.last-update" ] && ok || bad "stamp file created"

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
