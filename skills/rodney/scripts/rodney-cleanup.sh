#!/usr/bin/env bash
# rodney-cleanup — Inspect and clean up rodney Chrome processes & temp files.
#
# Usage:
#   rodney-cleanup                 # Inspect only (safe, no changes)
#   rodney-cleanup --clean         # Clean stale state + orphan processes (non-interactive)
#   rodney-cleanup --ps            # Show all rodney Chrome processes (alias for inspect)
#   rodney-cleanup --json          # Machine-readable summary (no human banner)
#
# Detects rodney's Chromium by its user-data-dir (global ~/.rodney or local ./.rodney),
# NOT by "chrome" in the process name — rodney's binary is Chromium and its remote
# debugging port is 0 by default. See skills/rodney/scripts/README.md.

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"

# Mode resolution: --clean wins; else an explicit flag; else a "ps"-named symlink
# (rodney-ps) implies inspect/ps mode.
MODE="inspect"
if [[ "${1:-}" == "--clean" ]]; then
    MODE="clean"
elif [[ "${1:-}" == "--ps" ]] || [[ "$SCRIPT_NAME" == *ps* ]]; then
    MODE="ps"
elif [[ "${1:-}" == "--json" ]]; then
    MODE="json"
fi

# Locate state files: global ~/.rodney/state.json plus any local ./.rodney/state.json
# (rodney --local sessions). We scan cwd for a local one.
STATE_FILES=()
[[ -f "$HOME/.rodney/state.json" ]] && STATE_FILES+=("$HOME/.rodney/state.json")
if [[ -f "./.rodney/state.json" ]] && [[ "./.rodney/state.json" != "$HOME/.rodney/state.json" ]]; then
    STATE_FILES+=("./.rodney/state.json")
fi

# A helper to read a JSON field with or without jq.
json_field() { # file key
    if command -v jq &>/dev/null; then
        jq -r --arg k "$2" '.[$k] // empty' "$1" 2>/dev/null || echo ""
    else
        grep -o '"'"$2"'":[^,}]*' "$1" | head -1 | sed -E 's/^[^:]*:[[:space:]]*"?//; s/"$//' || echo ""
    fi
}

# Collect rodney Chromium PIDs (any process whose user-data-dir points at a .rodney dir).
rodney_pids() {
    ps aux | grep -E 'user-data-dir=.*\.rodney' | grep -v grep | awk '{print $2}'
}

# ── Inspect / ps / json: report only ─────────────────────────────────
# Collects state into globals (managed_pid, total, orphans, json_out) so the
# json mode can emit only JSON without a human banner.
collect() {
    managed_pid="" total=0 orphans=0

    if [[ ${#STATE_FILES[@]} -gt 0 ]]; then
        for sf in "${STATE_FILES[@]}"; do
            local pid
            pid=$(json_field "$sf" chrome_pid)
            if [[ -n "$pid" ]] && ps -p "$pid" &>/dev/null; then
                managed_pid="$pid"
            fi
        done
    fi

    local pids
    pids=$(rodney_pids || true)
    for pid in $pids; do
        total=$((total + 1))
        if [[ "$pid" != "$managed_pid" ]]; then
            orphans=$((orphans + 1))
        fi
    done
}

report() {
    collect

    if [[ ${#STATE_FILES[@]} -gt 0 ]]; then
        for sf in "${STATE_FILES[@]}"; do
            local pid
            pid=$(json_field "$sf" chrome_pid)
            if [[ -n "$pid" ]]; then
                if ps -p "$pid" &>/dev/null; then
                    local port=""
                    port=$(json_field "$sf" debug_url | sed -E 's|.*:([0-9]+)/.*|\1|')
                    if [[ -n "$port" ]] && lsof -i ":$port" &>/dev/null; then
                        echo "📋 $sf → PID $pid RUNNING (port $port listening)"
                    else
                        echo "📋 $sf → PID $pid RUNNING (port ${port:-?} NOT listening ⚠️)"
                    fi
                else
                    echo "📋 $sf → PID $pid DEAD (stale state)"
                fi
            fi
        done
    else
        echo "📋 No rodney state.json found (global or local)"
    fi

    local pids
    pids=$(rodney_pids || true)
    echo ""
    echo "--- rodney Chromium processes (user-data-dir=*.rodney) ---"
    if [[ -z "$pids" ]]; then
        echo "(none found)"
    else
        for pid in $pids; do
            local status="[ORPHAN]"
            [[ "$pid" == "$managed_pid" ]] && status="[MANAGED]"
            local dir
            dir=$(ps -p "$pid" -o command= 2>/dev/null | grep -oE 'user-data-dir=[^ ]*' | cut -d= -f2 || echo "?")
            echo "  PID $pid $status  $dir"
        done
    fi
    echo ""
    echo "Total: $total rodney Chromium process(es); $orphans orphan(s)"
}

json_out() {
    collect
    local mpid="null"
    [[ -n "$managed_pid" ]] && mpid="$managed_pid"
    printf '{"managed_pid":%s,"total_chrome_processes":%d,"orphan_processes":%d}\n' "$mpid" "$total" "$orphans"
}

# ── Clean mode: non-interactive, safe by default ─────────────────────
clean() {
    local cleaned=0

    # 1. Remove stale state files whose Chrome PID is dead.
    for sf in "${STATE_FILES[@]:-}"; do
        local pid
        pid=$(json_field "$sf" chrome_pid)
        if [[ -n "$pid" ]] && ! ps -p "$pid" &>/dev/null; then
            echo "🧹 Removing stale $sf (PID $pid is dead)"
            rm -f "$sf"
            cleaned=$((cleaned + 1))
        fi
    done

    # 2. Kill orphan rodney Chromium processes (those not referenced by a live state PID).
    local managed_pid=""
    for sf in "${STATE_FILES[@]:-}"; do
        local pid
        pid=$(json_field "$sf" chrome_pid)
        if [[ -n "$pid" ]] && ps -p "$pid" &>/dev/null; then
            managed_pid="$pid"
        fi
    done

    for pid in $(rodney_pids); do
        if [[ "$pid" != "$managed_pid" ]]; then
            echo "🧹 Killing orphan rodney Chromium PID $pid"
            kill "$pid" 2>/dev/null || true
            cleaned=$((cleaned + 1))
        fi
    done

    # 3. Clean old /tmp/chrome-* dirs (>24h old). Never touch active ones.
    while IFS= read -r dir; do
        [[ -z "$dir" ]] && continue
        if [[ -n "$(find "$dir" -maxdepth 0 -mtime +1 2>/dev/null)" ]]; then
            echo "🧹 Removing old temp dir $dir"
            rm -rf "$dir"
            cleaned=$((cleaned + 1))
        fi
    done < <(find /tmp -maxdepth 1 -type d -name "chrome-*" 2>/dev/null | sort)

    if [[ $cleaned -eq 0 ]]; then
        echo "✅ Nothing to clean"
    else
        echo "✅ Cleaned $cleaned item(s)"
    fi
}

case "$MODE" in
    ps|inspect) report ;;
    json) json_out ;;
    clean) clean ;;
esac
