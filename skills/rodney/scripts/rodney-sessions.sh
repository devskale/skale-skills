#!/usr/bin/env bash
# rodney-sessions — manage named rodney sessions (--session <name>).
#
# The binary manages ONE session per invocation; this script is the multi-
# session view: list every named session with liveness/pages/size, stop them
# all, or clean up dead ones (crash leftovers: chrome-data dirs, orphan PIDs).
#
# Usage:
#   rodney-sessions                # list: name, pid, status, pages, age, size
#   rodney-sessions --stop-all     # stop every RUNNING named session (graceful)
#   rodney-sessions --clean [--age 24h]
#                                  # remove DEAD session dirs (all when --age given)
#   rodney-sessions --json         # machine-readable: [{name,pid,status,pages,age_s,size_mb}]
#
# Session dirs live in ~/.rodney-sessions/<name>/ (state.json + chrome-data).
# A session is RUNNING when its chrome_pid is alive, DEAD otherwise.
set -uo pipefail

SESSIONS_DIR="${RODNEY_SESSIONS_DIR:-$HOME/.rodney-sessions}"
MODE="list"; AGE_FILTER=""
for arg in "$@"; do
    case "$arg" in
        --stop-all) MODE="stop-all" ;;
        --clean)    MODE="clean" ;;
        --json)     MODE="json" ;;
        --age)      : ;; # value handled below via lookahead
        *)          [ -n "${PREV_AGE:-}" ] || AGE_FILTER=""
            case "${PREV_AGE:-}" in --age) AGE_FILTER="$arg" ;; esac ;;
    esac
    PREV_AGE="$arg"
done

json_field() { # file key
    python3 -c "
import json,sys
try: print(json.load(open(sys.argv[1])).get(sys.argv[2],''))
except Exception: pass" "$1" "$2" 2>/dev/null
}

pid_alive() { [ -n "$1" ] && [ "$1" != "?" ] && ps -p "$1" >/dev/null 2>&1; }

# collect: fills SESSIONS as "name|pid|status|pages|age_s|size_mb" lines
collect() {
    [ -d "$SESSIONS_DIR" ] || return 0
    for d in "$SESSIONS_DIR"/*/; do
        [ -d "$d" ] || continue
        name="$(basename "$d")"
        pid="$(json_field "$d/state.json" chrome_pid)"; pid="${pid:-?}"
        if pid_alive "$pid"; then status="RUNNING"; else status="dead"; fi
        pages="$(json_field "$d/state.json" active_page)"; pages="${pages:--}"
        # age of the state file in seconds (proxy for last activity)
        age_s=0
        if [ -f "$d/state.json" ]; then
            now=$(date +%s); mtime=$(stat -f %m "$d/state.json" 2>/dev/null || stat -c %Y "$d/state.json" 2>/dev/null || echo "$now")
            age_s=$((now - mtime))
        fi
        size_mb=$(du -sm "$d" 2>/dev/null | cut -f1)
        echo "$name|$pid|$status|$pages|$age_s|$size_mb"
    done
}

parse_age() { # "24h" → seconds; "45m"; "30s"; bare number = hours
    local a="$1"
    case "$a" in
        *h) echo "${a%h} * 3600" | bc 2>/dev/null || python3 -c "print(int('${a%h}')*3600)" ;;
        *m) python3 -c "print(int('${a%m}')*60)" ;;
        *s) python3 -c "print(int('${a%s}'))" ;;
        *)  python3 -c "print(int('$a')*3600)" ;;
    esac
}

case "$MODE" in
list|json)
    out=$(collect)
    if [ "$MODE" = "json" ]; then
        echo "$out" | python3 -c '
import sys, json
rows=[]
for line in sys.stdin:
    p=line.rstrip("\n").split("|")
    if len(p)==6:
        rows.append({"name":p[0],"pid":p[1],"status":p[2],"pages":p[3],"age_s":int(p[4]),"size_mb":int(p[5])})
print(json.dumps(rows, indent=2))'
    else
        if [ -z "$out" ]; then echo "no named sessions ($SESSIONS_DIR)"; exit 0; fi
        printf '%-20s %-8s %-8s %-6s %-10s %s\n' SESSION PID STATUS PAGES AGE SIZE_MB
        echo "$out" | while IFS='|' read -r name pid status pages age_s size_mb; do
            age_h=$(python3 -c "a=$age_s; print(f'{a//3600}h{(a%3600)//60}m' if a>=3600 else f'{a//60}m' if a>=60 else f'{a}s')")
            printf '%-20s %-8s %-8s %-6s %-10s %sM\n' "$name" "$pid" "$status" "$pages" "$age_h" "$size_mb"
        done
    fi
    ;;
stop-all)
    stopped=0
    collect | while IFS='|' read -r name pid status pages age_s size_mb; do
        if [ "$status" = "RUNNING" ]; then
            echo "stopping $name (pid $pid)..."
            rodney --session "$name" stop >/dev/null 2>&1 && echo "  ✓ $name stopped"
        fi
    done
    echo "done (running sessions stopped; dead dirs untouched — use --clean)"
    ;;
clean)
    if [ ! -d "$SESSIONS_DIR" ]; then echo "no sessions dir"; exit 0; fi
    removed=0
    while IFS='|' read -r name pid status pages age_s size_mb; do
        [ -z "$name" ] && continue
        if [ "$status" = "RUNNING" ]; then
            echo "  · $name: RUNNING — skipped (stop first)"
            continue
        fi
        if [ -n "$AGE_FILTER" ]; then
            limit=$(parse_age "$AGE_FILTER")
            if [ "$age_s" -lt "$limit" ]; then
                echo "  · $name: only ${age_s}s old (< $AGE_FILTER) — skipped"
                continue
            fi
        fi
        # retry removal: chrome may still be writing (observed in the wild)
        for i in 1 2 3; do rm -rf "$SESSIONS_DIR/$name" 2>/dev/null && break; sleep 1; done
        if [ -d "$SESSIONS_DIR/$name" ]; then echo "  ✗ $name: removal failed (still writing?)"; else
            echo "  ✗ removed $name (${size_mb}M freed)" | sed 's/✗/✓/'
            removed=$((removed+1))
        fi
    done < <(collect)
    echo "clean done"
    ;;
esac
