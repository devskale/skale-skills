# Rodney — Setup Guide

## What

Headless Chrome automation from the CLI. Scrape, screenshot, fill forms, export PDFs, accessibility audits, smoke tests.

## 1. Install rodney (per machine, once)

```bash
uv tool install rodney
```

Requires Chrome or Chromium.

## 2. Add the skill to your project

```bash
mkdir -p .pi/skills
git clone --depth 1 --filter=blob:none --sparse https://github.com/devskale/skale-skills.git /tmp/skale-skills
cd /tmp/skale-skills && git sparse-checkout set skills/rodney
cp -r skills/rodney .pi/skills/rodney
rm -rf /tmp/skale-skills
```

## 3. Verify

```bash
rodney start
rodney open https://example.com
rodney waitstable
rodney screenshot page.png
rodney stop
```

Done. Restart pi — the agent now has the rodney skill available.

## Gotchas

### MCP servers are lazy-loaded

The pi-mcp-adapter connects MCP servers **lazily by default** — the rodney server will **not** be running after a restart. It only starts when you first call one of its tools. This is expected, not a bug.

- `mcp({ })` may show the server as not connected. That's fine.
- Just call the tool you need directly: `mcp({ tool: "rodney_open", args: '{"url": "https://example.com"}' })` — the server connects on demand.
- Idle servers auto-disconnect after 10 minutes and reconnect on next use.


