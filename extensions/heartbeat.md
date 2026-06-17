# heartbeat

Recurring reminder that fires every N seconds. Sends a follow-up message to the
agent on each tick, and shows a countdown progress bar in the status line.

Useful for staying focused during long sessions — if you "fall asleep" the agent
gets nudged back into action with your custom message.

## Commands

```
/heartbeat 30s              → start with 30s interval (default message)
/heartbeat "Focus on X"     → start with custom message (60s)
/heartbeat 30s "msg"        → interval + custom message
/heartbeat -f file.md       → start, message read from file
/heartbeat -f file.md --limit 100  → limit lines read from file
/heartbeat status           → show status
/heartbeat off              → stop
```

### Status line

While active, the footer shows a countdown:

```
⏰ 42s [██████░░░░] #3
```

- `42s` — seconds until the next reminder
- `[██████░░░░]` — progress bar (fills as the interval elapses)
- `#3` — number of reminders sent so far

## Install

Add to pi settings.

**Global** (`~/.pi/agent/settings.json`) — available in every project:

```json
{
  "extensions": ["~/.pi/agent/extensions/skale-skills/extensions/heartbeat.ts"]
}
```

**Project** (`.pi/settings.json`) — only this repo:

```json
{
  "extensions": [".pi/extensions/heartbeat.ts"]
}
```

> If you cloned `skale-skills` somewhere else, point at the real path, e.g.
> `~/code/agents/skills/skale-skills/extensions/heartbeat.ts`.

**Quick test** (no settings edit, loads for one session):

```bash
pi -e ./extensions/heartbeat.ts
```

After editing settings or the file, run `/reload` inside pi (or restart pi).

## How the message is delivered

Each tick sends a follow-up user message:

```
⏰ **Heartbeat #3**

<your message>
```

The default message is `Time to check in — what are you working on?`. Override it
inline (`/heartbeat "msg"`) or from a file (`/heartbeat -f reminders.md`).

## Requirements

- pi ≥ 0.79 (uses `ExtensionAPI.registerCommand` + `ctx.ui.setStatus`)
- Interactive TUI mode (`/heartbeat` needs the status line; headless modes print
  a warning instead of starting)

## Notes

- The timer is reset on `/reload`, session switch (`/tree`), and session start.
  It does **not** survive a pi restart — restart it manually after reopening pi.
- State lives in the extension module, not the session. Branching/forking does
  not carry the running heartbeat; run `/heartbeat 30s` again in the new branch.
