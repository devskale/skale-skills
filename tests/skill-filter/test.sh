#!/usr/bin/env bash
# skill-filter.sh test suite
#   bash tests/skill-filter/test.sh
# Tests the scripts/skill-filter.sh helper (package skill/extension filters +
# global MCP server management) against a TEMP COPY of settings — never the
# live ~/.pi/agent/settings.json or ~/.config/mcp/mcp.json.
set -uo pipefail
cd "$(dirname "$0")/../.."

SCRIPT=scripts/skill-filter.sh
PASS=0; FAIL=0; WARN=0

ok()   { PASS=$((PASS+1)); }
bad()  { FAIL=$((FAIL+1)); echo "  FAIL: $1" >&2; }
warn() { WARN=$((WARN+1)); echo "  WARN (skipped honestly): $1" >&2; }

echo "skill-filter helper tests"
echo "-------------------------"

# ── structure ──
[ -x "$SCRIPT" ] && ok || bad "$SCRIPT missing or not executable"
[ -f "$SCRIPT" ] && ok || bad "$SCRIPT missing"

# ── manifest glob-excludes must not carry a ./ prefix ──
# pi matches patterns against package-root-relative paths via minimatch;
# `!./skills/deprecated/**` silently matches NOTHING (see AGENTS.md gotcha).
# note: grep -F, not BRE — grep interprets ** as a repetition operator
grep -Fq '"!skills/deprecated/**"' package.json && ok || bad 'package.json: manifest exclusion !skills/deprecated/** missing'
grep -q '"!\./' package.json && bad 'package.json: ./-prefixed glob-exclude silently matches nothing (drop the ./ prefix)' || ok

# ── shellcheck (if available) ──
if command -v shellcheck >/dev/null 2>&1; then
  if shellcheck "$SCRIPT" >/tmp/sf-shellcheck.log 2>&1; then
    ok
  else
    bad "shellcheck: $(tail -1 /tmp/sf-shellcheck.log)"
  fi
else
  warn "shellcheck not installed"
fi

# ── build a temp copy of the script pointing at temp settings ──
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
sed "s|SETTINGS=\"\$HOME/.pi/agent/settings.json\"|SETTINGS=\"$TMP_DIR/settings.json\"|" "$SCRIPT" > "$TMP_DIR/sf.sh"
chmod +x "$TMP_DIR/sf.sh"

# seed a minimal settings.json with the skale-skills package
cat > "$TMP_DIR/settings.json" <<'JSON'
{
  "packages": [
    "npm:other",
    {
      "source": "git:github.com/devskale/skale-skills",
      "skills": ["web-search", "fetch-url", "!skills/deprecated/**"],
      "extensions": ["extensions/heartbeat.ts", "extensions/imagegen.ts"]
    }
  ]
}
JSON

# helper: read the package's skills/extensions arrays
pkg_arr() {
  python3 - "$TMP_DIR/settings.json" "$1" <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))
for x in p["packages"]:
    if isinstance(x,dict) and x.get("source")=="git:github.com/devskale/skale-skills":
        print(json.dumps(x.get(sys.argv[2],[]))); break
PY
}

# ── list ──
"$TMP_DIR/sf.sh" list >/dev/null 2>&1 && ok || bad "list failed"

# ── disable a whole tree (must be ! glob, not -) ──
"$TMP_DIR/sf.sh" disable skill deprecated >/dev/null 2>&1
if pkg_arr skills | grep -q '"!skills/deprecated/\*\*"'; then ok; else bad "disable deprecated should store !skills/deprecated/** glob"; fi

# ── disable a single skill (must be - exact) ──
"$TMP_DIR/sf.sh" disable skill web-search >/dev/null 2>&1
if pkg_arr skills | grep -q '"-skills/web-search/SKILL.md"'; then ok; else bad "disable web-search should store -skills/web-search/SKILL.md"; fi

# ── enable a single skill (must be + exact) ──
"$TMP_DIR/sf.sh" enable skill web-search >/dev/null 2>&1
if pkg_arr skills | grep -q '"+skills/web-search/SKILL.md"'; then ok; else bad "enable web-search should store +skills/web-search/SKILL.md"; fi

# ── disable an archived skill (skills/deprecated/<name>) ──
"$TMP_DIR/sf.sh" disable skill viewimg >/dev/null 2>&1
if pkg_arr skills | grep -q '"-skills/deprecated/viewimg/SKILL.md"'; then ok; else bad "disable archived viewimg should store -skills/deprecated/viewimg/SKILL.md"; fi

# ── extension disable/enable ──
"$TMP_DIR/sf.sh" disable extension imagegen >/dev/null 2>&1
if pkg_arr extensions | grep -q '"-extensions/imagegen.ts"'; then ok; else bad "disable imagegen should store -extensions/imagegen.ts"; fi
"$TMP_DIR/sf.sh" enable extension imagegen >/dev/null 2>&1
if pkg_arr extensions | grep -q '"+extensions/imagegen.ts"'; then ok; else bad "enable imagegen should store +extensions/imagegen.ts"; fi

# ── idempotency: re-disable deprecated keeps a single tree-glob entry ──
"$TMP_DIR/sf.sh" disable skill deprecated >/dev/null 2>&1
"$TMP_DIR/sf.sh" disable skill deprecated >/dev/null 2>&1
COUNT=$(pkg_arr skills | python3 -c "import sys,json;print(sum(1 for e in json.load(sys.stdin) if e=='!skills/deprecated/**'))")
[ "$COUNT" -eq 1 ] && ok || bad "re-disable deprecated should keep exactly one tree-glob entry (got $COUNT)"

