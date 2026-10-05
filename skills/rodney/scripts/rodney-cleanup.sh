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
#
# Self-decompose (2026-10-05): also recognizes the ROD-family browsers beyond rodney's
# own sessions — go-rod's default temp profile dirs ($TMPDIR/rod/user-data/<hex>, used
# by launcher.New() without UserDataDir — e.g. rodney's own test suite) and rodney's
# test dirs (/tmp/rodney-test-*). A leaked test Chromium is as much rodney debris as
# a leaked session — same binary (~/.cache/rod/browser), same cleanup.

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

# Locate state files: global ~/.rodney/state.json, any local ./.rodney/state.json
# (rodney --local sessions), and every named session ~/.rodney-sessions/*/state.json
# (rodney --session <name>). Named sessions are managed in depth by
# rodney-sessions.sh; here they join the inspect/clean view so no session
# Chrome is invisible to the cleanup.
STATE_FILES=()
[[ -f "$HOME/.rodney/state.json" ]] && STATE_FILES+=("$HOME/.rodney/state.json")
if [[ -f "./.rodney/state.json" ]] && [[ "./.rodney/state.json" != "$HOME/.rodney/state.json" ]]; then
    STATE_FILES+=("./.rodney/state.json")
fi
for _sd in "$HOME"/.rodney-sessions/*/state.json; do
    [[ -f "$_sd" ]] && STATE_FILES+=("$_sd")
done

# A helper to read a JSON field with or without jq.
json_field() { # file key
    if command -v jq &>/dev/null; then
        jq -r --arg k "$2" '.[$k] // empty' "$1" 2>/dev/null || echo ""
    else
        grep -o '"'"$2"'":[^,}]*' "$1" | head -1 | sed -E 's/^[^:]*:[[:space:]]*"?//; s/"$//' || echo ""
    fi
}

# Collect rodney Chromium PIDs. Two signatures:
#   1. user-data-dir points at a .rodney dir (rodney sessions)
#   2. the binary is rod-managed (~/.cache/rod/browser) — catches go-rod default
#      temp profiles ($TMPDIR/rod/user-data/<hex>) from launcher.New() without
#      UserDataDir, e.g. rodney's own test suite. Named sessions and session
#      state files are NEVER orphans (checked via managed PIDs below).
rod_pids() {
    ps aux | grep -E 'user-data-dir=.*\.rodney|\.cache/rod/browser' | grep -v grep | awk '{print $2}'
}

# Same as rod_pids but keeps only NON-managed PIDs (not referenced by any live
# state file) — the actual orphan set.
rodney_pids() {
    local managed
    managed="$(managed_pids)"
    local pid
    for pid in $(rod_pids); do
        if [[ -z "$managed" ]] || ! grep -qw "$pid" <<<"$managed"; then
            echo "$pid"
        fi
    done
}

# All PIDs referenced as chrome_pid by a state file whose Chrome is ALIVE.
managed_pids() {
    local sf pid
    for sf in "${STATE_FILES[@]:-}"; do
        pid=$(json_field "$sf" chrome_pid)
        if [[ -n "$pid" ]] && ps -p "$pid" &>/dev/null; then
            echo "$pid"
        fi
    done
}

# ── Inspect / ps / json: report only ─────────────────────────────────
# Collects state into globals (managed_pid, total, orphans, json_out) so the
# json mode can emit only JSON without a human banner.
collect() {
    managed_pid="" total=0 orphans=0

    # First live managed PID (for the json summary; full set via managed_pids)
    if [[ ${#STATE_FILES[@]} -gt 0 ]]; then
        local sf pid
        for sf in "${STATE_FILES[@]}"; do
            pid=$(json_field "$sf" chrome_pid)
            if [[ -n "$pid" ]] && ps -p "$pid" &>/dev/null; then
                managed_pid="$pid"
            fi
        done
    fi

    # rodney_pids already filters to non-managed; count all rod-family browsers
    local pid
    for pid in $(rod_pids); do
        total=$((total + 1))
    done
    for pid in $(rodney_pids); do
        orphans=$((orphans + 1))
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
    pids=$(rod_pids || true)
    echo ""
    echo "--- rod-family Chromium processes (.rodney sessions + rod-managed binary) ---"
    if [[ -z "$pids" ]]; then
        echo "(none found)"
    else
        local managed_set
        managed_set="$(managed_pids)"
        for pid in $pids; do
            local status="[ORPHAN]"
            if [[ -n "$managed_set" ]] && grep -qw "$pid" <<<"$managed_set"; then
                status="[MANAGED]"
            fi
            local dir
            dir=$(ps -p "$pid" -o command= 2>/dev/null | grep -oE 'user-data-dir=[^ ]*' | cut -d= -f2 || echo "?")
            echo "  PID $pid $status  $dir"
        done
    fi

    # Leaked rod temp profiles (go-rod default dirs, no live process using them)
    local tmp_leak
    tmp_leak=$(stale_rod_temp_dirs 0)
    if [[ -n "$tmp_leak" ]]; then
        local n_leak
        n_leak=$(wc -l <<<"$tmp_leak" | tr -d ' ')
        echo ""
        echo "--- stale rod temp profile dirs ($n_leak, no live process) ---"
        du -sh ${TMPDIR%/}/rod/user-data 2>/dev/null | awk '{print "  " $0}'
    fi
    echo ""
    echo "Total: $total rod-family Chromium process(es); $orphans orphan(s)"
}

# stale_rod_temp_dirs <min_age_seconds> — dirs under $TMPDIR/rod/user-data and
# /tmp/rodney-test-* whose user-data-dir is NOT used by any live process.
# Age gate: 0 = any age (default), >0 = only dirs older than N seconds.
stale_rod_temp_dirs() {
    local min_age="${1:-0}" d dir pid used
    for d in "${TMPDIR%/}/rod/user-data"/* "$TMPDIR"/rodney-test-* /tmp/rodney-test-*; do
        [[ -d "$d" ]] || continue
        # rodney-test-* dirs carry chrome-data + chrome.pid; rod default dirs are
        # the profile themselves
        dir="$d"
        [[ -d "$d/chrome-data" ]] && dir="$d/chrome-data"
        used=""
        for pid in $(rod_pids); do
            if ps -p "$pid" -o command= 2>/dev/null | grep -q -- "user-data-dir=$dir"; then
                used=1; break
            fi
        done
        [[ -n "$used" ]] && continue
        if [[ "$min_age" -gt 0 ]]; then
            local now mtime
            now=$(date +%s)
            mtime=$(stat -f %m "$d" 2>/dev/null || stat -c %Y "$d" 2>/dev/null || echo "$now")
            (( now - mtime < min_age )) && continue
        fi
        echo "$d"
    done
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

    # 2. Kill orphan rod-family Chromium processes (rod-managed binary, not
    #    referenced by any live session state). rodney_pids already filters.
    for pid in $(rodney_pids); do
        echo "🧹 Killing orphan rod-family Chromium PID $pid"
        kill "$pid" 2>/dev/null || true
        cleaned=$((cleaned + 1))
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

    # 4. Sweep stale rod temp profiles: go-rod default dirs ($TMPDIR/rod/user-data/*)
    #    and rodney test dirs (rodney-test-*), unused by any live process, older
    #    than 1h (a just-interrupted test run may still restart its browser).
    while IFS= read -r dir; do
        [[ -z "$dir" ]] && continue
        echo "🧹 Removing stale rod temp profile $dir"
        rm -rf "$dir"
        cleaned=$((cleaned + 1))
    done < <(stale_rod_temp_dirs 3600)

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
