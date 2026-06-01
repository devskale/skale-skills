# agent-browser (Vercel Labs) — Setup Guide

## What

Rust CLI that gives AI agents fast, token-efficient browser control. Accessibility-tree snapshots with `@ref` element IDs. No Node.js required for the daemon.

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

## 2. Add the skill to your project (local, per-project)

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

## 3. Verify

```bash
agent-browser open https://example.com
agent-browser snapshot -i
agent-browser close
```

From pi, the agent will call these via `bash`.

## agent-browser vs rodney

| | agent-browser | rodney |
|---|---|---|
| Install | `brew install agent-browser` | `uv tool install rodney` |
| Daemon | Rust (no Node.js) | Go + rod |
| Page state | a11y tree + `@ref` (~50 tokens) | text/html extraction |
| Network interception | yes (`network route`) | no |
| Batch mode | yes | no |
| Semantic locators | `find role/text/label` | CSS selectors only |
| Assertions | none | `exists`, `visible`, `count`, `assert` |
| Diff | `diff snapshot/screenshot` | no |
| PDF | yes | yes |
| State persistence | `state save/load` | cookies only via session |

## Environment

| Variable | Default | Purpose |
|----------|---------|---------|
| `AGENT_BROWSER_PORT` | auto | Daemon port |
| `AGENT_BROWSER_NO_AUTO_DIALOG` | `0` | Disable auto-accepting alert/confirm dialogs |

## Dashboard

When running, a debug dashboard is available at `http://localhost:4848`.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `agent-browser install` fails | Ensure ~200 MB free disk. Linux: `agent-browser install --with-deps` |
| Windows ARM64 | Broken as of 0.25.x — use x86 or Linux/macOS |
| `--profile` loses active page | Known issue, avoid `--profile` for now |
| Port conflict | Set `AGENT_BROWSER_PORT` to a specific port |
| Chrome not found | Run `agent-browser install` again |
| Skill not loading | Ensure `.pi/skills/agent-browser/SKILL.md` exists. Restart pi. |
