#!/usr/bin/env bash
# rodney-ps — Show rodney Chrome processes. Thin wrapper over rodney-cleanup.sh.
# Resolves its own symlinked location so it works from ~/.local/bin.

# Resolve the real path of this script, following symlinks (macOS-safe: no readlink -f).
SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SOURCE" ]; do
    DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"
    SOURCE="$(readlink "$SOURCE")"
    [[ "$SOURCE" != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"

exec "$SCRIPT_DIR/rodney-cleanup.sh" "$@"
