# agent-browser (Vercel Labs) — Setup Guide

## What

Rust CLI that gives AI agents fast, token-efficient browser control. Accessibility-tree snapshots with `@ref` element IDs. No Node.js required for the daemon. **Best-in-class for Chrome profile reuse** — loads your real Chrome cookies in 2.2s.

## 1. Install the binary (per machine, once)

```bash
# macOS (recommended)
brew install agent-browser

# Or via npm
npm install -g agent-browser

# Or via cargo
cargo install agent-browser
```

First-time setup — downloads Chrome for Testing:

```bash
agent-browser install
```

## 2. Profile Reuse — The Key Feature

agent-browser can load your real Chrome profile's cookies, localStorage, and extensions into its own browser session. Three modes:

### Mode A: `--profile` (read-only snapshot, recommended)

Copies your Chrome profile to a temp dir (never modifies original), launches Chrome for Testing with your cookies. **2.2s load time in smoke tests.**

```bash
# List available profiles
agent-browser profiles

# Use your default Chrome profile
agent-browser --profile Default open https://github.com

# Use a named profile
agent-browser --profile "Work" open https://app.example.com
```

What's copied: cookies, localStorage, extensions state (cache dirs excluded for speed).
What's NOT: passwords (encrypted), session data tied to App-Bound Encryption.

### Mode B: `--state` (saved JSON, portable)

Import auth state from a JSON file. Best for CI or cross-machine reuse.

```bash
# Save state from a running session
agent-browser state save ./my-auth.json

# Load in future sessions
agent-browser --state ./my-auth.json open https://app.example.com/dashboard
```

### Mode C: `--session-name` (auto-persistent, best for daily use)

Automatically saves/restores state across restarts. Sessions stored in `~/.agent-browser/sessions/`.

```bash
# First run: logs in, state auto-saves
agent-browser --session-name twitter open https://twitter.com

# Future runs: already logged in
agent-browser --session-name twitter open https://twitter.com
```

### Mode D: `--auto-connect` (from running Chrome)

Connect to Chrome launched with `--remote-debugging-port` + `--user-data-dir`. Requires Chrome to be started manually first.

```bash
# Terminal 1: launch Chrome with debug port (separate profile, NOT your default!)
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --remote-debugging-port=9222 \
  --user-data-dir=/tmp/agent-debug

# Terminal 2: connect and save state
agent-browser --auto-connect state save ./my-auth.json

# Later: use saved state
agent-browser --state ./my-auth.json open https://app.example.com
```

> ⚠️ **Chrome 136+ (current stable: v149):** `--remote-debugging-port` on the default profile is **blocked for security**. You MUST use `--user-data-dir` pointing to a non-default directory. This means Mode D gets a blank profile, not your real Chrome. For your real sessions, use **Mode A** (`--profile Default`) or **Chrome DevTools MCP + `--autoConnect`**.

### Encrypted state

```bash
export AGENT_BROWSER_ENCRYPTION_KEY=$(openssl rand -hex 32)
agent-browser --session-name secure-session open example.com
```

### State management

```bash
agent-browser state list              # all saved states
agent-browser state show <name>        # summary of cookies, domains
agent-browser state clean --older-than 7  # delete old states
```

## 3. Add the skill to your project (local, per-project)

agent-browser ships with its own SKILL.md in the repo:
https://github.com/vercel-labs/agent-browser/blob/main/skills/agent-browser/SKILL.md

### If installed via npm (local or global)

The skill is already in `node_modules/agent-browser/skills/agent-browser/`:

```bash
mkdir -p .pi/skills
ln -s $(pwd)/node_modules/agent-browser/skills/agent-browser .pi/skills/agent-browser
```

### If installed via brew or cargo

Clone just the skill (no full repo needed):

```bash
mkdir -p .pi/skills/agent-browser
curl -sL https://raw.githubusercontent.com/vercel-labs/agent-browser/main/skills/agent-browser/SKILL.md -o .pi/skills/agent-browser/SKILL.md
```

Done. Restart pi — the agent now has the agent-browser skill available in this project only.

## 4. Verify

```bash
agent-browser open https://example.com
agent-browser snapshot -i
agent-browser close
```

From pi, the agent will call these via `bash`.

## 5. Smoke Tests

Evaluated in our [testbed](../testbed/). Results: **6/6 ✅**.

```bash
cd testbed && bash agents/smoke_agent_browser.sh
```

| Test | Result | Detail |
|------|--------|--------|
| Launch + navigate | ✅ 771ms | Headless, example.com |
| Snapshot/elements | ✅ `@eN` refs | Compact a11y tree |
| **Profile reuse** | ✅ **2.2s** | Real GitHub cookies |
| State save/restore | ✅ | Cookie survived across sessions |
| Multi-tab | ✅ | `tab new/list` |
| Cookie read | ✅ | 6 cookies from profile |

## agent-browser vs rodney vs browser-use

| | agent-browser | rodney | browser-use |
|---|---|---|---|
| Install | `brew install agent-browser` | `uv tool install rodney` | `pip install 'browser-use[cli]'` |
| Daemon | Rust (no Node.js) | Go + rod | Python (socket-based) |
| Profile reuse | ✅ `--profile Default` (2.2s) | ❌ | ✅ `--profile "Default"` (28s) |
| State persistence | ✅ `--session-name` (auto) | cookies only | manual export/import |
| Page state | a11y tree + `@ref` (~50 tokens) | text/html extraction | `[N]` indices |
| Network interception | yes (`network route`) | no | no (CLI) |
| Batch mode | yes | no | no (CLI) |
| Semantic locators | `find role/text/label` | CSS selectors only | no (CLI) |
| Assertions | none | `exists`, `visible`, `count`, `assert` | none |
| Diff | `diff snapshot/screenshot` | no | no |
| PDF | yes | yes | no (CLI) |
| AI agent mode | no (CLI only) | no | ✅ `Agent(task, llm)` |
| Cloud browsers | no | no | ✅ `cloud connect` |

## Environment

| Variable | Default | Purpose |
|----------|---------|---------|
| `AGENT_BROWSER_PORT` | auto | Daemon port |
| `AGENT_BROWSER_PROFILE` | — | Chrome profile name (shorthand for `--profile`) |
| `AGENT_BROWSER_SESSION_NAME` | — | Session name (shorthand for `--session-name`) |
| `AGENT_BROWSER_ENCRYPTION_KEY` | — | AES-256-GCM key for state files |
| `AGENT_BROWSER_NO_AUTO_DIALOG` | `0` | Disable auto-accepting alert/confirm dialogs |

## Dashboard

When running, a debug dashboard is available at `http://localhost:4848`.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `agent-browser install` fails | Ensure ~200 MB free disk. Linux: `agent-browser install --with-deps` |
| Windows ARM64 | Broken as of 0.25.x — use x86 or Linux/macOS |
| `--profile` doesn't get my cookies | Chrome 136+ App-Bound Encryption blocks some cookie decryption in temp copy. Use `--session-name` for persistent state instead. |
| Port conflict | Set `AGENT_BROWSER_PORT` to a specific port |
| Chrome not found | Run `agent-browser install` again |
| Skill not loading | Ensure `.pi/skills/agent-browser/SKILL.md` exists. Restart pi. |
| State files contain tokens | Add `*.json` from `~/.agent-browser/sessions/` to `.gitignore`. Delete when no longer needed. |
