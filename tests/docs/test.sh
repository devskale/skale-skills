#!/usr/bin/env bash
# docs integrity test suite
#   bash tests/docs/test.sh
# Catches two kinds of docs rot:
#   1. DEAD LINKS — a markdown link in a live hub (AGENTS.md, README.md,
#      CODING_RULES.md) points at a local file that doesn't exist.
#   2. ORPHANED DOCS — a docs/ file that no live hub references at all.
# SVG/PNG/diagrams are exempt from the orphan check: they're wired in via
# docs/skill-diagrams.md (and their .d2 sources), not by name in a hub.
set -uo pipefail
cd "$(dirname "$0")/../.."

ROOT="$(pwd)"
PASS=0; FAIL=0; WARN=0

ok()   { PASS=$((PASS+1)); }
bad()  { FAIL=$((FAIL+1)); echo "  FAIL: $1" >&2; }
warn() { WARN=$((WARN+1)); echo "  WARN (skipped honestly): $1" >&2; }

echo "docs integrity tests"
echo "--------------------"

HUBS=(AGENTS.md README.md CODING_RULES.md)

# ── helper: does a link target resolve to a local file? ──
# Returns 0 (yes) if the target is a relative path to an existing local file.
# Returns 1 (no / not applicable) for URLs, anchors, absolute paths, wildcards.
is_local_file() {
    local target="$1"
    # strip fragment / query
    target="${target%%#*}"
    target="${target%%\?*}"
    case "$target" in
        http*|https*|mailto:*|\#*|/*|~*) return 1 ;;
    esac
    local rel="${target#./}"
    [[ "$rel" == *"*"* ]] && return 1
    # must look like a real file (has an extension we ship)
    case "$rel" in
        *".md"|*".sh"|*".ts"|*".py"|*".json"|*".d2"|*".svg"|*".png") ;;
        *) return 1 ;;
    esac
    [ -e "$ROOT/$rel" ]
}

# ── 1. dead links in the live hubs ──
for hub in "${HUBS[@]}"; do
    [ -f "$hub" ] || { warn "$hub missing"; continue; }
    dead=0
    while IFS= read -r target; do
        if is_local_file "$target"; then
            : # exists — good
        elif [ -n "$target" ] && grep -qE '\.(md|sh|ts|py|json|d2|svg|png)$' <<<"$target"; then
            # target has a file extension but is_local_file returned false
            # → either it doesn't exist or it's a URL. Distinguish:
            case "$target" in
                http*|https*|mailto:*|\#*|/*|~*) : ;; # not a local file — skip
                *)
                    # resolve and check existence explicitly
                    rel="${target#./}"
                    if [ ! -e "$ROOT/$rel" ]; then
                        dead=$((dead+1))
                        echo "  DEAD LINK in $hub: $rel" >&2
                    fi
                    ;;
            esac
        fi
    done < <(grep -oE '\]\([^)#]+\)' "$hub" | sed 's/](//;s/)$//')
    if [ "$dead" -eq 0 ]; then ok; else bad "$hub has $dead dead link(s)"; fi
done

# ── 2. orphaned docs files ──
# A docs/ file is orphaned if NONE of the live hubs reference it by name.
# Exempt binary/vector assets that are wired via skill-diagrams.md, not a hub.
# Root-level .md docs (pi-architecture.md, LAYOUT.md, …) are checked the same way —
# they were silently skipped until now, because the loop only walked docs/.
ORPHAN_EXEMPT='\.(svg|png)$|\.d2$|^docs/diagrams/|^docs/images/'
DOC_FILES=$( { git ls-files docs/ | grep -vE "$ORPHAN_EXEMPT"; git ls-files -- '*.md' ':!docs/**' ':!skills/**' ':!tests/**' ':!deprecated/**' ':!skills/deprecated/**'; } | sort -u )
for f in $DOC_FILES; do
    base="$(basename "$f")"
    referenced=0
    for hub in "${HUBS[@]}"; do
        [ -f "$hub" ] || continue
        if grep -qF "$base" "$hub" 2>/dev/null; then referenced=1; break; fi
    done
    # Fall back: wired into another docs file that is itself referenced.
    if [ "$referenced" -eq 0 ] && grep -rqF "$base" docs/ 2>/dev/null; then
        referenced=1
    fi
    [ "$referenced" -eq 1 ] && ok || bad "orphaned docs file: $f (no live hub references it)"
done

echo ""

# ── 3. dead relative links in EVERY shipped markdown file ──
# The hub check above only looks at AGENTS.md / README.md / CODING_RULES.md, so a
# broken cross-reference inside docs/ (e.g. ../skills/x/ from docs/browser-use/) is
# invisible — four such links shipped for months. This walks every .md we publish.
#
# Skipped: skills/deprecated/ (archived vendor docs with spaces in filenames, kept
# verbatim for archaeology) and testbed/ (local, gitignored).
dead_all=0
while IFS= read -r f; do
    while IFS= read -r target; do
        case "$target" in
            http*|https*|mailto:*|\#*|/*|~*) continue ;;
        esac
        target="${target%%#*}"; target="${target%%\?*}"
        [ -z "$target" ] && continue
        target="${target#./}"
        # %20 in a link must decode to a space-containing path; resolve against
        # the file's DIRECTORY (dirname), not the file itself
        resolved=$(python3 -c "
import os,sys,urllib.parse
print(os.path.normpath(os.path.join(sys.argv[1], urllib.parse.unquote(sys.argv[2]))))" "$(dirname "$ROOT/$f")" "$target")
        if [ ! -e "$resolved" ]; then
            dead_all=$((dead_all+1))
            echo "  DEAD LINK in $f: $target" >&2
        fi
    done < <(grep -oE '\]\([^)]+\)' "$f" | sed 's/](//;s/)$//')
done < <(git ls-files '*.md' | grep -vE '^skills/deprecated/|^testbed/|^node_modules/')
if [ "$dead_all" -eq 0 ]; then ok; else bad "$dead_all dead relative link(s) outside the hubs"; fi

echo ""
echo "PASS=$PASS FAIL=$FAIL WARN=$WARN"
[ "$FAIL" -eq 0 ]
