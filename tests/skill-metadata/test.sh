#!/usr/bin/env bash
# tests/skill-metadata/test.sh — SKILL.md frontmatter hygiene.
# The `description` field is ALWAYS-LOADED context (every turn, every session):
# it is a routing pointer, not documentation. Rule: What + Use-when, ≤ 600 chars.
# Mechanics (flags, backends, auth, install) belong in the body.
set -uo pipefail
cd "$(dirname "$0")/../.."

PASS=0; FAIL=0; WARN=0
ok()   { PASS=$((PASS + 1)); }
bad()  { FAIL=$((FAIL + 1)); echo "  FAIL: $1" >&2; }
warn() { WARN=$((WARN + 1)); echo "  WARN (skipped honestly): $1" >&2; }
assert() { if eval "$2" >/dev/null 2>&1; then ok; else bad "$1"; fi; }

MAX_DESC=600

echo "skill-metadata tests"
echo "--------------------"

lens=()
for f in skills/*/SKILL.md; do
    name=$(basename "$(dirname "$f")")
    [ "$name" = "deprecated" ] && continue
    t=$(cat "$f")

    assert "skills/$name: name matches directory" "[ \"\$(grep -m1 '^name:' '$f' | sed 's/^name:[[:space:]]*//')\" = \"$name\" ]"

    # YAML parseability: invalid frontmatter kills the WHOLE skill load in pi
    # (visualize broke youtube+vtd with it, 2026-10). Parse with PyYAML when
    # available; fall back to an unquoted-colon scan otherwise.
    if python3 -c "import yaml" 2>/dev/null; then
        if python3 -c "
import yaml, sys
f = open('$f').read()
fm = f.split('---')[1] if f.startswith('---') else ''
try:
    yaml.safe_load(fm)
except yaml.YAMLError as e:
    print(f'skills/$name: YAML parse error: ' + str(e).replace(chr(10), ' ')[:200]); sys.exit(1)"; then
            ok
        else
            bad "$(python3 -c "
import yaml
f = open('$f').read()
fm = f.split('---')[1] if f.startswith('---') else ''
try:
    yaml.safe_load(fm)
except yaml.YAMLError as e:
    print(str(e).replace(chr(10), ' ')[:200])")"
        fi
    else
        # no PyYAML: flag unquoted values containing ': ' (the visualize failure mode)
        if python3 -c "
import re, sys
fm = open('$f').read().split('---')[1]
for line in fm.splitlines():
    m = re.match(r'^(description|name|version):(.*)$', line)
    if m and m.group(2).strip() and not m.group(2).strip().startswith(('\"', \"'\")):
        if ': ' in m.group(2) or m.group(2).rstrip().endswith(':'):
            print(f'skills/$name: unquoted colon in {m.group(1)}: {m.group(2).strip()[:60]}'); sys.exit(1)
sys.exit(0)"; then
            ok
        else
            bad "skills/$name: unquoted colon in frontmatter (quote the value)"
        fi
    fi

    if ! grep -q "^description:" "$f"; then
        bad "skills/$name: no description"
        continue
    fi

    desc_len=$(python3 -c "
import re
t = open('$f').read()
m = re.search(r'^description:\s*\"?(.*?)\"?\s*\$', t, re.M | re.S)
d = re.split(r'\n[a-z-]+:', m.group(1))[0].strip() if m else ''
print(len(d))")

    if [ "$desc_len" -gt "$MAX_DESC" ]; then
        bad "skills/$name: description $desc_len chars (max $MAX_DESC) — move mechanics to the body"
    else
        ok
        lens+=("$desc_len")
    fi

    if ! grep -qE "Use when|Use it when" "$f"; then
        warn "skills/$name: description has no 'Use when' clause (routing signal)"
    fi
done

if [ "${#lens[@]}" -gt 0 ]; then
    median=$(printf '%s\n' "${lens[@]}" | sort -n | awk '{a[NR]=$1} END{print (NR%2) ? a[(NR+1)/2] : (a[NR/2]+a[NR/2+1])/2}')
    echo "  description median: ${median} chars across ${#lens[@]} skills (target ≈ 200, max $MAX_DESC)"
fi

echo ""
echo "PASS: $PASS  FAIL: $FAIL  WARN: $WARN"
if [ "$FAIL" -ne 0 ]; then
    echo "RESULT: FAIL"
    exit 1
fi
echo "RESULT: PASS"
