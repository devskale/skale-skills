#!/usr/bin/env bash
# visualize test suite
#   bash tests/visualize/test.sh
set -uo pipefail
cd "$(dirname "$0")/../.."

SKILL=skills/visualize
SCRIPT="$SKILL/visualize"
PASS=0; FAIL=0

ok()   { PASS=$((PASS+1)); }
bad()  { FAIL=$((FAIL+1)); echo "  FAIL: $1" >&2; }

check() { # check <desc> <expected-exit> <cmd...>
    local desc="$1" want="$2"; shift 2
    "$@" >/tmp/visualize.out 2>&1
    local got=$?
    if [ "$got" -eq "$want" ]; then ok; else bad "$desc (want exit $want, got $got)"; fi
}

echo "visualize tests"
echo "---------------"

# structure
[ -f "$SKILL/SKILL.md" ] && ok || bad "SKILL.md missing"
[ -f "$SKILL/install.sh" ] && ok || bad "install.sh missing"
[ -f "$SKILL/install.bat" ] && ok || bad "install.bat missing"
[ -x "$SCRIPT" ] && ok || bad "visualize not executable"
[ -f "$SKILL/references/structures.md" ] && ok || bad "structures.md missing"
[ -f "$SKILL/references/modules.md" ] && ok || bad "modules.md missing"
[ -f "$SKILL/references/report.md" ] && ok || bad "report.md missing"
[ -f "$SKILL/references/promptlib.md" ] && ok || bad "promptlib.md missing"
[ -f "$SKILL/references/html-patterns.md" ] && ok || bad "html-patterns.md missing"

# templates
for t in cards repo-tree system-map report mermaid; do
    [ -f "$SKILL/templates/$t.html" ] && ok || bad "template $t.html missing"
done
[ -f "$SKILL/templates/README.md" ] && ok || bad "templates/README.md missing"

# usage / errors
check "no args → exit 2" 2 "$SCRIPT"
check "unknown cmd → exit 2" 2 "$SCRIPT" bogus
check "open missing file → exit 2" 2 "$SCRIPT" open /nonexistent.html
check "share missing file → exit 2" 2 "$SCRIPT" share /nonexistent.html
check "--help → exit 0" 0 "$SCRIPT" --help

# build a self-contained file and validate it
TMP=$(mktemp -d)
cat > "$TMP/good.html" <<'EOF'
<!doctype html><html><head><meta charset="utf-8"><title>t</title>
<style>body{font-family:sans-serif}</style></head>
<body><h1>Good</h1><div class="card">hello</div></body></html>
EOF
cat > "$TMP/bad.html" <<'EOF'
<!doctype html><html><head><meta charset="utf-8"><title>t</title>
<script src="https://example.com/app.js"></script></head>
<body><h1>Bad</h1></body></html>
EOF
check "validate self-contained → exit 0" 0 "$SCRIPT" validate "$TMP/good.html"
check "validate external ref → exit 1" 1 "$SCRIPT" validate "$TMP/bad.html"

# open (macOS `open` present) — just check it accepts a real file
if command -v open >/dev/null 2>&1; then
    check "open real file → exit 0" 0 "$SCRIPT" open "$TMP/good.html"
else
    echo "  (skipping open test: no opener found)"
fi

# share — live upload to throway (network). Skip if offline / curl missing.
if command -v curl >/dev/null 2>&1; then
    if curl -sf --max-time 10 "https://lubu.skale.dev/throway/api" >/dev/null 2>&1; then
        out="$("$SCRIPT" share "$TMP/good.html" 2>/dev/null)"
        if printf '%s' "$out" | grep -q '^https://lubu.skale.dev/throway/'; then
            ok
        else
            bad "share did not return a throway URL (got: $out)"
        fi
        # share --dir — create a browseable throway dir from a folder
        mkdir -p "$TMP/dir"
        echo hi > "$TMP/dir/one.txt"
        echo there > "$TMP/dir/two.txt"
        out="$("$SCRIPT" share --dir "$TMP/dir" 2>/dev/null)"
        if printf '%s' "$out" | grep -q '^https://lubu.skale.dev/throway/'; then
            ok
        else
            bad "share --dir did not return a throway dir URL (got: $out)"
        fi
    else
        echo "  (skipping share test: throway unreachable)"
    fi
else
    echo "  (skipping share test: curl not installed)"
fi

rm -rf "$TMP"

echo "---------------"
echo "PASS: $PASS  FAIL: $FAIL"
[ "$FAIL" -eq 0 ]
