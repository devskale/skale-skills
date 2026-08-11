---
name: which-browser-tool
description: "Pick the right browser tool: surf (drive your real logged-in Chrome on macOS), rodney (fresh isolated headless browser for scraping/mocking/CI), or chrome-devtools-mcp (deep introspection of a live page — console/perf/Lighthouse). Decision-first guide for agents. Triggers on: which browser tool, surf vs rodney vs chrome-devtools, browser automation choice, should I use surf or rodney or chrome-devtools-mcp."
---

# Which Browser Tool: `surf` vs `rodney` vs `chrome-devtools-mcp`

Three tools overlap. Pick by **what you're touching**: your real session, a clean throwaway browser, or a live page you need to introspect.

## Decide in one pass

Ask **one question** — it settles most cases:

> **Do I need the user's real, logged-in browser session?**

- **Real session on macOS, zero setup** → **`surf`** (AppleScript into their visible Chrome; no daemon/port/dialog).
- **Real session on any OS, or deep introspection (console/perf/Lighthouse)** → **`chrome-devtools-mcp`** (CDP `--autoConnect`; one "Allow" click).
- **No — want a clean, isolated, headless browser** (scraping, forms, PDFs, a11y, CI) → **`rodney`** (launches its own Chrome; never touches their data).

## When each wins

**`surf` wins when:** you're on a Mac, the page needs their login/cookies, and you want the lightest touch on the browser they already have open. The cost: macOS-only, drives their visible Chrome (no headless).

**`rodney` wins when:** you want a clean scriptable browser that won't disturb or expose the user's real session — headless by default, cross-platform, built-in assertions (`exists`, `visible`, `count`, `assert`), and **request interception** (`mock` serves a canned response, `block` fails requests client-side). The cost: launches its own browser (no session reuse), and interception is write-only — it can't *read* what the network sent (no console/network capture, perf traces, or Lighthouse).

**`chrome-devtools-mcp` wins when:** you must **read** a live page's internals — console logs, network requests/responses, performance traces, Lighthouse, heap snapshots — or attach to the user's real browser on any OS. The cost: needs their Chrome running and a one-time "Allow remote debugging?" click.

## They compose — combine, don't choose

These are complementary, not rivals. A typical session mixes them:

- **`surf`** for everyday click/fill/scrape on the user's real session (no friction).
- **`chrome-devtools-mcp`** when you need to **read** console/perf/Lighthouse on that same session.
- **`rodney`** for isolated/headless jobs and CI where you must not touch their data.

## Quick reference

| | **surf** | **rodney** | **chrome-devtools-mcp** |
|---|---|---|---|
| **Whose browser** | user's real Chrome | its own Chrome | user's real Chrome |
| **Headless** | ❌ | ✅ (default; `--show` for visible) | ❌ |
| **Platform** | macOS only | cross-platform | cross-platform |
| **Form factor** | bash CLI | bash CLI | MCP tools |
| **Assertions / CI** | DIY (`eval`/`count` + exit codes) | ✅ built-in | ❌ |
| **Network intercept (mock/block)** | ❌ | ✅ | ✅ |
| **Network / console / perf *read*** | ❌ | ❌ | ✅ |
| **PDF / a11y audit** | ❌ | ✅ | ✅ (Lighthouse) |
| **Session reuse** | ✅ | ❌ | ✅ |
| **Setup friction** | ~zero (one-time Apple Events toggle) | build Go binary | one-time "Allow" click |

## References

- **surf** — [surf.md](surf.md) · skill [`skills/surf/`](../../skills/surf/)
- **rodney** — [guides/rodney-setup.md](../../guides/rodney-setup.md) · skill [`skills/rodney/`](../../skills/rodney/)
- **chrome-devtools-mcp** — [chrome-dev.md](chrome-dev.md)
- **All browser tools (feature matrix, token costs)** — [browser-tools-comparison.md](browser-tools-comparison.md)
