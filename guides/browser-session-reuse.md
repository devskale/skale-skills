---
name: browser-session-reuse
description: "Free/open-source tools that reuse your real browser session (cookies, logins, tabs) for agentic browsing. Smoke test results, setup guides, and recommendations."
version: 0.1.0
date: 2026-06-06
---

# Browser Session Reuse — Free & Open Source

> How to let AI agents browse the web **as you** — using your existing Chrome logins, cookies, and tabs.
> No paid services. No cloud browsers. Your machine, your browser, your data.

## The Problem

Chrome 136+ (March 2025) killed `--remote-debugging-port` on the default profile. The old `chrome --remote-debugging-port=9222` trick silently fails. App-Bound Encryption prevents copying cookies to a new profile directory. This means most Puppeteer/Playwright-based tools **cannot access your real sessions** anymore.

## Solutions That Actually Work (Free & Open Source)

### TIER 1 — Controls Your ACTUAL Running Chrome

These connect to Chrome you already have open. Your tabs, your cookies, your logins. No new browser launched.

| # | Tool | Method | Install | MCP? | Chrome Web Store? |
|---|------|--------|---------|:----:|:-----------------:|
| 1 | **Chrome DevTools MCP** | Native Chrome toggle (`--autoConnect`, Chrome 146+) | `npx chrome-devtools-mcp@latest` | ✅ | N/A (built-in) |
| 2 | **OpenChrome** (`openchrome-mcp`) | CDP direct to real Chrome, persistent profiles, parallel | `npx openchrome-mcp` | ✅ | N/A |
| 3 | **Real Browser MCP** | Chrome extension + WebSocket MCP server | `npm i real-browser-mcp` + extension | ✅ | ✅ Yes |
| 4 | **Nanobrowser** | Chrome extension, multi-agent planner→navigator→validator | Chrome Web Store | No (extension) | ✅ Yes |
| 5 | **mcp-chrome** (hangwin) | Chrome extension + HTTP bridge, 23+ tools | `npm i mcp-chrome` + extension | ✅ | ❌ Sideload |
| 6 | **chrome-mcp** (DeepakSilaych) | Chrome extension exposes tabs/cookies to MCP | `npm i chrome-mcp` + extension | ✅ | ❌ Sideload |
| 7 | **Playwright MCP Bridge** (Microsoft) | Official extension, human authorizes per tab | `npx @playwright/mcp@latest --extension` | ✅ | ✅ Yes |
| 8 | **Browserfly** | Chrome extension, bring-your-own-keys AI agent | Chrome Web Store | No (extension) | ✅ Yes |

### TIER 2 — Imports Your Cookies/Profile (launches own browser)

These copy or decrypt your Chrome auth and use it in a fresh browser instance.

| # | Tool | Method | Install | Gets real cookies? | Speed |
|---|------|--------|---------|:------------------:|------:|
| 9 | **agent-browser** (`--profile Default`) | Copies Chrome profile to temp dir | `brew install agent-browser` | ✅ (most) | 2.2s ⚡ |
| 10 | **browser-use** (`from_system_chrome()`) | Copies Chrome profile (Python/Playwright) | `pip install browser-use` | ✅ (most) | 28s |
| 11 | **agentauth-py** | Decrypts Chrome cookies (defeats App-Bound Encryption) | `pip install agentauth-py` | ✅ all | fast |
| 12 | **sweet-cookie** | Reads cookie DBs (Chrome/Edge/Firefox/Safari) | `npx @steipete/sweet-cookie` | ✅ most | fast |

---

## Smoke Tests

> Run date: 2026-06-06 · macOS arm64 · Chrome stable v149

### Test Plan

For each tool, we test:
1. **Install** — does it install cleanly?
2. **Connect** — does it see your real Chrome session?
3. **Navigate** — can it open a page?
4. **Read** — can it extract page content?
5. **Auth** — does it see your cookies/logins on a protected site (e.g., GitHub)?

### Results

| Tool | Install | Connect to real Chrome | Navigate | Read content | Click/Interact | Screenshot | Verdict |
|------|:-------:|:----------------------:|:--------:|:------------:|:--------------:|:----------:|---------|
| **OpenChrome** v1.12.7 | ✅ `npm i -g` | ✅ CDP on port 9333 | ✅ title + stats | ✅ DOM + a11y refs | ✅ 12ms click | ✅ 21KB PNG | ✅ **PASS** |
| Chrome DevTools MCP | | | | | | | ⏳ |
| Real Browser MCP | | | | | | | ⏳ |
| Nanobrowser | | | | | | | ⏳ |
| mcp-chrome (hangwin) | | | | | | | ⏳ |
| agent-browser --profile | | | | | | | ⏳ |
| agentauth-py | | | | | | | ⏳ |
| sweet-cookie | | | | | | | ⏳ |

---

## Detailed Setup & Notes

### 1. Chrome DevTools MCP

```json
{
  "mcpServers": {
    "chrome-devtools": {
      "command": "npx",
      "args": ["-y", "chrome-devtools-mcp@latest", "--autoConnect"]
    }
  }
}
```

