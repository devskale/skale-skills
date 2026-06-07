# Browser Automation Docs

Everything about browser automation for AI agents — tools, setups, and Chrome 136+ constraints.

## Quick Navigation

| I want to… | Read this |
|------------|-----------|
| Compare all browser tools (feature matrix, token costs) | [browser-tools-comparison.md](browser-tools-comparison.md) |
| Reuse my real Chrome session (cookies, logins) | [browser-session-reuse.md](browser-session-reuse.md) |
| Set up OpenChrome MCP | [openchrome-usage.md](openchrome-usage.md) |
| Set up Chrome DevTools MCP | [chrome-dev.md](chrome-dev.md) |
| Set up Vercel agent-browser | [vcl-agent-browser.md](vcl-agent-browser.md) |

## Tool Decision Flow

```
Need a browser?
├── Reuse real Chrome session (cookies/logins)?
│   ├── Yes → OpenChrome MCP or Chrome DevTools MCP
│   │         (see browser-session-reuse.md)
│   └── No ↓
├── Need MCP integration?
│   ├── Yes → OpenChrome, Chrome DevTools MCP, or Playwright MCP
│   └── No ↓
├── Just need headless automation?
│   ├── Yes → rodney (rodney start/open/stop)
│   └── No ↓
└── Need stealth/anti-detect?
    └── CloakBrowser (testbed)
```

## Chrome 136+ Constraints

> ⚠️ Chrome 136+ (March 2025) broke `--remote-debugging-port=9222` on the default profile.
> **Never assume it works.** See [browser-tools-comparison.md](browser-tools-comparison.md) for the full breakdown.

Key facts:
- `--remote-debugging-port=9222` is **silently ignored** on the default profile
- `--user-data-dir` requires a separate (empty) profile
- App-Bound Encryption prevents copying cookies from the default profile
- Chrome 146+ `--autoConnect` via `chrome://inspect/#remote-debugging` still works

## Files

| File | Description |
|------|-------------|
| [browser-tools-comparison.md](browser-tools-comparison.md) | 10+ tools compared — rodney, OpenChrome, agent-browser, Playwright MCP, Puppeteer MCP, browser-use, CloakBrowser, Browserbase, Cloudflare Browser Run, Claude Computer Use |
| [browser-session-reuse.md](browser-session-reuse.md) | Strategies for reusing real Chrome sessions — cookie sync, profile mounting, App-Bound Encryption workarounds |
| [openchrome-usage.md](openchrome-usage.md) | OpenChrome MCP server setup, cookie sync, smoke test results |
| [chrome-dev.md](chrome-dev.md) | Chrome DevTools Protocol MCP setup — inspect, debug, automate live Chrome |
| [vcl-agent-browser.md](vcl-agent-browser.md) | Vercel agent-browser — Rust CLI, accessibility-tree snapshots, best Chrome profile reuse |
