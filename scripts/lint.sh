#!/usr/bin/env bash
# ── Quick lint & typecheck for the skale-skills extensions ────────────────────
# Runs Biome lint + `tsc` typecheck against extensions/*.ts.
#
# Deps are cached OUTSIDE the repo in ~/.cache/skale-skills/lint/ because pi's
# package update runs `git clean -fdx`, which wipes any node_modules/ inside the
# package. Pointing the toolchain at a cache dir keeps the repo pristine and the
# toolchain alive across updates (see docs/agent-skills-best-practices.md).
#
# Usage:
#   bash scripts/lint.sh            # full check (typecheck + lint)
#   bash scripts/lint.sh --lint     # biome only
#   bash scripts/lint.sh --type     # tsc only
#   bash scripts/lint.sh --fix      # biome + auto-fix safe issues
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE="${LINT_CACHE:-$HOME/.cache/skale-skills/lint}"
BIN="$CACHE/node_modules/.bin"

# Locate the installed pi package (for the @earendil-works/* type symlinks).
# Override with PI_PACKAGE=/path/to/pi-coding-agent if auto-detection fails.
PI="${PI_PACKAGE:-}"
if [ -z "$PI" ]; then
	for cand in \
		"/opt/homebrew/lib/node_modules/@earendil-works/pi-coding-agent" \
		"$(npm root -g 2>/dev/null)/@earendil-works/pi-coding-agent"; do
		if [ -n "$cand" ] && [ -d "$cand" ]; then PI="$cand"; break; fi
	done
fi

MODE="${1:-all}"

# ── 1. Toolchain (self-healing, cached outside repo) ─────────────────────────
ensure_toolchain() {
	if [ ! -x "$BIN/biome" ] || [ ! -x "$BIN/tsc" ]; then
		echo "→ installing lint toolchain (biome + typescript) into $CACHE …"
		mkdir -p "$CACHE"
		( cd "$CACHE" && npm init -y >/dev/null 2>&1 && npm install --no-save @biomejs/biome typescript@5.2 @types/node >/dev/null 2>&1 )
	fi
	# Ensure the pi type symlinks exist for tsc to resolve @earendil-works/*.
	if [ ! -e "$REPO/node_modules/@earendil-works/pi-agent-core" ]; then
		if [ -z "$PI" ] || [ ! -d "$PI" ]; then
			echo "✖ cannot find the installed pi package (needed for @earendil-works types)." >&2
			echo "  Set PI_PACKAGE=/path/to/pi-coding-agent and re-run." >&2
			exit 1
		fi
		mkdir -p "$REPO/node_modules/@earendil-works" "$REPO/node_modules/@types"
		ln -sfn "$PI/node_modules/@earendil-works/pi-ai"         "$REPO/node_modules/@earendil-works/pi-ai"
		ln -sfn "$PI/node_modules/@earendil-works/pi-tui"        "$REPO/node_modules/@earendil-works/pi-tui"
		ln -sfn "$PI/node_modules/typebox"                        "$REPO/node_modules/typebox"
		ln -sfn "$PI/node_modules/@earendil-works/pi-agent-core" "$REPO/node_modules/@earendil-works/pi-agent-core"
		ln -sfn "$PI"                                            "$REPO/node_modules/@earendil-works/pi-coding-agent"
		ln -sfn "$CACHE/node_modules/@types/node"                "$REPO/node_modules/@types/node"
	fi
	# Local tsconfig (not committed) scoped to extensions.
	if [ ! -f "$REPO/tsconfig.json" ]; then
		cat > "$REPO/tsconfig.json" <<'EOF'
{ "compilerOptions": { "target": "ES2022", "module": "commonjs", "moduleResolution": "node", "strict": true, "skipLibCheck": true, "noEmit": true, "esModuleInterop": true, "types": ["node"] }, "include": ["extensions/**/*.ts"] }
EOF
	fi
}

run_lint() {
	echo "── Biome lint (extensions/) ──"
	( cd "$REPO" && "$BIN/biome" check . )
}

run_fix() {
	echo "── Biome lint + safe fixes (extensions/) ──"
	( cd "$REPO" && "$BIN/biome" check --write . )
}

run_typecheck() {
	echo "── tsc typecheck (extensions/) ──"
	( cd "$REPO" && "$BIN/tsc" -p tsconfig.json --noEmit )
}

ensure_toolchain

FAIL=0
case "$MODE" in
	--lint) run_lint || FAIL=1 ;;
	--fix)  run_fix || FAIL=1 ;;
	--type) run_typecheck || FAIL=1 ;;
	*)      run_typecheck || FAIL=1; run_lint || FAIL=1 ;;
esac

if [ "$FAIL" -ne 0 ]; then
	echo ""
	echo "✖ lint/typecheck failed" >&2
	exit 1
fi

echo ""
echo "✔ lint clean"