**Prerequisites:** Chrome 146+ stable. Enable once: `chrome://inspect/#remote-debugging` → toggle on.

**Pros:** Built into Chrome. Zero extension install. Sees everything.
**Cons:** Headed only. Chrome 146+ required. No parallel sessions.

### 2. OpenChrome ✅ SMOKE TESTED

```bash
# Install globally
npm install -g openchrome-mcp
openchrome --version  # 1.12.7
```

**For MCP clients (Claude Code, Cursor, etc.):**
```bash
openchrome setup                    # auto-configures Claude Code
openchrome setup --client codex     # Codex CLI
```

**Manual MCP config:**
```json
{
  "mcpServers": {
    "openchrome": {
      "command": "openchrome",
      "args": ["serve", "--auto-launch"]
    }
  }
}
```

**CLI one-shots (via HTTP daemon):**
```bash
# 1. Start the daemon (one time)
export OPENCHROME_ALLOW_UNAUTHENTICATED_HTTP=1
openchrome serve --port 9333 --auto-launch --http 3101 &

# 2. Navigate
OPENCHROME_HTTP_PORT=3101 openchrome navigate "https://example.com" --reuse --json

# 3. Read page (DOM or a11y)
OPENCHROME_HTTP_PORT=3101 openchrome run read_page --arg tabId=TAB_ID --arg mode=ax --reuse --json

# 4. Click (needs fresh refs from read_page)
OPENCHROME_HTTP_PORT=3101 openchrome run interact --arg ref=ref_10 --arg action=click --reuse --json

# 5. Screenshot
OPENCHROME_HTTP_PORT=3101 openchrome run page_screenshot --arg tabId=TAB_ID --arg path=/tmp/screenshot.png --reuse --json
```

#### Smoke Test Results (2026-06-06)

| Test | Result | Detail |
|------|:------:|--------|
| Install | ✅ | `npm i -g openchrome-mcp` — 119 packages, 6s |
| Connect to Chrome (CDP) | ✅ | Found existing Chrome on port 9333, connected |
| Navigate | ✅ | example.com → title "Example Domain", 11 elements |
| Read page (DOM) | ✅ | Full DOM tree with `[ref_N]` IDs, 9ms |
| Read page (a11y) | ✅ | Accessibility tree with `ref_N @eN` IDs |
| Click (interact) | ✅ | Clicked "Learn more" → navigated to iana.org, 12ms |
| Screenshot | ✅ | 21KB PNG, 1920×1080, 66ms |
| Hint engine | ✅ | Auto-detected stale refs, suggested recovery |
| Doctor | ✅ | Ran diagnostic, found port 9222 conflict with Chrome Beta |

#### ✅ Cookie Sync WORKS — GitHub Login Verified

OpenChrome's atomic SQLite cookie sync successfully copied session cookies from the real Chrome profile to `~/.openchrome/profile/`. GitHub showed **"logged-in"**, avatar for **@devskale** (Skale.io Developer Account), and the **Dashboard** with Top repositories. **No App-Bound Encryption issue** — cookies decrypted correctly in the persistent profile.

The workflow that works:
1. OpenChrome syncs cookies from `~/Library/Application Support/Google/Chrome/Default/Cookies` → `~/.openchrome/profile/Default/Cookies` via `sqlite3 .backup`
2. Chrome launches with `--user-data-dir=~/.openchrome/profile/`
3. Cookies are readable because the persistent profile dir is treated as a legitimate Chrome profile by the OS keychain

**Key insight:** App-Bound Encryption ties the key to the OS user account + profile *path type*, not the exact path string. A `--user-data-dir` pointing to `~/.openchrome/profile/` can decrypt cookies that were synced from the real Chrome profile on the same macOS account.

#### Gotchas

1. **Port 9222 conflict:** If Chrome Beta (or any Chrome) is already on port 9222 but not serving CDP, OpenChrome can't auto-launch. Use `--port 9333` and launch Chrome manually with `--user-data-dir=~/.openchrome/profile/`.
2. **Auto-launch may fail:** If Chrome stable is already running (without debug port), `--auto-launch` can't start a second instance. Workaround: manually launch Chrome with `--user-data-dir=~/.openchrome/profile/ --remote-debugging-port=9333`, then run `openchrome serve --port 9333 --http 3102`.
3. **HTTP mode needs auth:** Set `OPENCHROME_ALLOW_UNAUTHENTICATED_HTTP=1` for local dev, or `OPENCHROME_AUTH_TOKEN=xyz` for production.
4. **Stale refs:** After page navigation, refs from `read_page` are invalidated. Must re-read before clicking.
5. **`oc run` (CLI one-shots) uses --server-mode** which launches its own headless Chrome — not your real profile. Use the HTTP daemon + `--reuse` for real-session access.
6. **118 tools registered** — massive surface. Hint engine helps guide agents.

