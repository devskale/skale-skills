# heartbeat

Recurring reminder that fires every N seconds. Sends a follow-up message to the
agent on each tick, shows a countdown progress bar in the status line, and is
**controllable by both the human (slash command) and the agent (tool)**.

Useful for staying focused during long sessions, periodic nudges, or letting the
agent re-pace itself while you're away.

## Two control surfaces

| Who | How |
|-----|-----|
| Human | `/heartbeat ...` slash command |
| Agent | `heartbeat` tool (the LLM can start/stop/tune it) |

Both share the same logic, so anything you can type, the agent can do too.

## Commands

```
/heartbeat 30s              → start with 30s interval (default message)
/heartbeat 5m               → start with 5m interval
/heartbeat "Focus on X"     → start with custom message (60s)
/heartbeat 30s "msg"        → interval + custom message
/heartbeat -f file.md       → start, message read from file (--lines N caps it)
/heartbeat 30s --limit 20   → stop after 20 heartbeats (--limit 0 = forever, default)
/heartbeat message <text>   → change message live
/heartbeat time <duration>  → change interval live (30s | 5m | 2h | 1d; bare = seconds)
/heartbeat status           → show status
/heartbeat off              → stop
```

Durations accept `s`, `m`, `h`, `d` (bare number = seconds).

### Status line

While active, the footer shows a countdown:

```
⏰ 42s [██████░░░░] #3
```

- `42s` — seconds until the next reminder
- `[██████░░░░]` — progress bar (fills as the interval elapses)
- `#3` — number of reminders sent so far

## Agent tool

The agent gets a `heartbeat` tool with `action`: `start | status | stop | message | time`,
plus `message`, `duration`, `maxCount`, `file`, `lines`. Example prompts that
trigger it:

- "remind me every 5 minutes to check the build"
- "ping me every 30s while I wait for the deploy"
- "speed up the heartbeat to every 10s"

The tool result includes the full state snapshot in `details`, so forking /
branching keeps the correct state.

## Install

Add to pi settings.

**Global** (`~/.pi/agent/settings.json`) — available in every project:

```json
{
  "extensions": ["~/code/agents/skills/skale-skills/extensions/heartbeat.ts"]
}
```

**Project** (`.pi/settings.json`) — only this repo:

```json
{
  "extensions": [".pi/extensions/heartbeat.ts"]
}
```

> If you cloned `skale-skills` somewhere else, point at the real path.

**Quick test** (no settings edit, loads for one session):

```bash
pi -e ./extensions/heartbeat.ts
```

After editing settings or the file, run `/reload` inside pi (or restart pi).

## Robustness notes

- Timers are stale-ctx safe — no crashes on reload / branch switch / compaction.
- Config (message, interval, maxCount) is persisted via `appendEntry` and
  restored on `session_start` / `session_tree` / `session_compact`. The timer
  itself is not auto-restarted (it is process-global); re-run `/heartbeat` to
  resume.
- All `ctx.ui` calls are wrapped so a missing/stale UI context degrades
  gracefully instead of crashing.

## Requirements

- pi ≥ 0.79 (`registerCommand`, `registerTool`, `ctx.ui.setStatus`)
- Interactive TUI or RPC mode for the status line (`hasUI`).
