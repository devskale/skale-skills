# Chrome DevTools MCP — Setup Guide

## What

Control a live Chrome browser from Pi via MCP. Screenshots, DOM snapshots, network inspection, performance traces, JavaScript console, and more — all through your real Chrome with cookies and logins intact.

**Best for:** Reusing your authenticated Chrome session without a separate browser profile.

## Why Chrome DevTools MCP?

| Advantage | Detail |
|-----------|--------|
| **Real session reuse** | Connects to your running Chrome — all cookies, logins, extensions work |
| **No `--remote-debugging-port` hack** | Uses `--autoConnect` (Chrome 144+) via the `chrome://inspect` toggle, sidestepping the Chrome 136+ port restriction |
| **29+ tools** | Navigate, click, screenshot, network logs, JS console, DOM queries, performance traces |
| **Zero config in Chrome** | Toggle remote debugging once in `chrome://inspect/#remote-debugging`; click **Allow** when the agent connects |
| **Lazy-loaded** | MCP server only starts when you use it, auto-disconnects when idle |

## Prerequisites

| Requirement | Install |
|-------------|---------|
| Chrome 144+ (Beta *or* Stable) | https://www.google.com/chrome/ |
| `pi-mcp-adapter` | `pi install npm:pi-mcp-adapter` |

> `--autoConnect` needs Chrome **144+** (Beta or Stable). Check yours at `chrome://version`. `--channel` defaults to `stable`.

## Setup

### 1. Enable Remote Debugging in Chrome (once)

1. Open Chrome (Beta or Stable — must match the `--channel` you configure below)
2. Navigate to `chrome://inspect/#remote-debugging`
3. Toggle **"Enable remote debugging"** on
4. Restart Chrome
5. When the agent first connects, Chrome pops a dialog → click **Allow**

The toggle is persistent — steps 1–4 are one-time. The **Allow** dialog reappears on each new connection.

### 2. Add the MCP server config

`pi-mcp-adapter` merges server definitions from four locations (highest → lowest precedence; the same server in two files → the higher tier wins):

| # | Purpose | Path |
|---|---------|------|
| 1 | user-global (shared w/ Cursor, Claude, …) | `~/.config/mcp/mcp.json` |
| 2 | pi-specific global | `~/.pi/agent/mcp.json` |
| 3 | project-local (shared) | `<repo>/.mcp.json` |
| 4 | pi-specific project | `<repo>/.pi/mcp.json` |

> **Want it everywhere?** Drop it in tier 1 — `~/.config/mcp/mcp.json` — once, and every pi session (plus other MCP-aware tools) picks it up. No per-project file needed.

The server block is identical in any of them:

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

> Prefer not to hand-edit JSON? Run `/mcp setup` in pi — it has a one-click **Chrome DevTools** preset that writes the file for you.

Restart pi (or run `/mcp`). The server is **lazy** — it only spawns when you first call one of its tools.

**Alternative flags:**

| Flag | Effect |
|------|--------|
| `--channel` | Chrome channel: `stable` (default), `beta`, `dev`, `canary` — must match an installed Chrome |
| `--autoConnect` | Auto-connect to a running Chrome (144+) for session reuse — **required** to reuse your logins |
| `--browser-url` | Connect to a Chrome you launched manually with `--remote-debugging-port` (fallback — see Troubleshooting) |
| `--headless` | Use headless Chrome instead of a visible window |
| `--slim` | Fewer tools, faster startup |

### 3. Verify

```
mcp({ connect: "chrome-devtools" })
```

You should see ~29 tools available. If not, make sure Chrome is running and remote debugging is enabled.

## Usage

### Quick Examples

```
# Navigate
mcp({ tool: "chrome_navigate", args: '{"url": "https://github.com"}' })

# Take a screenshot
mcp({ tool: "chrome_screenshot", args: '{"name": "github-home"}' })

# Get DOM snapshot
mcp({ tool: "chrome_get_console_logs", args: '{}' })

# Execute JavaScript
mcp({ tool: "chrome_evaluate", args: '{"script": "document.title"}' })

# Click an element
mcp({ tool: "chrome_click_element", args: '{"selector": "a[href='/login']"}' })
```

