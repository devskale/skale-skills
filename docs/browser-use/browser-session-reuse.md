---
name: browser-session-reuse
description: "Reuse your real Chrome session (cookies, logins, tabs) for agentic browsing: Chrome DevTools MCP autoConnect, OpenChrome cookie sync, agent-browser profile copy, sweet-cookie extraction. Chrome 136+ constraints, verified smoke tests."
version: 0.2.0
date: 2026-10-11
---

# Browser Session Reuse — Your Real Chrome, Agent-Driven

> The single source of truth for "browse as me". Free/open-source tools only.
> Tool landscape → [browser-tools-comparison.md](browser-tools-comparison.md).

## The Problem (Chrome 136+)

Since March 2025, `--remote-debugging-port` on the default profile is **silently ignored**, and App-Bound Encryption blocks decrypting cookies copied to a new profile directory. Most Puppeteer/Playwright tools therefore **cannot reach your real sessions**. What still works, by tier:

| Tier | Method | Tools |
|------|--------|-------|
| **1 — controls your actual running Chrome** | DevTools MCP `--autoConnect` (Chrome 146+); extension-based bridges | Chrome DevTools MCP, Playwright MCP Bridge, Nanobrowser, livemcp |
| **2 — imports your cookies/profile into own browser** | cookie sync, profile copy, cookie decryption | OpenChrome, agent-browser `--profile`, browser-use `from_system_chrome()`, sweet-cookie |
| **3 — own browser only** | no session attachment | rodney, CloakBrowser, cloud browsers |

**macOS exception (verified):** Chrome on macOS encrypts cookies with a Keychain key tied to the *user account*, not the profile path — so cookie sync into a different `--user-data-dir` **works on macOS** (OpenChrome proved it). Windows DPAPI + App-Bound v20 blocks it.

## Tier 1 — Control Your Running Chrome

### Chrome DevTools MCP `--autoConnect` (simplest)

```json
{ "mcpServers": { "chrome-devtools": {
    "command": "chrome-autoallow",
    "args": ["run", "--autoConnect", "--channel=beta"] } } }
```

Enable once: `chrome://inspect/#remote-debugging` → toggle on. The `chrome-autoallow` wrapper auto-clicks the consent dialog. Sees everything — tabs, cookies, localStorage. Headed only, no parallel sessions. Setup → [chrome-dev.md](chrome-dev.md).

### Playwright MCP Bridge Extension (Microsoft, human-in-loop)

`npx @playwright/mcp@latest --extension` — sideload the extension from GitHub releases; each session requires a manual "Connect" authorize click. Perfect identity preservation, enterprise-friendly, one tab at a time.

### Nanobrowser (agent in your browser)

Chrome Web Store extension, bring-your-own LLM key, planner→navigator→validator multi-agent. Runs in the browser, not an MCP server.

### OpenChrome ✅ smoke-tested (2026-06-06)

MCP server + CLI driving real Chrome via CDP, with **atomic cookie sync** into a persistent profile (`~/.openchrome/profile/`). **GitHub login verified as @devskale** — cookies synced from the real profile decrypt correctly on macOS (see exception above). Killer features: parallel authenticated sessions, contract assertions (`oc_assert`), hint engine, 118 tools.

**Three-tier profile strategy:** ① real profile (Chrome fully closed) · ② persistent profile + cookie sync (default — works while Chrome runs) · ③ `--restart-chrome` (kills your Chrome — avoid).

```bash
npm i -g openchrome-mcp
openchrome setup                    # auto-configures Claude Code / Cursor / Codex
# CLI one-shots need the HTTP daemon (oc run uses a headless temp profile — NOT your cookies):
export OPENCHROME_ALLOW_UNAUTHENTICATED_HTTP=1
openchrome serve --port 9333 --auto-launch --http 3101 &
OPENCHROME_HTTP_PORT=3101 openchrome navigate "https://example.com" --reuse --json
OPENCHROME_HTTP_PORT=3101 openchrome run read_page --arg tabId=TAB_ID --arg mode=ax --reuse --json
OPENCHROME_HTTP_PORT=3101 openchrome run interact --arg ref=ref_10 --arg action=click --arg tabId=TAB_ID --reuse --json
```

Smoke results: connect ✅ (CDP 9333) · navigate ✅ · DOM+a11y read ✅ (9ms) · click ✅ (12ms) · screenshot ✅ · cookie sync ✅.

