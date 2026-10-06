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

banner "Shell scripts (bash -n + shellcheck -S error)"
# Bash launchers/CLIs: a parse error or shellcheck ERROR severity bug must never
# reach a commit (style warnings stay out of the gate on purpose). Skipped
# honestly when shellcheck is not installed.
# NOTE macOS bash 3.2: `case` is a syntax error inside < <( ) — if/glob only.
# Scope: *.sh files + suffix-less files that actually start with a bash shebang
# (git ls-files 'skills/*' would swallow every md/svg/ttf — filter by content).
if command -v shellcheck >/dev/null 2>&1; then
    sc_fail=0
    while IFS= read -r f; do
        [ -f "$f" ] || continue
        head -1 "$f" 2>/dev/null | grep -q '^#!.*bash' || continue
        bash -n "$f" || { echo "  ✗ $f: bash -n failed" >&2; sc_fail=1; continue; }
        shellcheck -S error "$f" || sc_fail=1
    done < <(git ls-files 'skills/'; git ls-files --others --exclude-standard 'skills/')
    [ "$sc_fail" -eq 0 ] && echo "ok" || { FAIL=1; echo "FAIL: shell scripts" >&2; }
else
    warn "shellcheck not installed — shell gate skipped"
fi

banner "Python scripts (ruff F,E9 — the vet tier)"
# Static bug checks for the skill Python code: pyflakes (F) + syntax (E9).
# Style rules stay OUT of the gate on purpose (same philosophy as shellcheck
# -S error). Skipped honestly when neither ruff nor uvx is available.
PY_FILES=$(git ls-files 'skills/*/scripts/*.py')
if [ -n "$PY_FILES" ]; then
    if command -v ruff >/dev/null 2>&1; then
        # shellcheck disable=SC2086
        ruff check --select F,E9 $PY_FILES || FAIL=1
    elif command -v uvx >/dev/null 2>&1; then
        # shellcheck disable=SC2086
        uvx ruff check --select F,E9 $PY_FILES || FAIL=1
    else
        warn "neither ruff nor uvx installed — python gate skipped"
    fi
else
    echo "  (no python files)"
fi

banner "Skill metadata (description hygiene)"
if bash tests/skill-metadata/test.sh; then echo "ok"; else FAIL=1; echo "FAIL: skill-metadata" >&2; fi

banner "Watchlist (watchlist.jsonl)"
if python3 - <<'PY'
import json, sys

REQUIRED = {"status", "type", "name", "source", "why", "added"}
STATUSES = {"watch", "review", "adopted", "rejected"}
TYPES = {"skill", "ext"}

lines = open("watchlist.jsonl", encoding="utf-8").read().splitlines()
errors = []
seen_sources = set()
for i, line in enumerate(l for l in lines if l.strip()):
    try:
        e = json.loads(line)
    except json.JSONDecodeError as err:
        errors.append(f"line {i + 1}: invalid JSON: {err}")
        continue
    missing = REQUIRED - e.keys()
    if missing:
        errors.append(f"line {i + 1} ({e.get('name', '?')}): missing {sorted(missing)}")
    if e.get("status") not in STATUSES:
        errors.append(f"line {i + 1}: status {e.get('status')!r} not in {sorted(STATUSES)}")
    if e.get("type") not in TYPES:
        errors.append(f"line {i + 1}: type {e.get('type')!r} not in {sorted(TYPES)}")
    if e.get("source") in seen_sources:
        errors.append(f"line {i + 1}: duplicate source {e['source']!r}")
    seen_sources.add(e.get("source"))

if errors:
    for e in errors:
        print(f"  ✗ {e}")
    sys.exit(1)
print(f"  {len([l for l in lines if l.strip()])} entries OK (required fields, status/type enums, no duplicate sources)")
PY
then echo "ok"; else FAIL=1; echo "FAIL: watchlist" >&2; fi

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