# ── error handling ──
if "$TMP_DIR/sf.sh" disable skill nonexistent >/dev/null 2>&1; then bad "unknown skill should exit non-zero"; else ok; fi
if "$TMP_DIR/sf.sh" disable bogus foo >/dev/null 2>&1; then bad "unknown type should exit non-zero"; else ok; fi
if "$TMP_DIR/sf.sh" frobnicate >/dev/null 2>&1; then bad "unknown command should exit non-zero"; else ok; fi

# ── MCP: disable/enable on a temp config ──
MCP_TMP="$TMP_DIR/mcp.json"
cat > "$MCP_TMP" <<'JSON'
{"mcpServers":{"chrome-devtools":{"command":"chrome-autoallow","args":["run"]}}}
JSON
sed "s|SETTINGS=\"\$HOME/.pi/agent/settings.json\"|SETTINGS=\"$TMP_DIR/settings.json\"|; s|MCP_CONFIG=\"\$HOME/.config/mcp/mcp.json\"|MCP_CONFIG=\"$MCP_TMP\"|" "$SCRIPT" > "$TMP_DIR/sf-mcp.sh"
chmod +x "$TMP_DIR/sf-mcp.sh"
"$TMP_DIR/sf-mcp.sh" disable mcp chrome-devtools >/dev/null 2>&1
if grep -q '"mcpServers"' "$MCP_TMP" 2>/dev/null && grep -q 'chrome-devtools' "$MCP_TMP"; then
  bad "disable mcp should remove chrome-devtools"
else
  ok
fi
"$TMP_DIR/sf-mcp.sh" list mcp >/dev/null 2>&1 && ok || bad "list mcp failed on empty config"

# ── seed-defaults: fresh install (string package entry) ──
# pi install writes a plain string on fresh machines; seed must convert it to
# the object form with the minimal whitelist (web-search + fetch-url).
cat > "$TMP_DIR/settings.json" <<'JSON'
{
  "packages": [
    "npm:other",
    "git:github.com/devskale/skale-skills"
  ]
}
JSON
"$TMP_DIR/sf.sh" seed-defaults >/dev/null 2>&1 && ok || bad "seed-defaults failed on fresh string entry"
SEEDED=$(python3 -c "
import json
p=json.load(open('$TMP_DIR/settings.json'))
for x in p['packages']:
    if isinstance(x,dict) and 'skale-skills' in x.get('source',''):
        print(json.dumps(x.get('skills',[]))); break
")
echo "$SEEDED" | grep -q '"skills/web-search/SKILL.md"' && echo "$SEEDED" | grep -q '"skills/fetch-url/SKILL.md"' && ok || bad "seed should whitelist web-search + fetch-url (got $SEEDED)"
echo "$SEEDED" | grep -q 'deprecated' && ok || bad "seed should include the deprecated safety net"
python3 -c "
import json,sys
p=json.load(open('$TMP_DIR/settings.json'))
npm_other=[x for x in p['packages'] if x=='npm:other']
assert npm_other, 'seed must preserve other packages'
" && ok || bad "seed clobbered sibling packages"

# ── seed-defaults: object entry without skills key ──
cat > "$TMP_DIR/settings.json" <<'JSON'
{
  "packages": [
    {"source": "git:github.com/devskale/skale-skills", "extensions": ["extensions/heartbeat.ts"]}
  ]
}
JSON
"$TMP_DIR/sf.sh" seed-defaults >/dev/null 2>&1 && ok || bad "seed-defaults failed on object entry without skills"
python3 -c "
import json
p=json.load(open('$TMP_DIR/settings.json'))
x=p['packages'][0]
assert 'skills/web-search/SKILL.md' in x['skills'], 'skills not seeded'
assert x['extensions']==['extensions/heartbeat.ts'], 'seed must preserve extensions filter'
" && ok || bad "seed dropped existing extensions filter"

# ── seed-defaults: respects existing customization (idempotent) ──
cat > "$TMP_DIR/settings.json" <<'JSON'
{
  "packages": [
    {"source": "git:github.com/devskale/skale-skills", "skills": ["+skills/youtube/SKILL.md"]}
  ]
}
JSON
"$TMP_DIR/sf.sh" seed-defaults >/dev/null 2>&1 && ok || bad "seed-defaults should exit 0 when filter exists"
if grep -q 'web-search/SKILL.md' "$TMP_DIR/settings.json"; then bad "seed must not touch an existing skills filter"; else ok; fi

# ── seed-defaults: local-path string entry + no-package graceful ──
cat > "$TMP_DIR/settings.json" <<'JSON'
{"packages": ["~/code/agents/skills/skale-skills"]}
JSON
"$TMP_DIR/sf.sh" seed-defaults >/dev/null 2>&1 && ok || bad "seed-defaults failed on local-path entry"
python3 -c "
import json
p=json.load(open('$TMP_DIR/settings.json'))
x=p['packages'][0]
assert isinstance(x,dict) and x['source']=='~/code/agents/skills/skale-skills', 'source must be preserved'
" && ok || bad "seed must preserve the original source string"
cat > "$TMP_DIR/settings.json" <<'JSON'
{"packages": ["npm:other"]}
JSON
"$TMP_DIR/sf.sh" seed-defaults >/dev/null 2>&1 && ok || bad "seed-defaults should exit 0 when package absent"

# ── seed-defaults exists in install.sh right after pi install ──
grep -q 'skill-filter.sh seed-defaults' install.sh && ok || bad "install.sh should seed defaults after pi install"

echo ""
echo "PASS=$PASS FAIL=$FAIL WARN=$WARN"
[ "$FAIL" -eq 0 ]
