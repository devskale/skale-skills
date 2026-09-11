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
/heartbeat 10m --once       → one-shot: fire once after 10m, then stop
/heartbeat message <text>   → change message live
/heartbeat time <duration>  → change interval live (30s | 5m | 2h | 1d; bare = seconds)
/heartbeat pause            → freeze the countdown (state kept)
/heartbeat resume           → continue (one-shots keep their remaining delay)
/heartbeat status           → show status
/heartbeat off              → stop
```

Durations accept `s`, `m`, `h`, `d` (bare number = seconds).

### ESC: pause, then stop

While a heartbeat is active **and** pi is idle:

| Press | Effect |
|-------|--------|
| lone **ESC** | **pause** — instant side effect; the press still passes through to pi |
| **ESC … ESC** (0.5–1.5s apart) | **stop** — a deliberate *second* ESC that is *not* a double-ESC |
| **ESC ESC** fast (<0.5s) | untouched — pi's native double-ESC still opens the **chat tree** |

Design notes:

- pi's native double-ESC (chat tree) needs *both* presses to reach the editor,
  so the heartbeat **never consumes the first ESC** — the tree keeps working
  even while a heartbeat runs.
- Only the **stop press is consumed** — pi ignores a slow second ESC (its tree
  window has expired), so it's unambiguously ours.
- While paused you can edit message/interval (`/heartbeat message`,
  `/heartbeat time`); **resume** via `/heartbeat resume` (ESC never resumes).
- pi mid-turn: ESC keeps its native abort behavior; no heartbeat → untouched.
- Edge: opening the chat tree while a heartbeat is *running* pauses it as a
  side effect — visible in the status line, undone with `/heartbeat resume`.

`--once` cannot be combined with `--limit`. A beat that comes due while pi is
mid-turn is shifted (capped at 5 min), not consumed — it fires when pi is idle.

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
- **Idle-only delivery (default):** a beat that comes due while pi is mid-turn
  (busy) is **shifted** by one interval (capped at 5 minutes max) and re-checked
  — it is **not consumed** (the count isn't bumped), so a long agent run just
  pushes the beat out instead of stacking a burst of reminders mid-work. The
  beat fires only when pi is idle.
- **`/heartbeat` with no args prints help** (instead of starting a default
  heartbeat).
- All `ctx.ui` calls are wrapped so a missing/stale UI context degrades
  gracefully instead of crashing.

## Requirements

- pi ≥ 0.79 (`registerCommand`, `registerTool`, `ctx.ui.setStatus`)
- Interactive TUI or RPC mode for the status line (`hasUI`).
