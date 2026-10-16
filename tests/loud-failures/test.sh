#!/usr/bin/env bash
# Loud-failure audit — HARD RULE (AGENTS.md): failures must be loud, never
# silenced. No hiding errors in skill launchers or scripts.
#
# Scans every auto-update launcher for the silenced-update anti-pattern:
#   - git pull / uv sync with stderr discarded (2>/dev/null) or || true
#   - &>/dev/null on pull/sync/stamp lines (both streams gone)
#   - stamp written although the pull isn't guarded (breakage hidden for the
#     whole AUTO_UPDATE_DAYS window)
# Plus: bare `except Exception: pass` in skill python scripts, unless the line
# carries an explicit `# loud-ok` opt-out marker.

set -u
cd "$(dirname "$0")/../.." || exit 1

PASS=0
FAIL=0
WARN=0

ok()   { PASS=$((PASS+1)); echo "  ✓ $1"; }
bad()  { FAIL=$((FAIL+1)); echo "  ✗ $1"; }
warn() { WARN=$((WARN+1)); echo "  ⚠ $1"; }

echo "[1] Auto-update launchers: pull/sync failures must be loud..."
for f in $(grep -rl "git pull" skills/ 2>/dev/null | grep -vE "\.md$|install\.|/tests?/|\.sh$"); do
    name=$f
    # silenced pull: stderr discarded or error swallowed
    if grep -nE "git pull.*2>/dev/null" "$f" >/dev/null 2>&1; then
        bad "$name: git pull silences stderr (2>/dev/null) — failures invisible"
        continue
    fi
    if grep -nE "git pull.*\|\| true" "$f" >/dev/null 2>&1; then
        bad "$name: git pull failure swallowed (|| true)"
        continue
    fi
    # both streams discarded on update lines
    if grep -nE "(pull|sync|STAMP_FILE).*&>/dev/null|&>/dev/null.*&( >/dev/null)?$" "$f" >/dev/null 2>&1; then
        bad "$name: &>/dev/null discards update errors"
        continue
    fi
    # pull not guarded → stamp would be written on failure
    if grep -q "git pull" "$f" && ! grep -qE "if ! git pull|! *\(.*git pull|&& ! .*git pull" "$f"; then
        bad "$name: git pull not guarded with 'if !' — stamp may be written on failure"
        continue
    fi
    ok "$name: update failures loud"
done

echo ""
echo "[2] Stamp-after-pull sanity: guarded pull implies retry on failure..."
for f in $(grep -rl 'date +%s > "$STAMP_FILE"' skills/ 2>/dev/null | grep -vE "\.md$|install\.|/tests?/"); do
    if grep -q "git pull" "$f" && ! grep -qE '\$ok && date|exit 1' "$f"; then
        bad "$name: stamp write not gated by ok/exit — failure not retried"
    else
        ok "$name: stamp gated"
    fi
done

echo ""
echo "[3] Python: silent 'except ...: pass' needs an explicit '# loud-ok' marker..."
while IFS= read -r file; do
    while IFS=: read -r lineno; do
        [ -n "$lineno" ] || continue
        next=$((lineno + 1))
        body=$(sed -n "${next}p" "$file" | sed 's/^[[:space:]]*//')
        if [[ "$body" == "pass" || "$body" == "pass "* || "$body" == "pass#"* ]]; then
            if [[ "$body" == *"loud-ok"* ]]; then
                ok "$file:$lineno — silent except explicitly marked loud-ok"
            else
                bad "$file:$lineno — except swallows silently (add handling or '# loud-ok')"
            fi
        fi
    done < <(grep -nE "^\s*except[^:]*:\s*$" "$file" | cut -d: -f1)
done < <(git ls-files 'skills/*.py' 'skills/*/*.py' 'skills/*/*/*.py' 'skills/*/*/*/*.py')

echo ""
echo "=== Results ==="
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
echo "  Warned/skipped: $WARN"
if [ $FAIL -gt 0 ]; then
    echo ""
    echo "❌ Some checks failed."
    exit 1
fi
echo "✅ All loud-failure checks passed."
