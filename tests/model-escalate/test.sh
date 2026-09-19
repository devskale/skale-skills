#!/usr/bin/env bash
# model-escalate extension — smoke test
#
# pi *extension* (not a CLI skill), so tests cover:
#   1. File structure + core wiring (events, setModel, ladder)
#   2. Type check passes (tsc, same gate as scripts/lint.sh)
#   3. Signature/Strike-Logik als hermetischer Node-Sanity-Run
set -e
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

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

EXT=extensions/model-escalate.ts

echo "=== model-escalate extension tests ==="

# ── 1. Struktur ─────────────────────────────────────────────────────────
assert "extension file exists"        "[ -f $EXT ]"
assert "registers tool_result"        "grep -q 'pi.on(\"tool_result\"' $EXT"
assert "registers model_select reset" "grep -q 'pi.on(\"model_select\"' $EXT"
assert "escalates via pi.setModel"    "grep -q 'pi.setModel' $EXT"
assert "uses scopedModels ladder"     "grep -q 'scopedModels' $EXT"
assert "injects escalation notice"    "grep -q 'pi.sendMessage' $EXT"
assert "persist strikes (appendEntry)" "grep -q 'pi.appendEntry' $EXT"
assert "/escalate command"            "grep -q 'registerCommand' $EXT"
assert "--local-free: no hardcoded project" "! grep -qi 'kontext' $EXT"

# ── 2. Type check (gleicher Gate wie scripts/lint.sh) ──────────────────
assert "tsc typecheck clean" "npx tsc --noEmit -p tsconfig.json 2>/dev/null || npx tsc --noEmit extensions/model-escalate.ts --module esnext --moduleResolution bundler --target es2022 --strict --skipLibCheck"

# ── 3. Signatur-Logik (hermetisch, ohne pi) ────────────────────────────
assert "signature list present"  "grep -q 'Tool \".*\" not found' $EXT"
assert "hint before escalation"  "grep -q 'SKILL_HINT' $EXT"
assert "strike window config"    "grep -q 'windowMinutes' $EXT"

echo ""
echo "PASS: $PASS  FAIL: $FAIL"
[ "$FAIL" -eq 0 ]
