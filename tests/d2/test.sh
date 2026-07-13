#!/usr/bin/env bash
set -e

# D2 Skill Test Suite
# Validates the knowledge skill: structure, frontmatter, content, and a live
# end-to-end (sample .d2 validates + renders to SVG and ASCII). Live parts need
# the `d2` binary on PATH (`brew install d2`); they skip gracefully if absent.

cd "$(dirname "${BASH_SOURCE[0]}")/../../skills/d2"

PASS=0
FAIL=0

assert() {
    if eval "$2"; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
        echo "  FAIL: $1"
    fi
}

echo "=== Testing d2 ==="
echo ""

# ── 1. File structure ─────────────────────────────────────────────────
echo "[1] File structure..."
assert "SKILL.md"             "[ -f SKILL.md ]"
assert "references/syntax.md" "[ -f references/syntax.md ]"
assert "WORKLOG.md"           "[ -f WORKLOG.md ]"
echo ""

# ── 2. SKILL.md frontmatter ───────────────────────────────────────────
echo "[2] SKILL.md frontmatter..."
assert "name: d2"        "grep -q '^name: d2' SKILL.md"
assert "description"     "grep -q '^description:' SKILL.md"
assert "license"         "grep -q '^license:' SKILL.md"
assert "version"         "grep -q 'version:' SKILL.md"
echo ""

# ── 3. SKILL.md references linked ─────────────────────────────────────
echo "[3] SKILL.md references..."
assert "syntax.md linked"  "grep -q 'references/syntax.md' SKILL.md"
echo ""

# ── 4. SKILL.md content quality ───────────────────────────────────────
echo "[4] SKILL.md content..."
assert "mentions the d2 binary"   "grep -qi 'd2 ' SKILL.md"
assert "mandates elk layout"      "grep -qi 'layout-engine: elk' SKILL.md"
assert "covers validate"          "grep -qi 'd2 validate' SKILL.md"
assert "covers ASCII self-verify" "grep -qi 'ASCII\|\.txt' SKILL.md"
assert "has a Gotchas section"    "grep -q '## Gotchas' SKILL.md"
echo ""

# ── 5. d2 binary available? ───────────────────────────────────────────
echo "[5] d2 binary..."
if command -v d2 &>/dev/null; then
    assert "d2 on PATH" "command -v d2"
    VER=$(d2 --version 2>&1 || true)
    assert "has version" "[ -n '$VER' ]"
    echo "  version: $VER"
else
    echo "  SKIP: d2 not on PATH (brew install d2) — skipping live tests"
    echo ""
    echo "==============================="
    echo "  PASS: $PASS   FAIL: $FAIL   (live: skipped)"
    echo "==============================="
    [ "$FAIL" -eq 0 ] && exit 0 || exit 1
fi
echo ""

# ── 6. Live: sample .d2 validates + renders ───────────────────────────
echo "[6] Live end-to-end (sample diagram)..."
TMP="$(mktemp -d)"
cat > "$TMP/arch.d2" <<'D2EOF'
vars: {
  d2-config: {
    layout-engine: elk
  }
}
user: { shape: person }
api: API Server
db: { shape: cylinder; style.multiple: true }
queue: { shape: queue }
user -> api: request
api -> db: query
api -> queue: enqueue
D2EOF

# validate (syntax check) — exit 0
if d2 validate "$TMP/arch.d2" >/dev/null 2>&1; then
    assert "d2 validate exits 0" "true"
else
    assert "d2 validate exits 0" "false"
fi

# render SVG (default, self-contained) — file exists & non-empty
d2 "$TMP/arch.d2" "$TMP/arch.svg" >/dev/null 2>&1
assert "renders SVG"        "[ -s \"$TMP/arch.svg\" ]"
assert "SVG is well-formed" "head -1 \"$TMP/arch.svg\" | grep -q '<svg' || head -1 \"$TMP/arch.svg\" | grep -q '<?xml'"

# render ASCII (needs ELK — set in vars) — non-empty self-verifiable output
d2 "$TMP/arch.d2" "$TMP/arch.txt" >/dev/null 2>&1
assert "renders ASCII (.txt)" "[ -s \"$TMP/arch.txt\" ]"
if [ -s "$TMP/arch.txt" ]; then
    ASCII_LINES=$(wc -l < "$TMP/arch.txt" | tr -d ' ')
    assert "ASCII render is multi-line"   "[ \"$ASCII_LINES\" -gt 3 ]"
    assert "ASCII contains a node label"   "grep -qi 'api\|user\|db' \"$TMP/arch.txt\""
fi

# fmt: format in place, then --check must be idempotent (exit 0)
d2 fmt "$TMP/arch.d2" >/dev/null 2>&1 && assert "d2 fmt formats in place" "true" || assert "d2 fmt formats in place" "false"
d2 fmt --check "$TMP/arch.d2" >/dev/null 2>&1 && assert "d2 fmt --check idempotent" "true" || assert "d2 fmt --check idempotent" "false"

rm -rf "$TMP"
echo ""

# ── 7. Recipes cookbook ─────────────────────────────────────────────
echo "[7] Recipes cookbook..."
assert "references/recipes.md"  "[ -f references/recipes.md ]"
for r in layered request-flow microservices pubsub c4-container deployment; do
    assert "recipe $r validates" "d2 validate references/recipes/$r.d2 >/dev/null 2>&1"
done
echo ""

# ── 8. Diagram types (sequence / ER / class) ──────────────────────
echo "[8] Diagram types..."
for t in sequence er.diagram class; do
    assert "type $t validates" "d2 validate references/types/$t.d2 >/dev/null 2>&1"
done
echo ""

# ── 9. Delivery polish examples ───────────────────────────────────
echo "[9] Delivery polish..."
assert "interactive.d2 validates" "d2 validate references/delivery/interactive.d2 >/dev/null 2>&1"
assert "layers.d2 validates"     "d2 validate references/delivery/layers.d2 >/dev/null 2>&1"
echo ""

echo "==============================="
echo "  PASS: $PASS   FAIL: $FAIL"
echo "==============================="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