### Available Tool Categories

| Category | Tools (examples) |
|----------|-------------------|
| **Navigation** | `chrome_navigate`, `chrome_go_back`, `chrome_go_forward`, `chrome_refresh` |
| **Interaction** | `chrome_click_element`, `chrome_type_text`, `chrome_select_option`, `chrome_hover_element` |
| **Inspection** | `chrome_screenshot`, `chrome_get_console_logs`, `chrome_get_network_logs`, `chrome_get_dom_snapshot` |
| **JavaScript** | `chrome_evaluate`, `chrome_execute_script` |
| **Performance** | `chrome_performance_profiler_start`, `chrome_performance_profiler_stop` |
| **Tabs** | `chrome_list_tabs`, `chrome_new_tab`, `chrome_switch_tab`, `chrome_close_tab` |

> Run `mcp({ describe: "chrome_devtools_list" })` for the full list.

## How It Compares

| | **Chrome DevTools MCP** | **OpenChrome** | **agent-browser** | **rodney** |
|---|---|---|---|---|
| Real Chrome session | ✅ `--autoConnect` | ✅ cookie sync | ✅ profile loading | ❌ fresh instance |
| Setup effort | Low (one toggle) | Medium | Medium | Low (`uv tool install`) |
| MCP-native | ✅ 29+ tools | ✅ | ❌ CLI only | ❌ CLI only |
| Headless support | ✅ `--headless` | ✅ | ✅ | ✅ |
| Network inspection | ✅ built-in | ❌ | ❌ | ❌ |
| JS console | ✅ built-in | ❌ | ❌ | ❌ |

Full comparison → [browser-tools-comparison.md](browser-tools-comparison.md)

## Troubleshooting

### "No Chrome instances found"

- Chrome is not running → start it
- Remote debugging not enabled → `chrome://inspect/#remote-debugging`, toggle on, restart
- Wrong channel → use `--channel=beta` if you have Chrome Beta, `--channel=stable` for Stable

### "Connection refused"

- Chrome restarted after enabling debugging → try again, the flag is persistent
- Another MCP server already connected → close other connections, Chrome allows one at a time

### `--autoConnect` finds nothing on macOS (Chrome 136+ default profile)

Known issue ([#1830](https://github.com/ChromeDevTools/chrome-devtools-mcp/issues/1830)): after Chrome 136+ hardening, `--autoConnect` can fail to attach to your **default** profile on macOS. Fallback — launch Chrome yourself with a dedicated profile + port, then point the server at it:

```bash
# 1. launch Chrome with remote debugging on a custom profile + port
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --remote-debugging-port=9222 \
  --user-data-dir=/tmp/chrome-profile-stable
```

```json
// 2. switch the server to --browser-url (drop --autoConnect)
"args": ["-y", "chrome-devtools-mcp@latest", "--browser-url=http://127.0.0.1:9222"]
```

Trade-off: a separate `--user-data-dir` is a **fresh** profile (no shared logins). To reuse your real session over a port, point `--user-data-dir` at a copy of your Default profile.

### MCP server shows as "not connected"

This is expected — MCP servers are **lazy-loaded**. The server only starts when you call a tool. Just call the tool you need directly instead of checking connection status first.

### Idle disconnects

Servers auto-disconnect after ~10 minutes of inactivity and reconnect on next use. This is normal.

## Notes

- Config **never** goes in `.pi/settings.json` — use one of the four `mcp.json` locations in [§2](#2-add-the-mcp-server-config). `~/.config/mcp/mcp.json` is the recommended global default.
- For headless-only usage, add `--headless` to the args. No Chrome window will appear.
- The `--slim` flag reduces the tool set for faster startup — useful if you only need navigation and screenshots.
- Official flag reference: <https://developer.chrome.com/docs/devtools/agents/get-started/configuration> · repo: <https://github.com/ChromeDevTools/chrome-devtools-mcp>
