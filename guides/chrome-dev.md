# Chrome DevTools MCP for Pi

Set up the official `chrome-devtools-mcp` server so Pi can inspect, debug, and automate a live Chrome browser via MCP.

> **Always use `pnpm` over `npm` or `yarn` for all Node.js package operations.**

## Prerequisites

- Node.js v20.19+
- `pi-mcp-adapter` installed globally (`pi install npm:pi-mcp-adapter`)

## 1. Install Chrome Beta

Chrome Beta is required for the `--channel=beta` flag which auto-discovers the browser.

Download from: https://www.google.com/chrome/beta/

After installing, enable remote debugging:

1. Open Chrome Beta
2. Navigate to `chrome://inspect/#remote-debugging`
3. Ensure **Discover network targets** is checked

## 2. Configure MCP Server

`pi-mcp-adapter` reads MCP server configs from `.mcp.json` (project-level) or `~/.config/mcp/mcp.json` (global). **Do NOT put `mcpServers` in `.pi/settings.json`** — the adapter does not read from there.

Create `.mcp.json` in the project root:

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

- `-y` — auto-confirm npx install (required by `pi-mcp-adapter`)
- `--autoConnect` — automatically connects to a running Chrome instance
- `--channel=beta` — targets Chrome Beta instead of stable

### Config file precedence

| File | Scope |
|------|-------|
| `~/.config/mcp/mcp.json` | User-global shared |
| `~/.pi/agent/mcp.json` | Pi global override |
| `.mcp.json` | Project-local shared |
| `.pi/mcp.json` | Pi project override |

## 3. Restart Pi

Servers are **lazy by default** — they won't connect until you actually use one of their tools. Pi will detect the server on startup but won't spawn it until needed.

## Verify

In Pi, trigger a connection:

```
mcp({ connect: "chrome-devtools" })
```

You should see 29 tools: screenshots, network inspection, performance traces, DOM snapshots, and more.

## Usage Tips

- **Start Chrome Beta** before using the tools — the server connects to the running browser.
- Run with `--headless` in the args for headless mode (no visible window).
- Add `--slim` for a reduced set of basic browser tools (faster startup).
