# Chrome DevTools MCP — Setup Guide

## What

Control a live Chrome browser from Pi via MCP. Screenshots, DOM snapshots, network inspection, performance traces, JavaScript console, and more — all through your real Chrome with cookies and logins intact.

**Best for:** Reusing your authenticated Chrome session without a separate browser profile.

## Why Chrome DevTools MCP?

| Advantage | Detail |
|-----------|--------|
| **Real session reuse** | Connects to your running Chrome — all cookies, logins, extensions work |
| **No `--remote-debugging-port` hack** | Uses `--autoConnect` (Chrome 146+), bypasses Chrome 136+ restrictions |
| **29+ tools** | Navigate, click, screenshot, network logs, JS console, DOM queries, performance traces |
| **Zero config in Chrome** | Toggle once in `chrome://inspect/#remote-debugging`, done forever |
| **Lazy-loaded** | MCP server only starts when you use it, auto-disconnects when idle |

## Prerequisites

| Requirement | Install |
|-------------|---------|
| Chrome Beta (v146+) | https://www.google.com/chrome/beta/ |
| `pi-mcp-adapter` | `pi install npm:pi-mcp-adapter` |

> Chrome Stable also works if it's v146+. Check with `chrome://version`.

## Setup

### 1. Enable Remote Debugging in Chrome (once)

1. Open Chrome Beta
2. Navigate to `chrome://inspect/#remote-debugging`
3. Toggle **"Enable remote debugging"** on
4. Restart Chrome

This is persistent — you only do it once.

### 2. Add MCP Server to Your Project

Create or edit `.mcp.json` in your project root:

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

That's it. Restart Pi — the server connects lazily when you first use it.

**Alternative flags:**

| Flag | Effect |
|------|--------|
| `--channel=beta` | Connect to Chrome Beta (change to `--channel=stable` if using Stable) |
| `--headless` | Use headless Chrome instead of visible window |
| `--slim` | Fewer tools, faster startup |
| `--autoConnect` | Auto-connect to running Chrome (required for session reuse) |

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

### MCP server shows as "not connected"

This is expected — MCP servers are **lazy-loaded**. The server only starts when you call a tool. Just call the tool you need directly instead of checking connection status first.

### Idle disconnects

Servers auto-disconnect after ~10 minutes of inactivity and reconnect on next use. This is normal.

## Notes

- Config goes in `.mcp.json` (project) or `~/.config/mcp/mcp.json` (global) — **not** in `.pi/settings.json`
- For headless-only usage, add `--headless` to the args. No Chrome window will appear.
- The `--slim` flag reduces the tool set for faster startup — useful if you only need navigation and screenshots.
