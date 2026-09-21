#!/usr/bin/env bash
# skill-filter.sh — enable/disable skills, extensions, and MCP servers for the
# skale-skills pi package (and global MCP servers).
#
# Manages the three resource surfaces that pi loads from this repo:
#   1. Package filters in ~/.pi/agent/settings.json (the git:github.com/devskale/
#      skale-skills package object) — skills[] and extensions[].
#   2. Global MCP servers in ~/.config/mcp/mcp.json (chrome-devtools, ...).
#
# WHY THIS EXISTS (the "-" vs "!" gotcha):
#   - `-path`  force-excludes an EXACT path. It does NOT expand globs, so
#              `-skills/deprecated/**` is a silent no-op.
#   - `!pattern` glob-excludes via minimatch, so `!skills/deprecated/**` correctly
#              excludes a whole tree.
#   - `+path`  force-includes an exact path.
#   `pi config` only writes per-file `-path` entries (it has no "whole tree"
#   option). This script encodes the correct semantics so the archive convention
#   (skills/deprecated/**) works with one entry.
#
# Usage:
#   scripts/skill-filter.sh list [skill|extension|mcp]
#   scripts/skill-filter.sh enable  <skill|extension> <name>
#   scripts/skill-filter.sh disable <skill|extension> <name>|deprecated
#   scripts/skill-filter.sh enable|disable mcp <server-name>
#
# Examples:
#   scripts/skill-filter.sh list
#   scripts/skill-filter.sh list mcp
#   scripts/skill-filter.sh disable skill viewimg        # → !skills/deprecated/viewimg/SKILL.md
#   scripts/skill-filter.sh disable skill deprecated      # → !skills/deprecated/**  (whole tree)
#   scripts/skill-filter.sh enable  skill viewimg         # → +skills/deprecated/viewimg/SKILL.md
#   scripts/skill-filter.sh disable extension imagegen    # → -extensions/imagegen.ts
#   scripts/skill-filter.sh disable mcp chrome-devtools   # remove from ~/.config/mcp/mcp.json
set -u

SETTINGS="$HOME/.pi/agent/settings.json"
MCP_CONFIG="$HOME/.config/mcp/mcp.json"
PKG_SOURCE="git:github.com/devskale/skale-skills"

die() { echo "error: $*" >&2; exit 1; }

# --- find the skale-skills package object index in settings.json ---
pkg_index() {
  python3 - "$SETTINGS" "$PKG_SOURCE" <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))
src=sys.argv[2]
for i,x in enumerate(p.get("packages",[])):
    if isinstance(x,dict) and x.get("source")==src:
        print(i); sys.exit(0)
sys.exit(1)
PY
}

# --- filter manipulation helpers (python) ---
# update_filter <type:skills|extensions> <pattern> <enable:0|1>
update_filter() {
  local type="$1" pattern="$2" enable="$3"
  python3 - "$SETTINGS" "$PKG_SOURCE" "$type" "$pattern" "$enable" <<'PY'
import json,sys
path,src,typ,pattern,enable=sys.argv[1],sys.argv[2],sys.argv[3],sys.argv[4],sys.argv[5]
enable=enable=="1"
p=json.load(open(path))
for x in p.get("packages",[]):
    if isinstance(x,dict) and x.get("source")==src:
        cur=x.get(typ,[])
        # strip any existing +/-/! prefix for this pattern
        def strip(s):
            return s[1:] if s[:1] in "+-!" else s
        kept=[e for e in cur if strip(e)!=pattern]
        if enable:
            kept.append(f"+{pattern}")
            prefix="+"
        else:
            # glob form for tree excludes, exact form otherwise
            if pattern.endswith("/**"):
                kept.append(f"!{pattern}")
                prefix="!"
            else:
                kept.append(f"-{pattern}")
                prefix="-"
        x[typ]=kept
        break
json.dump(p,open(path,"w"),indent=2)
print(f"  {typ}: {prefix}{pattern}")
PY
}

# --- MCP helpers ---
mcp_list() {
  if [ ! -f "$MCP_CONFIG" ]; then echo "  (no $MCP_CONFIG)"; return; fi
  python3 - "$MCP_CONFIG" <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))
for name,cfg in p.get("mcpServers",{}).items():
    cmd=cfg.get("command","")
    args=" ".join(cfg.get("args",[]))
    print(f"  {name}: {cmd} {args}".rstrip())
PY
}

