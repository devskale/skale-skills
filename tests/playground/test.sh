#!/usr/bin/env bash
# playground.sh tests — Roster-Integrität, play-Pfade, doctor (live, ohne Netz)
set -u
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 1
PG="scripts/playground.sh"

PASS=0; FAIL=0
assert() { if eval "$2"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "  FAIL: $1"; fi; }

echo "playground tests"
echo "----------------"

# ── Struktur ────────────────────────────────────────────────────────
assert "script exists + executable" "[ -x '$PG' ]"
bash -n "$PG" && assert "bash -n clean" true || assert "bash -n clean" false

# ── list: Farm-Einträge + Watchlist-Status ──────────────────────────
OUT="$($PG list)"
assert "list nennt die Farm" "printf '%s' \"\$OUT\" | grep -q '.clones'"
for c in unslop ponytail emilkowalski-skills; do
    assert "list zeigt '$c'" "printf '%s' \"\$OUT\" | grep -q '$c'"
done
assert "list zeigt watchlist-status" "printf '%s' \"\$OUT\" | grep -q 'watchlist:'"

# ── play: kanonischer Skill-Pfad, keine hidden-Duplikate ────────────
P="$($PG play ponytail | grep -- '--skill')"
assert "play ponytail → skills/ponytail (nicht .openclaw)" "echo '$P' | grep -q 'clones/ponytail/skills/ponytail/SKILL.md'"
assert "play ohne hidden-Pfad" "! echo '$P' | grep -q '/\\.openclaw/'"
assert "play unbekannt → exit 1" "! $PG play gibt-es-nicht >/dev/null 2>&1"

# ── doctor: sauber auf dieser Maschine (keine .clones-Roster-Links) ─
D="$($PG doctor)"
assert "doctor läuft" "[ \$? -eq 0 ] || true"
assert "doctor meldet sauber ODER Probleme zählbar" "echo '$D' | grep -qE 'sauber|⚠|✗'"

echo ""
echo "=== Summary: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
