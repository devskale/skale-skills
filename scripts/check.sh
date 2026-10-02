#!/usr/bin/env bash
# scripts/check.sh — the one gate. Run before every commit; wired as the pre-commit hook.
#   bash scripts/check.sh          # lint + typecheck + docs integrity
#   bash scripts/check.sh --full   # additionally every per-skill suite (slow; also what pre-push runs)
#
# Design note: per-skill suites stay in their own tests/<name>/test.sh — this script is the
# composition, not a reimplementation. Suites print their own PASS/FAIL counters and exit
# non-zero on failure, so failures propagate.
set -uo pipefail
cd "$(dirname "$0")/.."

FAIL=0
warn() { echo "  WARN (skipped honestly): $1"; }

banner() { printf '\n── %s ──\n' "$1"; }

banner "Biome lint + typecheck"
if bash scripts/lint.sh; then echo "ok"; else FAIL=1; echo "FAIL: lint/typecheck" >&2; fi

banner "Skill metadata (description hygiene)"
if bash tests/skill-metadata/test.sh; then echo "ok"; else FAIL=1; echo "FAIL: skill-metadata" >&2; fi

banner "Docs integrity (dead links, orphans)"
if bash tests/docs/test.sh; then echo "ok"; else FAIL=1; echo "FAIL: docs" >&2; fi

if [ "${1:-}" = "--full" ]; then
    banner "Per-skill suites"
    # Live-browser suites drive the user's real desktop Chrome — not a machine-independent
    # gate. Include with LIVE_OK=1 when you actually want them (Chrome open, visible desktop).
    # Known issue: rodney's suite crashes (exit 2, no results) when `rodney title` fails in
    # its live section — `TITLE=$(rodney title)` under set -e. Found 2026-10-01, unfixed.
    LIVE_SUITES=" rodney surf "
    for t in tests/*/test.sh; do
        name=$(basename "$(dirname "$t")")
        [ "$name" = "deprecated" ] && continue
        if [ "${LIVE_OK:-0}" != "1" ] && [[ "$LIVE_SUITES" == *" $name "* ]]; then
            warn "$name skipped (live browser; LIVE_OK=1 to include)"
            continue
        fi
        # Suites skip network-dependent checks honestly (WARN); a WARN is not a failure.
        if bash "$t" >/tmp/check-$name.log 2>&1; then
            echo "ok: $name ($(grep -hoE 'PASS:? *[0-9]+' /tmp/check-$name.log | tail -1))"
        else
            FAIL=1
            echo "FAIL: $name" >&2
            tail -15 "/tmp/check-$name.log" | sed 's/^/    /' >&2
        fi
    done
fi

printf '\n'
if [ "$FAIL" -ne 0 ]; then
    echo "RESULT: FAIL — fix the above before committing" >&2
    exit 1
fi
echo "RESULT: PASS"
