#!/usr/bin/env bash
# scripts/extension-drift.sh — is the RUNNING agent's package clone in sync with this checkout?
#
# pi loads extensions from the package copy (~/.pi/agent/git/github.com/devskale/skale-skills),
# NOT from this working checkout (see docs/development.md). After editing extensions/ here, the
# running agent keeps the old code until the clone is updated — by push + `pi install`, or by a
# deliberate dev override. This script makes that drift visible instead of letting it cost a
# debug round-trip ("I fixed it but nothing changed").
#
# Report-only by design. To actually sync for a quick live test, copy the file yourself —
# docs/development.md explains why dev overrides must be removed again before shipping.
set -uo pipefail
cd "$(dirname "$0")/.."

CLONE="${PI_PACKAGE_CLONE:-$HOME/.pi/agent/git/github.com/devskale/skale-skills}"

if [ ! -d "$CLONE/extensions" ]; then
    echo "package clone not found at $CLONE"
    echo "(is the skale-skills pi package installed? adjust PI_PACKAGE_CLONE if it lives elsewhere)"
    exit 1
fi

drift=0
for f in extensions/*.ts extensions/lib/*.ts; do
    [ -f "$f" ] || continue
    other="$CLONE/$f"
    if [ ! -f "$other" ]; then
        echo "ONLY IN CHECKOUT: $f"
        drift=$((drift + 1))
    elif ! cmp -s "$f" "$other"; then
        echo "DIFFERS:          $f"
        drift=$((drift + 1))
    fi
done

ver() { grep -hoE 'VERSION = "[0-9.]+"' "$1/extensions/xmodel.ts" 2>/dev/null | grep -oE '[0-9.]+' | head -1; }
echo ""
printf "checkout xmodel: %s\npackage xmodel:  %s\n" "$(ver .)" "$(ver "$CLONE")"

if [ "$drift" -eq 0 ]; then
    echo "in sync."
else
    echo ""
    echo "$drift file(s) drifted — the running agent is on older code until synced (push + pi install, or manual dev override)."
fi
exit "$drift"
