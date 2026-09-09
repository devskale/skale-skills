#!/usr/bin/env bash
# chrome-autoallow — auto-click Chrome's "Allow remote debugging?" consent dialog.
#
# Lifecycle-bound to the chrome-devtools MCP server (no permanent daemon):
#   mcp.json -> chrome-autoallow run <server args...>
#
#   run    arm the watcher, run `npx chrome-devtools-mcp <args...>` as child,
#          disarm on exit (trap) — re-armed automatically on every MCP spawn.
#   arm    start the watcher in the background
#   disarm stop it
#   status is it armed? recent clicks?
#
# Watcher self-terminates when ANY of these hit:
#   1. parent process dies                (run mode only: the wrapper; checked
#                                          every ~3.5s. Standalone `arm` has no
#                                          parent binding and relies on 2-5.)
#   2. idle: no dialog seen/clicked for   CHROME_AUTOALLOW_IDLE_SECS (default 600s;
#      the timer resets on every click)   a mid-session reconnect within the
#                                          window is still caught
#   3. Chrome is not running for 30s      (nothing to watch)
#   4. hard deadline                      CHROME_AUTOALLOW_MAXSECS (default 6h)
#   5. `disarm`
# Every stop reason is logged. It ONLY presses "Allow" inside a sheet titled
# "Allow remote debugging?" — never any other dialog.
#
# Env overrides:
#   CHROME_AUTOALLOW_PROCESS  Chrome process name (default: derived from
#                             --channel arg, beta -> "Google Chrome Beta")
#   CHROME_AUTOALLOW_TITLE    dialog title  (default: "Allow remote debugging?")
#   CHROME_AUTOALLOW_BUTTON   button label  (default: "Allow")
#   CHROME_AUTOALLOW_MAXSECS  hard deadline (default: 21600)
#   CHROME_AUTOALLOW_IDLE_SECS  idle self-stop, timer resets on click (default: 600)

set -u

PIDFILE="${TMPDIR:-/tmp}/chrome-autoallow.pid"
LOGFILE="${TMPDIR:-/tmp}/chrome-autoallow.log"

process_name() {
  if [ -n "${CHROME_AUTOALLOW_PROCESS:-}" ]; then
    echo "$CHROME_AUTOALLOW_PROCESS"
    return
  fi
  case " $* " in
    *" --channel=stable "*|*" --channel stable "*) echo "Google Chrome" ;;
    *" --channel=canary "*|*" --channel canary "*) echo "Google Chrome Canary" ;;
    *" --channel=dev "*|*" --channel dev "*) echo "Google Chrome Dev" ;;
    *) echo "Google Chrome Beta" ;;
  esac
}

watcher_alive() {
  [ -f "$PIDFILE" ] || return 1
  local pid
  pid="$(cat "$PIDFILE" 2>/dev/null)" || return 1
  [ -n "$pid" ] || return 1
  kill -0 "$pid" 2>/dev/null || return 1
  # pid-recycling guard: the pid must actually be an osascript watcher
  ps -p "$pid" -o comm= 2>/dev/null | grep -q "osascript"
}

