# Browser Automation Docs — Index

Pick by task. Every doc is one click away; each topic has exactly one source of truth.

## Drive by task

| I want to… | Read this |
|------------|-----------|
| **Pick surf vs rodney vs chrome-devtools-mcp** (the everyday choice) | [which-browser-tool.md](which-browser-tool.md) |
| **Browse as me** — reuse my real Chrome session (cookies, logins, incl. OpenChrome cookie sync) | [browser-session-reuse.md](browser-session-reuse.md) |
| Compare the full tool landscape (matrix, benchmarks, token costs, graveyard) | [browser-tools-comparison.md](browser-tools-comparison.md) |
| Set up Chrome DevTools MCP | [chrome-dev.md](chrome-dev.md) |
| Set up Vercel agent-browser | [vcl-agent-browser.md](vcl-agent-browser.md) |
| **surf** — drive my real Chrome on macOS (AppleScript) | [surf.md](surf.md) |
| Browse in the terminal (w3m, chawan) | [terminal-browsing.md](terminal-browsing.md) |
| Sniff an API without any browser | [api-sniffing.md](api-sniffing.md) |

## The one load-bearing rule

> ⚠️ **Chrome 136+ (March 2025):** `--remote-debugging-port=9222` is **silently ignored** on the default profile; `--user-data-dir` gives a blank profile; App-Bound Encryption blocks copied-profile cookies (macOS excepted — verified). Never cite pre-March-2025 tutorials.
>
> What still reaches your real session: DevTools MCP `--autoConnect`, extension bridges, cookie sync/extraction. Details → [browser-session-reuse.md](browser-session-reuse.md).

## Decision in one line

- Real session on macOS, zero setup → **surf**
- Real session, any OS, or read console/perf → **chrome-devtools-mcp**
- Clean headless browser (scraping, CI, assertions) → **rodney**
- Everything else (stealth, cloud, frameworks, matrices) → [browser-tools-comparison.md](browser-tools-comparison.md)
- No browser needed at all? Try [api-sniffing.md](api-sniffing.md) first
