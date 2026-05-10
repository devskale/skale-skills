# Chrome DevTools MCP — Setup Guide

## What

Inspect, debug, and automate a live Chrome browser from Pi via MCP. Screenshots, network inspection, performance traces, DOM snapshots, and more.

## Prerequisites

- Chrome Beta installed: https://www.google.com/chrome/beta/
- `pi-mcp-adapter` installed: `pi install npm:pi-mcp-adapter`

## Add to a Pi Project

Create `.mcp.json` in your project root:

```json
{
  "mcpServers": {
    "chrome-devtools": {
      "command": "npx",
      "args": [
        "-y",
        "chrome-devtools-mcp@latest",
        "--autoConnect",
        "--channel=beta"
      ]
    }
  }
}
```

Done. Restart pi — the server is lazy, it connects only when you use its tools.

## Verify

```
mcp({ connect: "chrome-devtools" })
```

You should see ~29 tools available.

## Notes

- **Start Chrome Beta** before using the tools — the server connects to the running browser
- Config goes in `.mcp.json` (project) or `~/.config/mcp/mcp.json` (global), **not** in `.pi/settings.json`
- Add `--headless` for headless mode, `--slim` for fewer tools (faster startup)