arm() {
  # run mode (parent bound): always spawn a fresh watcher so the
  # wrapper<->watcher binding stays 1:1; standalone arm is idempotent.
  if [ -z "${CHROME_AUTOALLOW_PARENT_PID:-}" ] && watcher_alive; then
    echo "already armed (pid $(cat "$PIDFILE"))"
    return 0
  fi
  local proc title button maxsecs idlesecs parent
  parent="${CHROME_AUTOALLOW_PARENT_PID:-}"
  proc="${CHROME_AUTOALLOW_PROCESS:-$(process_name "$@")}"
  title="${CHROME_AUTOALLOW_TITLE:-Allow remote debugging?}"
  button="${CHROME_AUTOALLOW_BUTTON:-Allow}"
  maxsecs="${CHROME_AUTOALLOW_MAXSECS:-21600}"
  idlesecs="${CHROME_AUTOALLOW_IDLE_SECS:-600}"
  osascript - "$parent" "$proc" "$title" "$button" "$maxsecs" "$LOGFILE" "$idlesecs" >>"$LOGFILE" 2>&1 <<'APPLESCRIPT' &
on run argv
  set parentPID to item 1 of argv
  set procName to item 2 of argv
  set dialogTitle to item 3 of argv
  set allowLabel to item 4 of argv
  set maxSecs to (item 5 of argv) as integer
  set logFile to item 6 of argv
  set idleSecs to (item 7 of argv) as integer
  set endEpoch to ((do shell script "date +%s") as integer) + maxSecs
  set lastEvent to (do shell script "date +%s") as integer
  set stopReason to "idle timeout (" & idleSecs & "s without dialog)"
  set chromeAbsentSince to 0
  set iter to 0
  set totalClicks to 0
  repeat
    set nowEpoch to (do shell script "date +%s") as integer
    if iter mod 5 is 0 then
      if parentPID is not "" then
        try
          do shell script "ps -p " & parentPID & " > /dev/null 2>&1"
        on error
          set stopReason to "parent process gone"
          exit repeat
        end try
      end if
      if nowEpoch > endEpoch then
        set stopReason to "hard deadline reached"
        exit repeat
      end if
    end if
    if (nowEpoch - lastEvent) > idleSecs then exit repeat
    set chromeRunning to true
    try
      tell application "System Events" to set chromeRunning to (exists process procName)
    end try
    if chromeRunning then
      set chromeAbsentSince to 0
    else
      if chromeAbsentSince is 0 then set chromeAbsentSince to nowEpoch
      if (nowEpoch - chromeAbsentSince) > 30 then
        set stopReason to "Chrome not running for 30s"
        exit repeat
      end if
    end if
    try
      tell application "System Events"
        tell process procName
          repeat with w in windows
            set dlgSheets to (sheets of w whose name is dialogTitle)
            repeat with s in dlgSheets
              set els to entire contents of s
              repeat with el in els
                try
                  if (role of el is "AXButton") and (name of el is allowLabel) then
                    click el
                    set totalClicks to totalClicks + 1
                    set lastEvent to nowEpoch
                    set stamp to do shell script "date '+%Y-%m-%dT%H:%M:%S'"
                    do shell script "echo " & quoted form of (stamp & " auto-allowed (total " & totalClicks & ")") & " >> " & quoted form of logFile
                    exit repeat
                  end if
                end try
              end repeat
            end repeat
          end repeat
        end tell
      end tell
    end try
    set iter to iter + 1
    delay 0.7
  end repeat
  set stamp to do shell script "date '+%Y-%m-%dT%H:%M:%S'"
  do shell script "echo " & quoted form of (stamp & " watcher stopped: " & stopReason) & " >> " & quoted form of logFile
end run
APPLESCRIPT
  local wpid=$!
  echo "$wpid" >"$PIDFILE"
  echo "armed (watcher pid $wpid, process '$proc', idle-stop ${idlesecs}s, deadline ${maxsecs}s)"
}

disarm() {
  if watcher_alive; then
    kill "$(cat "$PIDFILE")" 2>/dev/null
    echo "disarmed (pid $(cat "$PIDFILE"))"
  else
    echo "not armed"
  fi
  rm -f "$PIDFILE"
}

status() {
  if watcher_alive; then
    echo "armed (pid $(cat "$PIDFILE"))"
  else
    echo "not armed"
    rm -f "$PIDFILE"
  fi
  if [ -f "$LOGFILE" ]; then
    tail -5 "$LOGFILE"
  fi
  return 0
}

cmd="${1:-}"
case "$cmd" in
  run)
    shift
    CHROME_AUTOALLOW_PARENT_PID="$$"
    export CHROME_AUTOALLOW_PARENT_PID
    arm "$@"
    SERVER_PID=""
    cleanup() {
      [ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null
      disarm >/dev/null 2>&1
    }
    trap cleanup EXIT
    trap 'exit 0' INT TERM
    if command -v npx >/dev/null 2>&1; then
      # background + wait so traps fire immediately on TERM (a foreground
      # child would defer them); <&0 keeps MCP stdio intact (bash would
      # otherwise point a background job's stdin at /dev/null)
      npx -y chrome-devtools-mcp@latest "$@" <&0 &
      SERVER_PID=$!
      wait "$SERVER_PID"
    else
      echo "chrome-autoallow: npx not found on PATH" >&2
      exit 127
    fi
    ;;
  arm) shift; arm "$@" ;;
  disarm) disarm ;;
  status) status ;;
  *)
    echo "usage: chrome-autoallow run|arm|disarm|status [args...]"
    echo "  run <server args...>  arm watcher + run chrome-devtools-mcp (MCP entrypoint)"
    exit 1
    ;;
esac