mcp_set() {
  local name="$1" enable="$2"
  python3 - "$MCP_CONFIG" "$name" "$enable" <<'PY'
import json,sys,os
path,name,enable=sys.argv[1],sys.argv[2],sys.argv[3]
p={}
if os.path.exists(path):
    p=json.load(open(path))
p.setdefault("mcpServers",{})
if enable=="1":
    # enable = ensure present. If not configured, we can't guess the command.
    if name not in p["mcpServers"]:
        print(f"  mcp {name}: NOT configured, nothing to enable (add it manually to {path})")
        sys.exit(0)
    print(f"  mcp {name}: already enabled")
else:
    if name in p["mcpServers"]:
        del p["mcpServers"][name]
        print(f"  mcp {name}: disabled")
    else:
        print(f"  mcp {name}: not configured")
if not p["mcpServers"]:
    p.pop("mcpServers",None)
os.makedirs(os.path.dirname(path),exist_ok=True)
json.dump(p,open(path,"w"),indent=2)
PY
}

# --- seed minimal default activation (run right after `pi install`) ---
# Writes the whitelist default (web-search + fetch-url, deprecated excluded)
# into the package's skills filter — pi treats plain patterns as the include
# set (applyPatterns step 1), so everything else stays opt-in via `pi config`.
# Idempotent + respects customization: if a skills filter already exists,
# it is left untouched.
seed_defaults() {
  if [ ! -f "$SETTINGS" ]; then echo "  (no $SETTINGS — pi not set up yet, skipping seed)"; return 0; fi
  python3 - "$SETTINGS" <<'PY'
import json,sys
path=sys.argv[1]
p=json.load(open(path))
for i,x in enumerate(p.get("packages",[])):
    src=x if isinstance(x,str) else x.get("source","")
    if "skale-skills" not in src:
        continue
    if isinstance(x,dict) and "skills" in x:
        print("  skills filter already set — leaving your customization untouched")
        sys.exit(0)
    obj=x if isinstance(x,dict) else {"source":x}
    obj["skills"]=[
        "skills/web-search/SKILL.md",
        "skills/fetch-url/SKILL.md",
        "!skills/deprecated/**",
    ]
    p["packages"][i]=obj
    json.dump(p,open(path,"w"),indent=2)
    print("  seeded default activation: web-search + fetch-url (others opt-in via pi config)")
    sys.exit(0)
print("  skale-skills package not found in settings — nothing to seed")
PY
}

list_all() {
  echo "── skale-skills package filters ($SETTINGS) ──"
  local idx; idx=$(pkg_index) || die "skale-skills package not found in settings"
  python3 - "$SETTINGS" "$idx" <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))
x=p["packages"][int(sys.argv[2])]
for typ in ("skills","extensions"):
    print(f"  [{typ}]")
    for e in x.get(typ,[]):
        print(f"    {e}")
PY
  echo "── MCP servers ($MCP_CONFIG) ──"
  mcp_list
}

run_toggle() {
  local mode="$1" type="$2" name="$3"
  local enable=0; [ "$mode" = "enable" ] && enable=1
  case "$type" in
    skill)
      local pattern
      if [ "$name" = "deprecated" ]; then
        pattern="skills/deprecated/**"
      elif [ -d "skills/$name" ]; then
        pattern="skills/$name/SKILL.md"
      elif [ -d "skills/deprecated/$name" ]; then
        pattern="skills/deprecated/$name/SKILL.md"
      else
        die "unknown skill: $name (not in skills/ or skills/deprecated/)"
      fi
      update_filter skills "$pattern" "$enable"
      ;;
    extension)
      local pattern
      if [ -f "extensions/$name" ]; then
        pattern="extensions/$name"
      elif [ -f "extensions/$name.ts" ]; then
        pattern="extensions/$name.ts"
      else
        die "unknown extension: $name (not in extensions/)"
      fi
      update_filter extensions "$pattern" "$enable"
      ;;
    mcp)
      mcp_set "$name" "$enable"
      ;;
    *) die "unknown type: $type (skill|extension|mcp)" ;;
  esac
}

cmd="${1:-list}"; shift || true
case "$cmd" in
  list)
    if [ -n "${1:-}" ]; then
      case "$1" in
        mcp) mcp_list ;;
        skill|extension) echo "  (see full list)"; list_all ;;
        *) die "unknown type: $1 (skill|extension|mcp)" ;;
      esac
    else
      list_all
    fi
    ;;
  enable|disable)
    [ -n "${1:-}" ] || die "usage: $0 $cmd <skill|extension|mcp> <name>"
    run_toggle "$cmd" "$1" "$2"
    ;;
  seed-defaults)
    seed_defaults
    ;;
  *) die "unknown command: $cmd (list|enable|disable|seed-defaults)" ;;
esac
