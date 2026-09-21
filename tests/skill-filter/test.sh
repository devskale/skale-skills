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

echo ""
echo "PASS=$PASS FAIL=$FAIL WARN=$WARN"
[ "$FAIL" -eq 0 ]
