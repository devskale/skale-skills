#!/usr/bin/env bash
# gen-registry.sh — render references/registry.md from the installed rodney
# binary's own help registry (`rodney help --json`).
#
# The registry is the binary's self-description: command, usage, description,
# flags, examples, grouped. Running this script after a binary update keeps
# the browsable reference in sync — no hand-maintained drift.
#
# Usage:
#   scripts/gen-registry.sh                     # print to stdout
#   scripts/gen-registry.sh --write             # write references/registry.md
#
# The drift check in tests/rodney/test.sh regenerates and diffs — a stale
# registry.md fails the suite.
set -euo pipefail
cd "$(dirname "$0")/.."

cat > /tmp/gen-registry.py <<'PYEOF'
import sys, json, collections

d = json.load(sys.stdin)
by_group = collections.defaultdict(list)
for name, c in d.items():
    by_group[c.get("group", "Other")].append((name, c))

lines = []
lines.append("# Rodney Command Registry (generated)")
lines.append("")
lines.append("> **Generated from the installed binary** (`rodney help --json`) — do not edit")
lines.append("> by hand; regenerate with `scripts/gen-registry.sh --write`. The binary is")
lines.append("> the source of truth; for one command at runtime prefer `rodney help <command>`.")
lines.append("")

for group in sorted(by_group):
    lines.append("## " + group)
    lines.append("")
    for name, c in sorted(by_group[group]):
        usage = c.get("usage", "rodney " + name)
        lines.append("### `" + usage + "`")
        lines.append("")
        desc = c.get("description", "")
        if desc:
            lines.append(desc)
            lines.append("")
        flags = c.get("flags") or []
        if flags:
            lines.append("Flags:")
            lines.append("")
            for f in flags:
                lines.append("- `" + f + "`")
            lines.append("")
        ex = c.get("examples") or []
        if ex:
            lines.append("```bash")
            for e in ex:
                lines.append(e)
            lines.append("```")
            lines.append("")

sys.stdout.write("\n".join(lines) + "\n")
PYEOF

if [ "${1:-}" = "--write" ]; then
    rodney help --json | python3 /tmp/gen-registry.py > references/registry.md
    echo "✓ references/registry.md regenerated ($(grep -c '^### ' references/registry.md) commands)"
else
    rodney help --json | python3 /tmp/gen-registry.py
fi
rm -f /tmp/gen-registry.py