**When Chrome is already running** (the common case — `--auto-launch` can't start a second instance), launch Chrome manually against the synced profile:

```bash
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --remote-debugging-port=9333 --user-data-dir="$HOME/.openchrome/profile" \
  --profile-directory="Default" --no-first-run --no-default-browser-check "about:blank" &
openchrome serve --port 9333 --http 3101   # connects to that instance
```

**Cookie sync internals:** atomic `sqlite3 .backup` of the Cookies DB + file copy of localStorage/IndexedDB (passwords, extensions, history are NOT synced). Sync runs on serve startup when stale (mtime hash of source DB) — restart serve to re-sync. Short-lived tokens (OAuth nonces, CSRF) go stale; long-lived sessions (GitHub, Google) are fine.

**Troubleshooting:** port 9222 conflict with Chrome Beta → use `--port 9333` · `STALE_REF` on click → `read_page` first, refs die on navigation · HTTP mode refuses unauthenticated → `OPENCHROME_ALLOW_UNAUTHENTICATED_HTTP=1` · cookies stale → restart serve · `sqlite3` missing (Linux) → `apt install sqlite3` · Windows v20 App-Bound cookies don't survive sync (macOS v10 does).

**Don't use it when:** you just need your already-running Chrome → DevTools MCP is simpler; quick scrape → rodney/agent-browser.

**Walking dead (avoid):** mcp-chrome (hangwin) — 12.4k★ but silent since 2026-01 · Real Browser MCP — 0★. See the [graveyard](browser-tools-comparison.md#graveyard-verified-2026-10-04-via-githubnpmpypi).

## Tier 2 — Import Cookies/Profile into Own Browser

| Tool | Method | Gets real cookies? | Speed |
|------|--------|:-----------------:|------:|
| **agent-browser** `--profile Default` | copies profile to temp dir | ✅ most | **2.2s** ⚡ |
| **browser-use** `from_system_chrome()` | copies profile (Playwright) | ✅ most | 28s, 4 GB+ disk |
| **sweet-cookie** | reads cookie DBs (Chrome/Edge/Firefox/Safari) | ✅ most | fast |

### agent-browser

```bash
brew install agent-browser && agent-browser install
agent-browser --profile Default open https://github.com   # read-only snapshot of your profile
agent-browser --auto-connect state save ./auth.json        # export auth from running Chrome
agent-browser --state ./auth.json open https://app.example.com
agent-browser --session-name myapp open https://example.com   # auto persist from now on
```

Caveat: `--profile` may hit App-Bound Encryption on some cookies; `--auto-connect state save` + `--state` is the reliable path. State can be AES-256-GCM encrypted via `AGENT_BROWSER_ENCRYPTION_KEY`.

### sweet-cookie (cookies for scripts — no browser at all)

```bash
npx @steipete/sweet-cookie github.com                 # prints cookie header
npx @steipete/sweet-cookie x.com --browser chrome --format header
```

Zero native addons (`node:sqlite` + OS keychain), Node ≥22/Bun, battle-tested in the peep and willhaben skills. Extract-only — inject into `fetch()`/requests yourself. v20 App-Bound cookies are skipped with a warning.

🧟 **agentauth-py** (the old answer) is walking dead — no source since 2025-03. Use sweet-cookie.

## Decision Flow

```
Browse as me:
├─ Chrome 146+? ──────────► Chrome DevTools MCP --autoConnect (simplest)
├─ Parallel sessions? ────► OpenChrome (cookie sync, verified)
├─ Prefer extension? ─────► Playwright MCP Bridge (human-in-loop) or Nanobrowser
└─ CLI with my profile? ──► agent-browser --profile Default (2.2s)

Cookies in scripts (no browser):
└─ Node/Bun ─────────────► sweet-cookie
```

## References

- [Chrome blog: remote-debugging-port changes](https://developer.chrome.com/blog/remote-debugging-port) — the breaking change
- [OpenChrome](https://github.com/shaun0927/openchrome) · [auto-connect docs](https://github.com/shaun0927/openchrome/blob/main/docs/auto-connect.md) · [CLI docs](https://github.com/shaun0927/openchrome/blob/main/docs/cli.md)
- [Playwright MCP Bridge](https://github.com/microsoft/playwright-mcp) · [Nanobrowser](https://nanobrowser.ai/) · [livemcp](https://github.com/Magi-Labs/livemcp)
- [agent-browser](https://github.com/vercel-labs/agent-browser) · [sweet-cookie](https://github.com/steipete/sweet-cookie)
- Full tool landscape → [browser-tools-comparison.md](browser-tools-comparison.md)

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 0.2.0 | 2026-10-11 | Compacted; absorbed the session-connect section + session-tool catalog from browser-tools-comparison.md (single source of truth). **v0.2.1: folded openchrome-usage.md in** (tier strategy, Chrome-already-running workaround, sync internals, troubleshooting) and deleted the file. Walking-dead tools reduced to one-liners. |
| 0.1.0 | 2026-06-06 | Initial: tiers, smoke tests, setup notes. |