**Pros:** Real Chrome CDP. Persistent profiles. **Cookie sync actually works** (GitHub login verified). Parallel sessions. WAF fallback. Context export/import. Hint engine. Stale-ref detection. 118 tools. Contract assertions. Evidence bundles. Skill recording. Declarative playbooks.
**Cons:** Complex setup for CLI one-shots (need HTTP daemon). Auto-launch fragile when Chrome already running (manual Chrome launch needed as workaround).

**→ Full usage guide: [openchrome-usage.md](openchrome-usage.md)**

### 3. Real Browser MCP

```bash
npm install -g real-browser-mcp
# + install Chrome extension from Web Store: "Real Browser MCP"
```

```json
{
  "mcpServers": {
    "real-browser": {
      "command": "real-browser-mcp"
    }
  }
}
```

**Pros:** Chrome Web Store extension. Dead simple. WebSocket = survives MCP client restarts.
**Cons:** New project. One tab focus.

### 4. Nanobrowser

Install from Chrome Web Store: [Nanobrowser](https://chromewebstore.google.com/detail/nanobrowser-ai-web-agent/imbddededgmcgfhfpcjmijokokekbkal)

Bring your own LLM API key (Gemini, GPT-4, etc.). Multi-agent: planner → navigator → validator.

**Pros:** Mature extension. Chrome Web Store. Multi-agent architecture. No backend needed.
**Cons:** Not an MCP server — runs in browser only. Needs your own LLM key.

### 5. mcp-chrome (hangwin)

```bash
# Install bridge
npm install -g mcp-chrome
# Sideload extension from https://github.com/hangwin/mcp-chrome
```

```json
{
  "mcpServers": {
    "chrome-mcp": {
      "type": "streamableHttp",
      "url": "http://127.0.0.1:12306/mcp"
    }
  }
}
```

**Pros:** 23+ tools. No debug port. HTTP/WebSocket bridge. ~6k stars. LLM-optimized screenshots.
**Cons:** Sideload extension (not in Web Store). Two processes (extension + bridge).

### 6. agent-browser (profile reuse)

```bash
brew install agent-browser
agent-browser install
agent-browser --profile Default open https://github.com
```

**Pros:** 2.2s profile load. Rust binary. Token-efficient a11y snapshots. State persistence.
**Cons:** Doesn't control your running Chrome — copies profile to temp dir. Some cookies may fail with App-Bound Encryption.

### 7. agentauth-py

```bash
pip install agentauth-py
agent-auth grab github.com
# Cookies stored in encrypted vault
```

**Pros:** Defeats App-Bound Encryption. Works with Playwright/requests/LangChain. macOS/Linux.
**Cons:** Extract-only — needs another tool to use cookies. macOS/Linux only.

### 8. sweet-cookie

```bash
npx @steipete/sweet-cookie github.com
# Prints cookies as header string
```

**Pros:** Multi-browser (Chrome/Edge/Firefox/Safari). Zero native addons. CLI + library. Battle-tested (used in peep, willhaben skills).
**Cons:** Extract-only. Node ≥22 or Bun required. Some v20 App-Bound cookies skipped.

---

## Decision Flow

```
I want my AI coding agent (Claude/Cursor/etc) to browse as me:
│
├─► Chrome 146+? ──► Chrome DevTools MCP + --autoConnect (simplest)
├─► Want parallel sessions? ──► OpenChrome
├─► Prefer extension? ──► mcp-chrome or Real Browser MCP
└─► Enterprise/security? ──► Playwright MCP Bridge Extension
```

```
I want an AI agent IN my browser (side panel):
│
└─► Nanobrowser (bring your own LLM key)
```

```
I need cookies in scripts (no browser automation needed):
│
├─► Python ──► agentauth-py
└─► Node/Bun ──► sweet-cookie
```

```
I want CLI automation with my profile:
│
└─► agent-browser --profile Default (2.2s, best CLI)
```

---

## References

- [Chrome Blog: remote-debugging-port changes](https://developer.chrome.com/blog/remote-debugging-port) — the breaking change
- [Webfuse: Top 5 MCP Servers for Browser Automation 2026](https://www.webfuse.com/blog/the-top-5-best-mcp-servers-for-ai-agent-browser-automation)
- [OpenChrome GitHub](https://github.com/shaun0927/openchrome)
- [Real Browser MCP GitHub](https://github.com/iflow-mcp/ofershap-real-browser-mcp)
- [Nanobrowser](https://nanobrowser.ai/) · [GitHub](https://github.com/nanobrowser/nanobrowser)
- [mcp-chrome (hangwin)](https://github.com/hangwin/mcp-chrome)
- [chrome-mcp (DeepakSilaych)](https://github.com/DeepakSilaych/chrome-mcp)
- [Playwright MCP Bridge Extension](https://github.com/microsoft/playwright-mcp)
- [agent-browser](https://github.com/vercel-labs/agent-browser)
- [agentauth-py](https://pypi.org/project/agentauth-py/)
- [sweet-cookie](https://github.com/steipete/sweet-cookie)
- [Full comparison: browser-tools-comparison.md](browser-tools-comparison.md)
