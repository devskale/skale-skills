---
name: browser-tools-comparison
description: "Compare agent browser tools: rodney, Chrome DevTools MCP, agent-browser, CloakBrowser, Playwright MCP, Puppeteer MCP, browser-use, Claude Computer Use, Browserbase, Cloudflare Browser Run. Feature matrix, token costs, decision flow, Playwright vs Puppeteer deep-dive."
version: 0.1.4
date: 2026-06-01
---

# Agent Browser Tools — Comparison

> v0.1.0 · 2026-06-01 · Comprehensive comparison of browser tools for AI agents

## Tools Compared

| # | Tool | Type | Language | Protocol | In this repo? |
|---|------|------|----------|----------|---------------|
| 1 | [**rodney**](#1-rodney) | CLI → headless Chrome | Python (rod/Go) | CDP | ✅ skills/rodney |
| 2 | [**Chrome DevTools MCP**](#2-chrome-devtools-mcp) | MCP server → live Chrome | Node.js | CDP | ✅ guides/chrome-dev.md |
| 3 | [**agent-browser**](#3-agent-browser--vercel-labs) | CLI + daemon | Rust | CDP | ✅ guides/vcl-agent-browser.md |
| 4 | [**CloakBrowser**](#4-cloakbrowser) | Stealth Chromium lib | Python/C++ | CDP | ✅ testbed/cloakbrowser/ |
| 5 | [**Playwright MCP**](#5-playwright-mcp) | MCP server | Node.js | CDP | ❌ external |
| 6 | [**browser-use**](#6-browser-use) | Python agent framework | Python | Playwright | ❌ external |
| 7 | [**Claude Computer Use**](#7-claude-computer-use) | API tool (Anthropic) | — | Desktop / CDP | ❌ external |
| 8 | [**Browserbase MCP**](#8-browserbase-mcp) | Cloud MCP server | Node.js (Stagehand) | CDP | ❌ external |
| 9 | [**Cloudflare Browser Run**](#9-cloudflare-browser-run) | Cloud MCP server | — | CDP | ❌ external |
| 10 | [**Puppeteer MCP**](#10-puppeteer-mcp) | MCP server | Node.js (Google) | CDP | ❌ external |

---

## Quick Pick

| Need | Best tool | Also consider |
|------|-----------|--------------|
| **Connect to my running Chrome** (cookies, tabs, logins) | **Chrome DevTools MCP** (`--autoConnect`) | Claude Computer Use |
| **Control an existing session** (don't launch new browser) | **Chrome DevTools MCP** | Puppeteer/Playwright (separate profile only, Chrome 136+) |
| Headed (visible browser) for debugging | **Chrome DevTools MCP**, **rodney `--show`** | agent-browser dashboard, Playwright headed |
| Headless (no UI, background) | **rodney**, **agent-browser**, **CloakBrowser** | Playwright MCP headless, Puppeteer MCP |
| Both modes (switchable) | **Playwright MCP**, **Puppeteer MCP**, **rodney** | agent-browser |
| Simple scraping, screenshots, forms | **rodney** | agent-browser |
| Debug a live browser you're using | **Chrome DevTools MCP** | — |
| Token-efficient agent loops | **agent-browser** | rodney |
| Anti-detect / bot evasion | **CloakBrowser** | Browserbase (stealth) |
| Full AI agent framework (Python) | **browser-use** | agent-browser |
| Claude-based desktop automation | **Claude Computer Use** | Playwright MCP |
| Cloud scale, no local browsers | **Browserbase MCP** | Cloudflare Browser Run |
| Cross-browser testing (Fx/Safari) | **Playwright MCP** | Puppeteer MCP |
| Chromium-only, CDP-deep work | **Puppeteer MCP** | Playwright MCP |
| CI/CD smoke tests, assertions | **rodney** | Playwright MCP |
| Network interception, routing | **agent-browser** | Playwright MCP |

---

## 🔌 Connect to Existing Browser Session

> **This is the key axis.** Most tools launch their own browser. Only some can attach to Chrome that's *already running* — with your tabs open, cookies set, logged-in sessions active.

### What Are Your ACTUAL Options? (Honest List, 2026)

> ⚠️ **Current Chrome stable: v149** (June 2026). The Chrome 136+ restriction on `--remote-debugging-port` is **still in effect** — there's no workaround on the default profile. The old `chrome --remote-debugging-port=9222` against your daily Chrome **silently fails** (port never opens).

Given the Chrome 136+ breaking change and the limitations of each tool, here are your **realistic** options for connecting to a browser that has your sessions:

| # | Option | Gets your real Chrome? | Pros | Cons |
|---|--------|------------------------|------|------|
| 1 | **Chrome DevTools MCP + `--autoConnect`** (Chrome 146+ stable) | ✅ **YES** | Your actual browser, your cookies, your tabs. Zero setup once enabled. | Requires Chrome 146+. Single-browser attachment. |
| 2 | **Chrome DevTools MCP + `--browserUrl`** + manual Chrome launch with `--user-data-dir` | ❌ **separate profile** (blank) | Works on any Chrome. Full control. | Fresh profile — no your cookies unless you copy profile in. |
| 3 | **Puppeteer / Playwright `connectOverCDP()` + `--user-data-dir=/tmp/other`** | ❌ **separate profile** (blank) | Programmatic control. Both headed/headless. | Same profile limitation. Also requires killing your daily Chrome first. |
| 4 | **agentauth-py** (decrypts Chrome cookies) | ✅ **YES** (defeats App-Bound Encryption) | Works on macOS/Linux. Plugs into Playwright/requests/LangChain. | macOS/Linux only. 3rd-party tool. |
| 5 | **Hangwin mcp-chrome** (extension + local bridge) | ✅ **yes** (no debug port needed) | No command-line browser launch. More stable than raw CDP. | Extension + bridge to install. |
| 6 | **Playwright MCP Bridge Extension** (Microsoft) | ✅ **yes** (auth required) | Perfect state preservation. Microsoft-maintained. | Sideload extension. Manual authorization per session. |
| 7 | **agent-browser `--auto-connect state save`** | ✅ **yes** (if Chrome was launched with debug port + custom profile) | All-in-one Rust CLI. State encryption. | Requires manual Chrome launch with `--user-data-dir`. |
| 8 | **CloakBrowser Profile Manager** (Docker, self-hosted) | ❌ **own sessions, not yours** | Persistent cookies. Unique fingerprints. Free. | Not your Chrome's cookies. New persona. |
| 9 | **Rodney / agent-browser** (own browser only) | ❌ own | Simple. | No your sessions. |
| 10 | **Cloud tools** (Browserbase, CF Browser Run, Airtop, Bedrock AgentCore) | ❌ cloud only | No local install. | Not your browser. |
| ~~11~~ | ~~Claude Computer Use~~ | ~~✅ yes (desktop)~~ | — | **Ruled out** by user. |
| ~~12~~ | ~~Puppeteer / Playwright `connectOverCDP()` against default Chrome profile~~ | ~~was ✅~~ | — | **BROKEN since Chrome 136** — `--remote-debugging-port` ignored on default profile. Don't waste time trying. |

**Bottom line:** To get your *real* Chrome with your real cookies (without Claude), your real options are:
1. **Chrome DevTools MCP + `--autoConnect`** (cleanest, if Chrome 146+)
2. **agentauth-py** (most reliable, defeats encryption, macOS/Linux)
3. **Extension-based MCPs** (Hangwin, Playwright MCP Bridge) — no debug port drama

The old `chrome --remote-debugging-port=9222` pattern is dead. Don't rely on tutorials older than March 2025.

### ⚠️ Breaking Change: Chrome 136+ Killed the Old CDP Connect Method

> **March 2025, Chrome 136:** Google disabled `--remote-debugging-port` on the **default user data directory** as a [security measure](https://developer.chrome.com/blog/remote-debugging-port) against cookie theft via CDP.

**What broke:**

```
# OLD WAY (no longer works on your daily Chrome profile)
chrome --remote-debugging-port=9222
# → SILENTLY IGNORED if using your default profile
# → No debugging port opened. Your Puppeteer/Playwright connect fails.
```

```
# WORKAROUND (but loses your sessions!)
chrome --remote-debugging-port=9222 --user-data-dir=/tmp/chrome-debug
# → Works! BUT: empty profile. No cookies, no logins, no extensions.
# → This is NOT "connect to my browser." This is "connect to a blank browser."
```

**The only way to connect to YOUR actual browser (with your cookies, logins, open tabs):**

| Method | Chrome Version | Gets Your Real Sessions? |
|--------|---------------|----------------------|
| `--autoConnect` (DevTools MCP) | **146+ stable** | ✅ **YES** |
| `chrome://inspect/#remote-debugging` toggle | **146+ stable** | ✅ **YES** |
| `--remote-debugging-port` + default profile | **< 136 only** | ✅ was yes, **now broken** |
| `--remote-debugging-port` + `--user-data-dir` | any | ❌ **separate/empty profile** |
| Claude Computer Use (screenshots) | any | ✅ **YES** (different approach) |

### The Hierarchy (Post-Chrome 136)

```
┌───────────────────────────────────────────────────────────────────┐
│  TIER 1: Your REAL browser, your REAL sessions                  │
│  (the only ways to get your cookies, logins, open tabs)         │
│                                                                   │
│  ★ Chrome DevTools MCP + --autoConnect                          │
│     Chrome 146+ stable. Enable once in                           │
│     chrome://inspect/#remote-debugging. That's it.               │
│     Sees EVERYTHING — tabs, cookies, localStorage, logins.       │
│     It IS your browser.                                          │
│                                                                   │
│  ★ Claude Computer Use                                           │
│     Screenshots of your actual desktop. Controls your real       │
│     Chrome (or any browser/app). Different paradigm,             │
│     but gets your real sessions by definition.                   │
├───────────────────────────────────────────────────────────────────┤
│  TIER 2: CDP connect with SEPARATE profile                      │
│  (connects to A Chrome, just not YOUR Chrome)                   │
│                                                                   │
│  ⚠️ These work technically but do NOT get your daily            │
│     browser's cookies or login sessions!                        │
│                                                                   │
│  ◆ Puppeteer (core/MCP)                                         │
│     puppeteer.connect(ws://...) over CDP                        │
│     Requires: chrome --remote-debugging-port=9222                │
│                    --user-data-dir=/tmp/other-profile            │
│     Result: clean browser, NO your sessions                     │
│                                                                   │
│  ◆ Playwright (core/MCP)                                        │
│     chromium.connectOverCDP('http://localhost:9222')             │
│     Same requirement, same limitation.                          │
│                                                                   │
│  ◆ browser-use                                                  │
│     Inherits whatever backend you configure. Same limits.       │
│                                                                   │
│  💡 USE CASE: CI/CD, scraping, automation tasks where           │
│     you DON'T need your personal login state.                   │
├───────────────────────────────────────────────────────────────────┤
│  TIER 3: Own browser only (no session attachment)                │
│  (launches fresh Chrome every time — always isolated)            │
│                                                                   │
│  △ rodney          ──► launches own headless Chrome             │
│  △ agent-browser   ──► downloads & runs own Chrome for Testing  │
│  △ CloakBrowser    ──► runs own stealth Chromium binary        │
│  △ Browserbase     ──► cloud browser (always fresh or saved)   │
│  △ CF Browser Run  ──► cloud browser (always remote)           │
└───────────────────────────────────────────────────────────────────┘
```

### Detailed: How Each Tool Handles Session Connection

#### ★ Chrome DevTools MCP — Best for "My Running Browser"

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

- **`--autoConnect`** (Chrome 146+ stable): Attaches to your already-running Chrome automatically. No flags, no port config.
- Sees **all your open tabs**, cookies, localStorage, extensions, logged-in sessions.
- Does **not** launch a new browser or open a new window.
- Requires **Chrome Beta** (or stable 146+ with `--autoConnect`).
- **Headed only** — it's controlling your visible browser. No headless mode.
- This is what "connect to my browser" means for most people.

→ [Setup guide](chrome-dev.md)

#### ★ Claude Computer Use — Best for "My Whole Desktop"

- Takes **screenshots of your actual screen**, controls mouse/keyboard.
- Works with **whatever browser you have open** — Chrome, Firefox, Safari, Edge.
- Also controls **other apps** — not just a browser.
- Always **headed** (it sees your real desktop).
- No CDP needed — it's pure screenshot → LLM → action.
- Expensive per action, but zero setup friction.

#### ◆ Puppeteer — Connect via CDP WebSocket

```javascript
const puppeteer = require('puppeteer-core');
// Connect to Chrome launched with --remote-debugging-port=9222
const browser = await puppeteer.connect({
  browserWSEndpoint: 'ws://localhost:9222/devtools/browser/xxx',
});
// See existing tabs!
const pages = await browser.pages();
// Open new tab in SAME browser instance
const page = await browser.newPage();
```

**⚠️ Chrome 136+ critical caveat:** `--remote-debugging-port` is **ignored on your default profile**.

**Prerequisites (Chrome 136+):**
1. Kill all Chrome processes first (existing instance swallows the flag silently)
2. Launch Chrome with **both** flags:
   ```bash
   # macOS
   "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
     --remote-debugging-port=9222 \
     --user-data-dir=/tmp/chrome-debug-profile
   ```
3. Use `puppeteer-core` (not full `puppeteer`, which downloads its own Chromium)
4. Connect via WebSocket URL from `http://localhost:9222/json/version`

**What you get (and what you DON'T):**
- ✅ Can interact with **existing tabs** or open **new tabs** in the same browser
- ✅ Both **headed and headless** (headless if Chrome was launched headless)
- ✅ Full CDP access for network, performance, security
- ❌ **NOT your cookies/logins** — the `--user-data-dir` points to a separate profile
- ❌ Must kill your daily Chrome first (can't attach to a running instance)
- ⚠️ Chrome shows "browser is being controlled by automated test software" banner

**Bottom line:** This works great for automation/scraping/CI where you don't need personal sessions. It does **NOT** give you "control my logged-in Gmail." For that, use TIER 1.

**MCP server:** `@anthropic-ai/puppeteer-mcp` supports `connect` mode via CDP endpoint config.

#### ◆ Playwright — Connect via CDP

```javascript
const { chromium } = require('playwright');
// Connect to Chrome launched with --remote-debugging-port=9222
const browser = await chromium.connectOverCDP('http://localhost:9222');
// Get existing contexts/pages
const contexts = browser.contexts();
const page = contexts[0].pages()[0];
```

**⚠️ Same Chrome 136+ limitation as Puppeteer:** requires `--user-data-dir` pointing away from default.

**What you get (and what you DON'T):**
- ✅ Same browser instance, can see and control existing tabs
- ✅ Both **headed and headless**
- ✅ Playwright's auto-waiting and locators work on connected pages too
- ❌ **NOT your cookies/logins** — separate profile via required `--user-data-dir`
- ⚠️ Slightly more verbose API than Puppeteer's `puppeteer.connect()`
- ⚠️ Some features may not apply to pre-existing contexts

**For your actual sessions:** Use `--autoConnect` (DevTools MCP) instead.

**MCP server:** `@playwright/mcp` supports connecting to existing CDP endpoints.

#### ◆ browser-use (Python)

- Uses **Playwright under the hood** → inherits `connect_over_cdp()` capability.
- Also supports **Puppeteer as backend** → inherits `connect()` via CDP.
- Subject to the **same Chrome 136+ limitation**: CDP connect only works with `--user-data-dir` pointing to a non-default directory.
- Configurable in agent setup:

```python
from browser_use import Agent
from playwright.async_api import async_playwright

async def main():
    pw = await async_playwright().start()
    # Connects to Chrome launched with --user-data-dir=/tmp/some-dir
    browser = await pw.chromium.connect_over_cdp("http://localhost:9222")
    agent = Agent(task="...", browser=browser)
    await agent.run()
```

- **Note:** The [browser-use issue #1520](https://github.com/browser-use/browser-use/issues/1520) tracks this Chrome 136 breakage. Workarounds discussed include symlinks and profile copying — but these are fragile.

#### △ rodney — Own Browser Only

```bash
# ALWAYS launches its own Chrome instance
rodney start        # ← new headless Chrome process
rodney start --show  # ← new visible Chrome process
rodney open https://example.com  # navigates in rodney's browser
rodney stop         # ← kills it
```

- ❌ **Cannot connect to existing Chrome.** Always launches its own process.
- But: **persistent within a session** — cookies/state survive across CLI calls until `rodney stop`.
- Supports **both headed (`--show`) and headless** (default).
- Sessions are isolated: global (`~/.rodney/`) or local (`./.rodney/` with `--local`).
- Workaround for existing session: not possible today. Would need CDP connect feature added.

#### △ agent-browser — Own Browser Only

```bash
agent-browser install   # downloads its own Chrome for Testing
agent-browser open https://example.com  # launches it
agent-browser close
```

- ❌ **Cannot connect to existing Chrome.** Runs its own downloaded Chrome for Testing.
- Has a **debug dashboard at localhost:4848** for headed inspection.
- Default **headless**, but dashboard provides visibility into state.
- State can be **saved/restored** (`state save/load`) across runs — but within its own browser, not yours.

#### △ CloakBrowser — Own Stealth Browser Only (with profile-import workarounds)

```python
from cloakbrowser import launch
browser = launch(headless=True, humanize=True)  # always a new stealth Chromium
```

**Direct connect to existing Chrome (`puppeteer.connect()` style): ❌ No.**

CloakBrowser's `launch()` always starts its own patched Chromium. It is **not** a drop-in for `puppeteer.connect()` or `connectOverCDP()`.

**Why by design:** connecting to an existing browser defeats the purpose — any browser you've used has accumulated fingerprint data, cookies, and behavioral signals that the stealth binary exists to eliminate. CloakBrowser is a clean-room stealth tool.

**Can you "clone" your Chrome profile into CloakBrowser? Verified from official README:**

CloakBrowser supports Playwright's `launch_persistent_context(user_data_dir=...)`, so you *can* point it at any directory. The README explicitly notes:

> *"Load Chrome extensions (extensions only work from a real user data dir)"*

The naive approach (copy profile → point at copy):

```python
import shutil
from cloakbrowser import launch_persistent_context

# 1. Copy your Chrome profile somewhere
shutil.copytree(
    "~/Library/Application Support/Google/Chrome",
    "/tmp/cloak-profile-copy"
)
# 2. Point CloakBrowser at the copy
browser = launch_persistent_context(user_data_dir="/tmp/cloak-profile-copy")
```

**This will fail for cookies and passwords.** Chrome 136+ uses **App-Bound Encryption** which ties the encryption key to the OS user account AND the specific profile path. Per [Chromium issue #394919677](https://issues.chromium.org/issues/394919677):

> *"App-Bound Encryption will be changed to not decrypt data if a custom `--user-data-dir` is used."*

The StackOverflow community has [documented this](https://stackoverflow.com/questions/79616855/selenium-chrome-136-failed-to-decrypt-errors-with-copied-profile-prevent-us) as "Failed to decrypt" errors. This is intentional — it's the same security layer that broke `--remote-debugging-port` on default profiles.

**What actually works for transferring sessions (verified from README):**

| Method | Works? | Notes |
|--------|--------|-------|
| Copy entire `user_data_dir` | ❌ | Cookies/passwords encrypted, can't decrypt in new location |
| Symlink `user_data_dir` | ⚠️ flaky | Chrome 136+ detects and may block |
| **`storage_state` (Playwright JSON export/import)** | ✅ | Officially supported. Export cookies+localStorage as plain JSON, re-import via `launch_context(storage_state="state.json")` |
| **Re-login manually** | ✅ | Painful but reliable |
| **CloakBrowser `launch_persistent_context("./my-profile")`** | ✅ | CloakBrowser's own persistent profile (NOT your Chrome's) |
| **CloakBrowser Browser Profile Manager** (new profile) | ✅ | Fresh persona, persistent cookies within CloakBrowser |

The `storage_state` approach is the most practical and officially supported:

```python
# Step 1: Export from your real Chrome (using Playwright on your real profile)
from playwright.sync_api import sync_playwright
with sync_playwright() as p:
    browser = p.chromium.launch_persistent_context(
        user_data_dir="~/Library/Application Support/Google/Chrome",
        # ... your config
    )
    context = browser  # it's the context
    context.storage_state(path="/tmp/my-chrome-state.json")
    browser.close()

# Step 2: Import into CloakBrowser (officially documented pattern)
from cloakbrowser import launch_context

context = launch_context(storage_state="/tmp/my-chrome-state.json")
page = context.new_page()
page.goto("https://example.com")  # Your cookies + localStorage are now loaded
context.close()
```

**Caveats:**
- `storage_state` only carries cookies + localStorage — not passwords, autofill, history, or extensions
- Cookies that are bound to specific fingerprint data (some session tokens, Cloudflare cf_clearance, etc.) may still get rejected
- You'll need to keep re-exporting as your real Chrome sessions refresh
- For persistent use, save state back: `context.storage_state(path="/tmp/my-chrome-state.json")`

**The Browser Profile Manager workaround** (managed by CloakBrowser, not your Chrome):

```bash
docker run -p 8080:8080 -v cloakprofiles:/data cloakhq/cloakbrowser-manager
# Open localhost:8080 → create profile → set fingerprint + proxy → launch
```

| Feature | What you get |
|---------|-------------|
| Persistent cookies & sessions | ✅ **yes** (per profile) |
| Unique fingerprints per profile | ✅ yes |
| Proxy per profile | ✅ yes |
| noVNC in-browser view | ✅ yes (headed visibility) |
| Self-hosted in Docker | ✅ yes |
| Open source (MIT) | ✅ yes |

This gives you CloakBrowser-managed persistent sessions, but **not your actual Chrome's cookies**. You log in once in the managed profile, and the cookies persist there.

| | Multilogin | GoLogin | AdsPower | **CloakBrowser Manager** |
|---|---|---|---|---|
| Price | $29–199/mo | $24–199/mo | Free–$50/mo | **Free** |
| Self-hosted | ❌ | ❌ | ❌ | ✅ |
| Fingerprints | JS injection | JS injection | Proprietary | ✅ **C++ source patches** |
| Open source | ❌ | ❌ | ❌ | ✅ Wrapper MIT |
| Data location | Their cloud | Their cloud | Local + cloud sync | ✅ **Your machine** |

**If you want persistence but don't need your real Chrome session, this is the cleanest path.**

Supports **both headed and headless** modes natively.

#### △ Cloud Tools (Browserbase, CF Browser Run) — Remote Only

- ❌ These run browsers **in the cloud**. No concept of "your local Chrome."
- Browserbase supports **session save/restore** in the cloud — but it's their cloud browser, not yours.
- Useful when you want zero local dependencies, not when you want to control your existing browser.

---

### Summary Table: Session Connection

| Tool | Connect to YOUR Chrome (your cookies/logins)? | How | Headed? | Headless? |
|------|------------------------------------------|-----|---------|-----------|
| **Chrome DevTools MCP** | ✅ **YES** (only way via CDP) | `--autoConnect` (Chrome 146+) | ✅ controls your browser | ❌ headed only |
| **Claude Computer Use** | ✅ **YES** (desktop-level) | screenshots of your screen | ✅ always | ❌ always headed |
| **Puppeteer / MCP** | ⚠️ **SEPARATE profile only** | `puppeteer.connect()` + `--user-data-dir` | ✅ | ✅ |
| **Playwright / MCP** | ⚠️ **SEPARATE profile only** | `connectOverCDP()` + `--user-data-dir` | ✅ | ✅ |
| **browser-use** | ⚠️ **SEPARATE profile only** | via Playwright/Puppeteer backend | ✅ | ✅ |
| **rodney** | ❌ own browser only | `rodney start` | ✅ `--show` | ✅ default |
| **agent-browser** | ❌ own browser only | `agent-browser install` | dashboard | ✅ default |
| **CloakBrowser** | ❌ own browser only | `launch(headless=False)` | ✅ | ✅ default |
| **Browserbase MCP** | ❌ cloud only | cloud session | cloud view | ✅ |
| **CF Browser Run** | ❌ cloud only | cloud session | cloud view | ✅ |

> **⚠️ Chrome 136+ (March 2025):** `--remote-debugging-port` on the default profile is **blocked for security**. Puppeteer/Playwright/browser-use CDP connect now requires a separate `--user-data-dir`, which means a blank profile. **Only Chrome DevTools MCP (`--autoConnect`) and Claude Computer Use can access your real browser sessions.**

### Decision: Which Connection Mode Do You Need?

```
I want to control MY browser (my cookies, my logins, my open tabs):
│
│  ⚠️ As of Chrome 136+, there are only TWO ways:
│
│  ├─► Chrome DevTools MCP + --autoConnect  (Chrome 146+ stable)
│  │   Enable once in chrome://inspect/#remote-debugging.
│  │   That's it. Your agent sees your real browser.
│  │   [BEST OPTION for most people]
│  │
│  └─► Claude Computer Use
│      Screenshots of your desktop. Controls any browser/app.
│      Expensive per action, but zero setup.
│
───────────────────────────────────────────────────────────────

I want to control A Chrome browser (but don't need my personal sessions):
│
│  ├─► Puppeteer MCP   [simplest CDP connect API]
│  ├─► Playwright MCP  [if you also need cross-browser]
│  ├─► rodney          [simplest CLI, no CDP needed]
│  └─► agent-browser   [best token efficiency]
│
│  All of these launch or connect to an isolated browser.
│  Great for scraping, testing, automation, CI/CD.
│
───────────────────────────────────────────────────────────────

I want anti-detect / bot evasion:
│
│  └─► CloakBrowser  [stealth Chromium, 30/30 detection pass]
│
───────────────────────────────────────────────────────────────

I want cloud-hosted (no local Chrome install):
│
│  ├─► Browserbase MCP     [natural language actions]
│  └─► CF Browser Run    [edge network]
```

---

## 1. rodney

**What:** Headless Chrome from the terminal. One persistent process — cookies/state survive across calls. Built in this repo.

```bash
uv tool install rodney
rodney start && rodney open https://example.com && rodney text "h1" && rodney stop
```

### Strengths
- ✅ Pure CLI — no daemon, no MCP, just bash calls
- ✅ Built-in assertions (`exists`, `visible`, `count`, `assert`) — great for CI
- ✅ Accessibility tree (`ax-tree`, `ax-find`, `ax-node`)
- ✅ PDF export, element screenshots, form filling, file downloads
- ✅ Session isolation (`--local` for per-project state)
- ✅ Visible mode (`--show`) for debugging
- ✅ 32 tests in our test suite

### Weaknesses
- ❌ CSS selectors only (no XPath, no semantic locators)
- ❌ No network interception or request/response inspection
- ❌ No batch mode — each call is a separate CLI invocation
- ❌ JS evaluation is single-line only
- ❌ Heavy SPAs can timeout on click/input

### Best for
Scraping, screenshots, form automation, accessibility audits, CI smoke tests.

### Links
- Setup → [guides/rodney-setup.md](rodney-setup.md)
- Full skill → [skills/rodney/SKILL.md](../skills/rodney/SKILL.md)
- Tests → `bash tests/rodney/test.sh`

---

## 2. Chrome DevTools MCP

**What:** MCP server that connects to a running Chrome Beta instance. ~29 tools for live browser inspection, debugging, performance traces.

```json
{
  "mcpServers": {
    "chrome-devtools": {
      "command": "npx",
      "args": ["-y", "chrome-devtools-mcp@latest", "--autoConnect", "--channel=beta"]
    }
  }
}
```

### Strengths
- ✅ Inspects a **real browser** you're actively using — see what you see
- ✅ Rich toolset (~29 tools): DOM snapshots, network, performance traces, console
- ✅ Screenshots of the actual visible page
- ✅ `--slim` mode for faster startup with fewer tools
- ✅ Lazy-loaded — connects on demand, auto-disconnects after 10 min idle

### Weaknesses
- ❌ Requires Chrome **Beta** installed and running first
- ❌ Tied to one browser session — can't spin up clean instances easily
- ❌ No built-in assertions or test primitives
- ❌ Not ideal for automated pipelines (needs human to have browser open)

### Best for
Debugging, inspecting a live session, "what's on my screen right now" workflows.

### Links
- Setup → [guides/chrome-dev.md](chrome-dev.md)
- Package → [`chrome-devtools-mcp`](https://github.com/anthropics/chrome-devtools-mcp) (Anthropic)

---

## 3. agent-browser (Vercel Labs)

**What:** Rust CLI + daemon. Token-efficient a11y-tree snapshots with `@ref` element IDs. Designed specifically for AI agent loops. **Best-in-class for session reuse.**

```bash
brew install agent-browser
agent-browser install          # downloads Chrome for Testing
agent-browser open https://example.com
agent-browser snapshot -i     # interactive a11y tree with @ref IDs
agent-browser close
```

### Strengths
- ✅ **A11y-tree snapshots** with `@ref` IDs — ~50 tokens per snapshot (very cheap)
- ✅ Semantic locators (`find --role`, `find --text`, `find --label`) — no CSS needed
- ✅ Network interception (`network route`, `network capture`)
- ✅ Batch mode — chain multiple actions in one call
- ✅ Diff support (`diff snapshot`, `diff screenshot`)
- ✅ **Chrome profile import** — `--profile "Default"` copies your Chrome profile to a temp dir (read-only snapshot) and launches with your cookies/sessions
- ✅ **State import from running Chrome** — `--auto-connect state save` connects to Chrome and saves auth state to JSON
- ✅ **Session persistence** — `--session-name myapp` auto-saves/restores state across restarts
- ✅ **State encryption** — AES-256-GCM with `AGENT_BROWSER_ENCRYPTION_KEY` env var
- ✅ Rust daemon — fast, low memory, no Node.js runtime
- ✅ Debug dashboard at `localhost:4848`

### Session Reuse Features (the most important)

agent-browser has the **most complete session-reuse story** of any tool in this comparison:

```bash
# 1. Reuse your existing Chrome profile (read-only snapshot, temp dir)
agent-browser --profile Default open https://gmail.com
agent-browser --profile "Work" open https://app.example.com

# 2. Import auth from your running Chrome
# ⚠️ Chrome 136+ (current stable 149): --remote-debugging-port on default profile is BLOCKED.
#    You MUST use --user-data-dir pointing to a non-default directory (clean profile).
#    If you need your actual Chrome session: use Chrome DevTools MCP --autoConnect (Tier 1) instead,
#    or agentauth-py to decrypt + import cookies.
chrome --remote-debugging-port=9222 --user-data-dir=/tmp/agent-debug-profile
agent-browser --auto-connect state save ./my-auth.json
agent-browser --state ./my-auth.json open https://app.example.com/dashboard

# 3. Persistent sessions (auto-save/restore)
agent-browser --session-name myapp open https://example.com
# From now on, state auto-saves/restores for "myapp"

# 4. Encrypted state
export AGENT_BROWSER_ENCRYPTION_KEY=$(openssl rand -hex 32)
agent-browser --session-name secure-session open example.com
```

> **Note on `--profile` + Chrome 136+:** the `--profile` flag copies your Chrome's profile to a temp dir. With App-Bound Encryption (Chrome 136+), this **may not decrypt cookies/passwords** in some scenarios. For reliable auth transfer, use `--auto-connect state save` (works against your real running Chrome) or the `--state <file>` import flow.

### Weaknesses
- ❌ No built-in assertion/test primitives
- ❌ `--profile` has known bug with active page loss (avoid on Windows while Chrome running)
- ❌ Windows ARM64 broken as of 0.25.x
- ❌ Requires daemon running (vs rodney's fire-and-forget CLI)
- ❌ Newer project — less battle-tested than rodney

### Best for
Agent loops where token cost matters, complex interactions needing semantic locators, network-level work, **and any workflow that needs to reuse your Chrome sessions**.

### Links
- Setup → [guides/vcl-agent-browser.md](vcl-agent-browser.md)
- Sessions guide → [agent-browser.dev/sessions](https://agent-browser.dev/sessions)
- Repo → [vercel-labs/agent-browser](https://github.com/vercel-labs/agent-browser)

---

## 4. CloakBrowser

**What:** Stealth Chromium that passes bot detection. Drop-in Playwright replacement with source-level C++ fingerprint patches (42 patches). Tested in this repo's testbed against FingerprintJS, BrowserScan, PixelScan, Cloudflare, and more.

```python
from cloakbrowser import launch

browser = launch(headless=True, humanize=True)
page = browser.new_page()
page.goto("https://example.com")
# Passes navigator.webdriver, plugins, chrome runtime checks
browser.close()
```

### Strengths
- ✅ **30/30 bot detection tests passed** — FingerprintJS, PixelScan, BrowserScan, etc.
- ✅ Source-level C++ patches (not JS injection or config tricks)
- ✅ Drop-in Playwright replacement — same API
- ✅ **Humanize mode**: Bézier-curve mouse movements, natural typing cadence, realistic scroll physics with overshoot/settle
- ✅ **Session persistence** across launches
- ✅ **Cloudflare bypass** tested and working
- ✅ MIT wrapper license, free binary

### Weaknesses
- ❌ Custom Chromium binary (not system Chrome) — larger download (~200 MB)
- ❌ Python-only API (no CLI or MCP layer)
- ❌ Newer project — less community than Playwright
- ❌ Proprietary binary license (wrapper is MIT)
- ❌ No built-in agent/LLM integration — it's a browser lib, not an agent framework

### Best for
Scraping protected sites, anti-detect needs, Cloudflare challenges, any workflow where bot detection blocks standard headless Chrome.

### Links
- Repo → [CloakHQ/CloakBrowser](https://github.com/CloakHQ/CloakBrowser)
- PyPI → [`cloakbrowser`](https://pypi.org/project/cloakbrowser/)
- Docs → [cloakbrowser.dev](https://cloakbrowser.dev/)
- Our test suite → [testbed/cloakbrowser/](../testbed/cloakbrowser/) (stealth, humanize, Cloudflare, session tests)

---

## 5. Playwright MCP

**What:** Official Microsoft Playwright as an MCP server. Supports Chromium, Firefox, WebKit. The de facto standard for browser automation.

```json
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["-y", "@playwright/mcp@latest"]
    }
  }
}
```

### Strengths
- ✅ **Cross-browser** — Chromium, Firefox, WebKit
- ✅ Auto-waiting on elements (smart retries, no arbitrary sleeps)
- ✅ Trace viewer for deep debugging
- ✅ Codegen — record actions → generate code
- ✅ Massive ecosystem and community
- ✅ Visual regression testing built-in
- ✅ Accessibility snapshots (token-efficient, like agent-browser)
- ✅ Console logs + network request inspection via MCP tools
- ✅ Docker image available: `mcr.microsoft.com/playwright/mcp`

### Weaknesses
- ❌ Heaviest install (downloads all 3 browser engines)
- ❌ Node.js dependency
- ✅ More general-purpose — not tuned for agent token efficiency like agent-browser
- ❌ No stealth/anti-detect by default (pair with CloakBrowser for that)
- ❌ Docker version is headless-Chromium only

### Best for
Cross-browser testing, teams already using Playwright, visual regression testing, reliable default choice for most developers.

### Links
- Package → [`@playwright/mcp`](https://github.com/microsoft/playwright-mcp)
- Docs → [playwright.dev](https://playwright.dev/)
- Comparison article → [Webfuse: Top 5 MCP Servers for Browser Automation 2026](https://www.webfuse.com/blog/the-top-5-best-mcp-servers-for-ai-agent-browser-automation)

---

## 6. browser-use

**What:** Open-source Python framework for building AI agents that control browsers. 96k+ GitHub stars. Uses LLMs to decide what actions to take on a page. Optimized `ChatBrowserUse()` completes tasks 3–5× faster than generic models.

```python
from browser_use import Agent
import asyncio

async def main():
    agent = Agent(
        task="Find the price of a MacBook Pro on apple.com",
        llm=your_llm,
    )
    result = await agent.run()
    print(result)

asyncio.run(main())
```

### Strengths
- ✅ **Full agent framework** — not just a browser driver, includes LLM loop, memory, planning
- ✅ **96k+ GitHub stars** — largest community of any browser agent tool
- ✅ Python-native — fits ML/AI workflows naturally
- ✅ `ChatBrowserUse()` model optimized for browser tasks (3–5× faster)
- ✅ Works with Bright Data Scraping Browser for anti-detect
- ✅ Persistent sessions, cookie management
- ✅ MCP server mode available (`browser-use-mcp-server`)
- ✅ Interactive dashboard for monitoring agent runs

### Weaknesses
- ❌ Heavy dependency chain (Playwright + LLM provider + browser)
- ❌ Token-hungry — each step sends page context to LLM
- ❌ Overkill for simple scraping (use rodney instead)
- ❌ Python only — no CLI-first or Rust option
- ❌ Cost adds up with LLM API calls per action

### Best for
Complex multi-step web tasks where an LLM needs to make decisions ("book a flight under $500", "fill out this form based on a PDF").

### Links
- Repo → [browser-use/browser-use](https://github.com/browser-use/browser-use) (96k+ ⭐)
- Docs → [docs.browser-use.com](https://docs.browser-use.com/)
- Guide → [Bright Data: Build AI Agents with browser-use](https://brightdata.com/blog/ai/browser-use-with-scraping-browser)
- Comparison → [Labellerr: Browser-Use Open-Source AI Agent](https://www.labellerr.com/blog/browser-use-agent/)

---

## 7. Claude Computer Use (Anthropic)

**What:** Anthropic's native tool that lets Claude control your computer desktop — browse the web, click buttons, type, use apps. Achieves SOTA on WebArena benchmark among single-agent systems. Available as API tool and as Claude Code / Claude in Chrome.

```python
import anthropic

client = anthropic.Anthropic()
message = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    tools=[{"type": "computer_20251101", "display_width_px": 1024, "display_height_px": 768}],
    messages=[{"role": "user", "content": "Search for a recipe and save it to a file"}],
)
```

### Strengths
- ✅ **SOTA on WebArena** benchmark — best-in-class single-agent web navigation
- ✅ Native Claude integration — no extra setup if you're already using Anthropic
- ✅ **Desktop-level control** — not just browser, any app on screen
- ✅ Available in Claude Code, Claude in Chrome extension, and API
- ✅ Handles dynamic sites, CAPTCHAs (sometimes), complex UI patterns
- ✅ Screenshot-based — sees what a human sees

### Weaknesses
- ❌ **Anthropic-only** — locked to Claude models
- ❌ Expensive — every action is an API call with tokens in/out (screenshots are large)
- ❌ No programmatic selectors — relies on visual understanding (can miss small elements)
- ❌ Latency — screenshot roundtrip per action
- ❌ Hard to integrate into non-Anthropic pipelines
- ❌ No offline/local mode — always needs API

### Best for
Claude-based agents that need general computer use, prototyping automation tasks quickly, tasks where visual understanding matters more than precise DOM access.

### Links
- Docs → [Anthropic Computer Use Tool](https://platform.claude.com/docs/en/agents-and-tools/tool-use/computer-use-tool)
- Review → [Claude In Chrome Review 2026](https://aitoolanalysis.com/claude-in-chrome-review/)
- Comparison → [Computer Use Agents 2026: Claude vs OpenAI vs Gemini](https://www.digitalapplied.com/blog/computer-use-agents-2026-claude-openai-gemini-matrix)
- Benchmark → [WebArena results](https://platform.claude.com/docs/en/agents-and-tools/tool-use/computer-use-tool)

---

## 8. Browserbase MCP

**What:** Cloud-hosted browser automation with Stagehand integration. Agents use natural language instructions ("click Sign Up") instead of selectors. Runs browsers remotely — nothing local to install except the MCP client.

```json
{
  "mcpServers": {
    "browserbase": {
      "command": "npx",
      "args": ["-y", "@browserbasehq/mcp-server-browserbase"],
      "env": {
        "BROWSERBASE_API_KEY": "YOUR_KEY"
      }
    }
  }
}
```

### Strengths
- ✅ **Fully cloud-hosted** — no local browser installation or maintenance
- ✅ **Natural language actions** — `"click the sign-up button"` vs CSS selectors
- ✅ Stagehand-powered extraction — pulls structured data without predefined schema
- ✅ **Stealth options** on some plans (anti-detect features)
- ✅ Scales horizontally — run many concurrent sessions
- ✅ Session recording and live debug view

### Weaknesses
- ❌ **Paid service** — API costs add up at scale
- ❌ Depends on external infrastructure (latency, uptime)
- ❌ Requires API key + account setup
- ❌ Default Stagehand model is Gemini (configurable but another dependency)
- ❌ Overkill for simple local tasks

### Best for
Teams needing cloud scale, avoiding local browser management, natural-language-first agent workflows.

### Links
- Repo → [browserbase/mcp-server-browserbase](https://github.com/browserbase/mcp-server-browserbase)
- Web → [browserbase.com](https://www.browserbase.com/)
- Comparison → [Webfuse: Top 5 MCP Servers](https://www.webfuse.com/blog/the-top-5-best-mcp-servers-for-ai-agent-browser-automation)

---

## 9. Cloudflare Browser Run

**What:** Cloudflare's browser-in-the-cloud offering exposed as MCP. Leverages Cloudflare's global network for low-latency browser sessions. New as of April 2026.

### Strengths
- ✅ Runs on **Cloudflare's edge network** — low latency globally
- ✅ MCP client support — works with Claude Desktop, Cursor, OpenCode
- ✅ No local browser needed
- ✅ Cloudflare-scale reliability and infrastructure
- ✅ Good fit if you're already on Cloudflare stack

### Weaknesses
- ❌ Very new (April 2026) — limited docs and community
- ❌ Cloudflare ecosystem lock-in
- ❌ Pricing model still evolving
- ❌ Less feature-rich than Browserbase for now

### Best for
Cloudflare Shops users, global-deployed agents needing edge browsers, experiments with cloud browser MCP.

### Links
- Blog → [Cloudflare: Browser Run for AI Agents](https://blog.cloudflare.com/browser-run-for-ai-agents/)

---

## 10. Puppeteer MCP

**What:** Google's browser automation library (since 2017) exposed as an MCP server. Chromium-focused with deep CDP access. The original browser automation tool that inspired Playwright (same creator at Microsoft). Multiple MCP server implementations available.

```json
{
  "mcpServers": {
    "puppeteer": {
      "command": "npx",
      "args": ["-y", "@anthropic-ai/puppeteer-mcp"]
    }
  }
}
```

> **Note:** The official Puppeteer team now ships a Puppeteer MCP server (`@anthropic-ai/puppeteer-mcp`). Community alternatives exist (e.g., `Xandon/puppeteer-mcp-server` with more tools).

### Strengths
- ✅ **Deep CDP access** — `page.createCDPSession()` for raw Chrome DevTools Protocol control
- ✅ **Lightweight** — smaller install than Playwright (Chromium only, no Firefox/WebKit binaries)
- ✅ **Mature** — since 2017, massive community, battle-tested
- ✅ **Google-backed** — tight integration with Chrome internals, service workers, shadow DOM
- ✅ **Fast for Chromium tasks** — screenshots, PDF generation, scraping
- ✅ **Network interception** — request/response mocking, proxy support
- ✅ **Multiple MCP servers** — official + community options
- ✅ Now supports **Firefox** (via WebDriver BiDi), not just Chromium

### Weaknesses
- ❌ **Chromium-first** — Firefox support is inferior to Playwright's; no WebKit
- ❌ **JavaScript/TypeScript only** — no Python, Java, or .NET bindings
- ❌ **Manual waits** — auto-waiting exists but less refined than Playwright's actionability checks
- ❌ **No cross-browser parity** — APIs behave differently across browsers
- ❌ **No built-in trace viewer** — debugging is more manual than Playwright
- ❌ **Some MCP servers are deprecated** in favor of Playwright MCP — check freshness

### Best for
Chromium-only workflows, CDP-heavy instrumentation, teams already invested in Chrome ecosystem, lightweight browser automation where you don't need Firefox/WebKit.

### Links
- Official MCP → [`@anthropic-ai/puppeteer-mcp`](https://github.com/anthropics/puppeteer-mcp)
- Community MCP → [Xandon/puppeteer-mcp-server](https://github.com/Xandon/puppeteer-mcp-server)
- Core lib → [pptr.dev](https://pptr.dev/) · [github.com/puppeteer/puppeteer](https://github.com/puppeteer/puppeteer) (88k+ ⭐)
- Setup guide → [MCP Puppeteer Server Setup 2026](https://markaicode.com/mcp-puppeteer-server-browser-automation-claude/)

---

## 11. Browser Session Management Tools (Specialized)

> A new class of tools focused specifically on **browser session reuse** — not full browser automation, but solving the "I want my cookies/login state across tools" problem.

These don't fit neatly into the "compare browsers" table above, so they get their own section.

### 11.1 agentauth-py — Chrome Cookie Vault

**What:** Python SDK that reads & decrypts cookies from your actual Chrome's cookie database (defeats App-Bound Encryption on macOS/Linux). Stores them in an encrypted vault. Plug into Playwright/requests/LangChain/n8n.

```bash
pip install agentauth-py
agent-auth grab linkedin.com        # grabs LinkedIn cookies from your Chrome
# Cookies now stored in encrypted vault

from agent_auth import Vault
vault = Vault()
cookies = vault.get_session("linkedin.com")

# Use with Playwright
from playwright.sync_api import sync_playwright
with sync_playwright() as p:
    browser = p.chromium.launch()
    context = browser.new_context()
    context.add_cookies(cookies)
    page = context.new_page()
    page.goto("https://linkedin.com/feed")  # Already authenticated!
```

### Strengths
- ✅ **Defeats Chrome 136+ App-Bound Encryption** (reverse-engineered on macOS/Linux)
- ✅ Multi-profile support (`--profile "Work"`)
- ✅ Encrypted vault storage (AES-256)
- ✅ Export/import for syncing to remote servers (scp-friendly)
- ✅ LangChain, n8n, Playwright integrations built-in
- ✅ Works with **requests** (no browser needed for API calls)
- ✅ MIT licensed
- ✅ Full audit logging

### Weaknesses
- ❌ macOS/Linux only (Windows DPAPI is harder — would need a different approach)
- ❌ 3rd-party tool, not a "browser" itself — needs another tool to use the cookies
- ❌ Cookies will go stale as your real Chrome session changes
- ❌ Some fingerprint-bound cookies (Cloudflare cf_clearance) may still get rejected

### Best for
Anyone who wants to **reuse their real Chrome sessions** with Playwright/Puppeteer/requests without launching their own browser. Solves the Chrome 136 encryption problem.

### Links
- PyPI → [`agentauth-py`](https://pypi.org/project/agentauth-py/)
- How it works → [Reverse-Engineering Chrome's Cookie Encryption](https://dev.to/jacobgadek/reverse-engineering-chromes-cookie-encryption-to-authenticate-ai-agents-212i)
- n8n node → [n8n-nodes-agentauth](https://www.npmjs.com/package/n8n-nodes-agentauth)

---

### 11.2 Hangwin mcp-chrome — Chrome Extension + Local Bridge

**What:** Chrome extension that runs in your real Chrome + a local Node.js bridge (`mcp-chrome-bridge`). Your AI agent connects to the bridge via MCP. **No need to launch a separate browser, no need for `--remote-debugging-port`.**

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

### Strengths
- ✅ **No debug port needed** — uses Chrome extension APIs (`chrome.tabs`, `chrome.debugger`)
- ✅ **Streams via HTTP/WebSocket** — survives MCP client restarts
- ✅ 23+ tools for browser control, network monitoring, content analysis
- ✅ LLM-optimized screenshots (strips irrelevant UI)
- ✅ Cross-tab management
- ✅ More stable than raw CDP connections
- ✅ ~6k+ GitHub stars, community mature

### Weaknesses
- ❌ Requires extension install + bridge process
- ❌ Chrome only (no Firefox/Safari)
- ❌ Extension not on Chrome Web Store (sideload from GitHub)
- ❌ Enterprise policies may block extension install
- ❌ Two processes to manage (extension + bridge)

### Best for
Anyone who wants session reuse **without the Chrome 136+ CDP complications** or command-line browser launches.

### Links
- Repo → [hangwin/mcp-chrome](https://github.com/hangwin/mcp-chrome)
- DeepWiki → [hangwin/mcp-chrome](https://deepwiki.com/hangwin/mcp-chrome)

---

### 11.3 Playwright MCP Bridge Extension (Microsoft)

**What:** Microsoft Playwright's official solution to the session-reuse paradox. Chrome extension that **manually authorizes** AI access to your current tab, then exposes the tab to Playwright MCP.

```json
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["-y", "@playwright/mcp@latest", "--extension"]
    }
  }
}
```

### Strengths
- ✅ **Perfect identity state preservation** — extension runs in your browser context, inherits all your cookies/localStorage/logins
- ✅ **Human-in-the-loop security** — you must click "Connect" in the extension popup to authorize
- ✅ Built on top of Playwright's robust framework
- ✅ No need to launch a separate browser
- ✅ Microsoft-maintained

### Weaknesses
- ❌ **Sideloading required** — not in Chrome Web Store, must download ZIP from GitHub Releases
- ❌ Manual authorization per session (deliberate security choice)
- ❌ Two-step setup (extension + MCP server)
- ❌ Enterprise policies may block sideloading
- ❌ One tab at a time typically

### Best for
Enterprise use cases, scenarios requiring human-in-the-loop authorization, anyone who needs to automate the exact tab they're looking at.

### Links
- Repo → [microsoft/playwright-mcp](https://github.com/microsoft/playwright-mcp) (with extension in releases)
- Setup guide → [MCP Browser Session Reuse: Complete Technical Guide 2026](https://onpiste.work/blogs/38-mcp-browser-session-reuse-guide)

---

### 11.4 YetiBrowser MCP — Local-First, Firefox-Aware

**What:** Open-source MCP server with extension-based session reuse. Emphasizes privacy, local data, and DOM diff for token efficiency.

### Strengths
- ✅ **DOM Snapshot Diff** — only sends page changes since last operation (huge token savings)
- ✅ **Cross-browser** — Chrome + Firefox (rare in MCP ecosystem)
- ✅ **Stealth by design** — reuses your real browser, fingerprint matches you perfectly
- ✅ Privacy-first: no telemetry, no cloud
- ✅ All data local

### Weaknesses
- ❌ Newer project, less battle-tested
- ❌ Firefox support experimental
- ❌ Smaller community

### Best for
Privacy-sensitive use cases, long-running agents where token cost matters, Firefox users.

### Links
- Listed in → [MCP Browser Session Reuse Guide](https://onpiste.work/blogs/38-mcp-browser-session-reuse-guide#yetibrowser-mcp)

---

### 11.5 Airtop — Cloud Browser with Native Auth

**What:** Cloud-hosted browser that handles session persistence, OAuth, and 2FA as first-class features. Integrates with n8n, Claude, and any MCP client.

### Strengths
- ✅ **Manages auth flows natively** — OAuth, 2FA, session persistence built in
- ✅ Cloud scale — many concurrent sessions
- ✅ MCP server mode
- ✅ n8n integration
- ✅ No local browser dependency

### Weaknesses
- ❌ Paid service
- ❌ Cloud-only (not your real browser)
- ❌ Less control than local tools

### Best for
Cloud-native agent workflows, OAuth-heavy APIs, when you want to offload auth management.

### Links
- Site → [airtop.ai](https://www.airtop.ai/)
- Comparison → [Browser Use vs Airtop 2026](https://www.skyvern.com/blog/browser-use-vs-airtop-which-is-better/)

---

### 11.6 AWS Bedrock AgentCore Browser — Cloud Browser with Profiles

**What:** AWS-managed cloud browser with persistent profiles, proxy config, and extension support. Announced Feb 2026.

### Strengths
- ✅ **Persistent browser profiles** — cookies/localStorage survive sessions
- ✅ **Proxy configuration** — stable egress IP for IP-bound sessions
- ✅ **Browser extensions** — load Chrome extensions into sessions
- ✅ AWS integration (Secrets Manager, IAM)
- ✅ Compliance certifications (FedRAMP, HITRUST, PCI)

### Weaknesses
- ❌ AWS-only (vendor lock-in)
- ❌ Cloud-only (not your real browser)
- ❌ Costs add up at scale

### Best for
Enterprise AWS workflows, compliance-sensitive use cases, IP-bound session requirements.

### Links
- AWS blog → [Customize AI agent browsing with proxies, profiles, extensions in Bedrock AgentCore](https://aws.amazon.com/blogs/machine-learning/customize-ai-agent-browsing-with-proxies-profiles-and-extensions-in-amazon-bedrock-agentcore-browser/)
- Docs → [Bedrock AgentCore Browser Tool](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/browser-tool.html)

---

### Session Management Tools Comparison

| Tool | Approach | Gets your real Chrome? | Encrypted? | Cost | Best for |
|------|----------|------------------------|------------|------|----------|
| **agentauth-py** | Decrypts Chrome cookies | ✅ **yes** (with macOS/Linux decryption) | ✅ AES-256 vault | Free | Plug into Playwright/requests/LangChain |
| **Hangwin mcp-chrome** | Extension + HTTP bridge | ✅ yes (extension runs in your Chrome) | N/A | Free | MCP clients wanting no debug port |
| **Playwright MCP Bridge** | Microsoft extension | ✅ yes (auth required) | N/A | Free | Enterprise, human-in-loop |
| **YetiBrowser MCP** | Extension + diff | ✅ yes | N/A (local-only) | Free | Token-efficient, Firefox |
| **Airtop** | Cloud browser | ❌ cloud | ✅ managed | Paid | OAuth/2FA workflows |
| **AWS Bedrock AgentCore** | Cloud browser | ❌ cloud | ✅ AWS-managed | AWS pricing | Enterprise AWS |
| **agent-browser** (built-in) | `--auto-connect state save` | ✅ yes | ✅ AES-256-GCM | Free | All-in-one solution |

---

## Playwright vs Puppeteer — Deep Dive

> The two foundational browser automation libraries compared specifically for **AI agent** use cases.

### At a Glance

| | **Playwright** | **Puppeteer** |
|---|---|---|
| Creator | Microsoft (2020) | Google (2017) |
| Browsers | Chromium, **Firefox**, **WebKit** | Chromium, **Firefox** (limited) |
| Languages | JS, TS, Python, Java, .NET | JS, TS only |
| GitHub stars | ~62k | **~88k** |
| Protocol | CDP + internal (Juggler/WDP) | **CDP-native** + BiDi (Firefox) |
| MCP server | `@playwright/mcp` (official) | `@anthropic-ai/puppeteer-mcp` (official) + community |
| Agent-friendliness | ⭐⭐⭐⭐ (auto-wait, locators, traces) | ⭐⭐⭐ (CDP power, manual tuning) |

### For AI Agents: Key Differences

#### 1. Reliability on Dynamic Pages

**Playwright wins here.** Its actionability checks (is element visible? overlapped? enabled? animated?) prevent the #1 cause of agent failures — clicking something that isn't ready.

```
// Playwright — auto-waits for element to be actionable
await page.getByRole('button', { name: 'Submit' }).click()
// ↑ Waits for: visible + enabled + not animated + not obscured

// Puppeteer — you manage timing
await page.waitForSelector('button[type="submit"]', { visible: true })
await page.click('button[type="submit"]')
// ↑ You must know what to wait for
```

For agents that generate actions from LLM output, Playwright's smart retries mean fewer failed steps per session.

#### 2. Browser Support

| | Playwright | Puppeteer |
|---|---|---|
| Chromium | ✅ first-class | ✅ **first-class (best)** |
| Firefox | ✅ first-class | ⚠️ via BiDi (limited) |
| WebKit (Safari) | ✅ first-class | ❌ no |
| Cross-browser tests | ✅ unified API | ❌ different code paths |

If your agent only touches Chromium, Puppeteer's deeper Chrome integration is an advantage. For anything cross-browser, it's Playwright by default.

#### 3. CDP Access & Protocol Control

**Puppeteer wins here.** It was built as a CDP client from day one.

```
// Puppeteer — raw CDP session, full protocol access
const client = await page.createCDPSession()
await client.send('Network.enable')
client.on('Network.responseReceived', ({ response }) => {
  console.log(`${response.url} → ${response.status}`)
})
```

Playwright can open CDP sessions on Chromium too, but it feels like an add-on. In Puppeteer, CDP is native.

#### 4. Observability & Debugging

| Feature | Playwright | Puppeteer |
|---|---|---|
| Trace Viewer | ✅ step-by-step replay | ❌ use DevTools manually |
| Codegen (record→code) | ✅ | ❌ |
| Inspector mode | ✅ interactive | partial (DevTools) |
| Video recording | ✅ built-in | manual setup |
| Screenshots on failure | ✅ automatic | manual |

For agent loops that fail on step 7 of 20, Playwright's Trace Viewer lets you replay exactly what happened. With Puppeteer, you're piecing together logs.

#### 5. Token Efficiency for LLMs

Neither ships with an agent-native page representation. Both return DOM/HTML/a11y data that needs preprocessing for LLMs:

- **Playwright**: accessibility snapshots are cleaner out of the box
- **Puppeteer**: you typically build your own extraction logic via `page.evaluate()` or CDP
- **Both**: worse than agent-browser's ~50-token `@ref` snapshots or rodney's CLI text output

**Bottom line:** If you're feeding page state to an LLM, add an abstraction layer on top of either one. Neither is purpose-built for token efficiency.

#### 6. Ecosystem & MCP Servers

| | Playwright | Puppeteer |
|---|---|---|
| Official MCP server | `@playwright/mcp` | `@anthropic-ai/puppeteer-mcp` |
| Community MCP servers | many | many (some deprecated) |
| Stealth plugins | `playwright-stealth`, `extra-stealth` | `puppeteer-extra-plugin-stealth` |
| Anti-detect pairing | CloakBrowser (Playwright-compatible) | CloakBrowser (Playwright-compatible) |
| Agent frameworks using it | browser-use, Browserbase Stagehand | fewer agent-specific integrations |

#### 7. Performance

For single-page interactions, they're nearly identical (both control Chromium via CDP). Differences show up at scale:

- **Puppeteer** has slightly lower overhead per page (smaller library, no cross-browser abstraction)
- **Playwright** handles parallel contexts more gracefully (better isolation ergonomics)
- For agent loops doing 1–100 steps: negligible difference
- For fleets running 1000+ concurrent sessions: Playwright's context management scales better

### Verdict

```
Choose Playwright if:
  ✅ You need Firefox or WebKit support
  ✅ Agent reliability matters more than raw CDP access
  ✅ You want traces, codegen, and integrated debugging
  ✅ You're using Python, Java, or .NET
  ✅ You run many parallel agent sessions

Choose Puppeteer if:
  ✅ You only target Chromium
  ✅ You need deep CDP / protocol-level control
  ✅ You want a lighter-weight install
  ✅ Your team already knows Puppeteer well
  ✅ You're building CDP-heavy tooling (network inspection, perf profiling)

For most AI agent projects in 2026:
  → Default to Playwright MCP
  → Drop down to Puppeteer MCP when you need Chromium-specific CDP power
```

### References

- [Webfuse: Playwright vs Puppeteer for AI Agent Control](https://www.webfuse.com/blog/playwright-vs-puppeteer-which-is-better-for-ai-agent-control) — agent-focused comparison
- [BrowserStack: Playwright vs Puppeteer 2026](https://www.browserstack.com/guide/playwright-vs-puppeteer) — comprehensive feature comparison
- [MorphLLM: Playwright vs Puppeteer 2026](https://www.morphllm.com/comparisons/playwright-vs-puppeteer) — benchmark-focused
- [ZenRows: Playwright vs Puppeteer](https://www.zenrows.com/blog/playwright-vs-puppeteer) — performance deep-dive
- [browser.ai: Which Framework Wins for AI Web Agents?](https://browser.ai/news/ai-agents/playwright-vs-puppeteer-which-framework-wins-for-ai-web-agents)
- [QA Skills: Playwright vs Puppeteer 2026 Deep Dive](https://qaskills.sh/blog/playwright-vs-puppeteer-2026-deep-dive)

---

## Feature Matrix

### Session Connection & Display (key axis)

| Feature | rodney | Chrome DevTools MCP | agent-browser | CloakBrowser | Playwright MCP | Puppeteer MCP | browser-use | Claude Comp. Use | Browserbase MCP | CF Browser Run |
|---------|--------|-------------------|---------------|-------------|----------------|-------------|-------------|-----------------|-----------------|----------------|
| **Connect existing Chrome** | ❌ | ✅ **autoConnect** | ❌ | ❌ | ⚠️ CDP (sep. profile) | ⚠️ CDP (sep. profile) | ⚠️ via backend | ✅ desktop | ❌ cloud | ❌ cloud |
| **Keeps your cookies/logins** | ❌ own sess | ✅ **yours** | ❌ own sess | ❌ own sess | ❌ **separate profile** | ❌ **separate profile** | ❌ **separate profile** | ✅ your screen | ❌ cloud only | ❌ |
| **Headed mode** | ✅ `--show` | ✅ **it IS your browser** | dashboard | ✅ `headless=False` | ✅ | ✅ | ✅ | ✅ always | cloud view | cloud view |
| **Headless mode** | ✅ default | ❌ | ✅ default | ✅ default | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ |
| **Both modes (switchable)** | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ |

### Full Feature Matrix

| Feature | rodney | Chrome DevTools MCP | agent-browser | CloakBrowser | Playwright MCP | browser-use | Claude Comp. Use | Browserbase MCP | CF Browser Run |
|---------|--------|-------------------|---------------|-------------|----------------|-------------|-----------------|-----------------|----------------|
| **Interface** | CLI (bash) | MCP tools | CLI (bash) | Python API | MCP tools | Python API | API tool | MCP tools | MCP tools |
| **Language** | Python | Node.js | Rust | Python | Node.js | Python | any (API) | Node.js (Stagehand) | — |
| **Browser** | Chrome/Chrm | Chrome Beta | Chrome Testing | Stealth Chrm | Ch/Fx/WK | Ch/Fx/WK | Desktop (any) | Cloud Chrome | Cloud Chrome |
| **Headless** | ✅ default | ❌ live only | ✅ default | ✅ default | ✅ default | ✅ default | ❌ screenshot | ✅ | ✅ |
| **Visible/debug** | ✅ `--show` | ✅ it IS your browser | ✅ dashboard | ✅ headed | ✅ | ✅ | ✅ it IS your screen | ✅ live view | ✅ |
| **Selectors** | CSS only | CSS / JS | A11y `@ref` + semantic | Playwright CSS/XPath | CSS + text + role | LLM-driven | visual (screenshot) | natural language | natural language |
| **A11y tree** | ✅ `ax-tree` | partial | ✅ core feature | via Playwright | ✅ core feature | via DOM | ❌ | via Stagehand | ? |
| **Stealth/anti-detect** | ❌ | ❌ | ❌ | **✅ 30/30 pass** | ❌ | via integr. | partial | ✅ (paid) | ✅ (CF infra) |
| **Humanize mode** | ❌ | ❌ | ❌ | **✅ Bézier mouse, typing physics** | ❌ | ❌ | implicit | ❌ | ❌ |
| **Screenshots** | page + el | viewport | page + el | ✅ | page + el full-page | ✅ | ✅ core (per step) | ✅ | ✅ |
| **PDF** | ✅ | ❌ | ✅ | via Playwright | ✅ | ✅ | ❌ | ❌ | ❌ |
| **Form fill** | ✅ | manual JS | ✅ | ✅ | ✅ | ✅ | ✅ (visual) | ✅ | ✅ |
| **Assertions** | ✅ built-in | ❌ | ❌ | ❌ | via expect | custom | ❌ | ❌ | ❌ |
| **Network intercept** | ❌ | ✅ | ✅ | via Playwright | ✅ | via Playwright | ❌ | ✅ | ✅ |
| **Batch/chain** | ❌ | ❌ | ✅ | via scripts | ✅ (scripts) | ✅ (agent loop) | ❌ (sequential) | ✅ | ✅ |
| **Diff** | ❌ | ❌ | ✅ snap+screen | ❌ | visual compare | ❌ | ❌ | ❌ | ❌ |
| **State persist** | cookies/sess | browser profile | ✅ save/load | ✅ sessions | context storage | ✅ | ❌ | cloud sessions | cloud sessions |
| **Tabs** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ (desktop) | ✅ | ✅ |
| **Cross-browser** | ❌ | ❌ | ❌ | ❌ | **✅ Ch/Fx/WK** | ✅ Ch/Fx | ✅ (desktop) | ❌ | ❌ |
| **Token efficiency** | medium | verbose | **~50 tok** | medium | medium | **low** (LLM per step) | **very low** (screenshots) | medium | medium |
| **Install size** | small (Py) | small (npm) | med (Rust+Ch) | large (~200MB) | **huge** (3 br) | large (Py+Ch) | zero (API) | small (npm) | small (npm) |
| **Cost** | free | free | free | free | free | **$$ (LLM calls)** | **$$$ (API) | **$ (cloud) | **$ (cloud) |
| **CI friendly** | ✅ | ❌ | ✅ | ✅ | ✅ | possible | ❌ | ✅ | ✅ |
| **GitHub stars** | private | ~3k | ~6k | growing | ~62k | **~96k** | N/A | ~2k | N/A |

---

## Architecture Patterns

```
┌─────────────────────────────────────────────────────────────┐
│                    HOW AGENTS USE BROWSERS                   │
├──────────────────┬──────────────────┬───────────────────────┤
│   CLI / Bash     │   MCP Server     │   Python Library      │
│                  │                  │                       │
│  rodney ◄───┐    │  Playwright MCP  │  browser-use ◄─┐      │
│  agent-brw ◄┤    │  Chrome DevTools │  CloakBrowser ◄┤      │
│             │    │  Browserbase     │                 │      │
│             │    │  CF Browser Run  │  (both use       │      │
│             │    │                  │   Playwright     │      │
│             │    │                  │   under hood)    │      │
└─────────────┼────┴──────────────────┴─────────────────┼──────┘
              │                                        │
              ▼                                        ▼
        ┌──────────┐                          ┌──────────────┐
        │  Agent   │                          │   LLM Loop   │
        │  calls   │                          │  (decides    │
        │  bash    │                          │   actions)   │
        └──────────┘                          └──────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    DESKTOP-LEVEL CONTROL                    │
│                                                             │
│   Claude Computer Use ──► screenshot ◄─► LLM ◄─► action     │
│   (sees screen, moves cursor, types — any app, not just     │
│    a browser)                                               │
└─────────────────────────────────────────────────────────────┘
```

---

## Token Cost Comparison (rough, per "navigate + extract" roundtrip)

| Tool | Approx tokens | Why |
|------|--------------|-----|
| **agent-browser** | **~50** | Compact a11y tree with `@ref` IDs |
| **rodney** | ~200 | Raw text/HTML from CLI output |
| **Playwright MCP** | ~300–800 | Structured a11y snapshot (JSON) |
| **Chrome DevTools MCP** | ~500–1500 | Large DOM snapshot JSON |
| **browser-use** | ~1000–5000+ | Full page context sent to LLM each step |
| **Claude Computer Use** | ~2000–10000+ | Screenshot + UI understanding per action |
| **Browserbase MCP** | ~300–800 | Stagehand-structured page view |

For long agent loops (20–100+ steps), token costs dominate. **agent-browser** is ~20× cheaper than Claude Computer Use per step.

---

## Decision Flow

```
Need browser automation?
│
├─ Bot detection / Cloudflare block?
│   └─► CloakBrowser (stealth Chromium, 30/30 pass)
│       Optional: pair with rodney or browser-use for agent layer
│
├─ Debugging a live browser you're using?
│   └─► Chrome DevTools MCP
│
├─ Need full desktop control (any app, not just browser)?
│   └─► Claude Computer Use (if using Anthropic)
│
├─ Automated / pipeline / CI?
│   ├─ Need assertions? ──► rodney
│   ├─ Token cost matters? ──► agent-browser
│   ├─ Cross-browser? ──► Playwright MCP
│   └─ Complex multi-step reasoning? ──► browser-use
│
├─ Quick scrape / screenshot / form fill?
│   └─► rodney (simplest setup, pure CLI)
│
├─ Natural language commands ("click Sign Up")?
│   └─► Browserbase MCP (cloud) or agent-browser (local, semantic)
│
├─ No local browser wanted / cloud only?
│   └─► Browserbase MCP or Cloudflare Browser Run
│
└─ Already invested in ecosystem?
    ├─ Playwright shop? ──► Playwright MCP
    ├─ Python/ML shop? ──► browser-use or CloakBrowser
    ├─ Vercel/Rust shop? ──► agent-browser
    └─ This repo? ──► rodney (it's ours!)
```

---

## Combinations That Work

These tools **can** be composed:

| Combination | Pattern |
|-------------|---------|
| **CloakBrowser + rodney** | Use CloakBrowser's stealth Chromium as `ROD_CHROME_BIN` for anti-detect scraping with rodney's CLI ergonomics |
| **CloakBrowser + browser-use** | Swap Playwright for CloakBrowser in browser-use for anti-detect agent loops |
| **rodney + Chrome DevTools MCP** | rodney for automated tasks, DevTools MCP to debug failures |
| **agent-browser (loop) + rodney (tests)** | Cheap navigation/extraction in agent workflows, assertion-heavy test suites with rodney |
| **browser-use + agent-browser** | browser-use for LLM-driven decisions, agent-browser for cheap page reads between decisions |
| **Playwright MCP + CloakBrowser** | Playwright's cross-browser tooling with CloakBrowser's stealth for protected sites |

⚠️ **Don't** run multiple Chrome instances fighting over the same port simultaneously. Stick to one active browser automation tool at a time, or configure explicit ports.

---

## References & Further Reading

### Comparison Articles
- [Webfuse: Top 5 MCP Servers for Browser Automation 2026](https://www.webfuse.com/blog/the-top-5-best-mcp-servers-for-ai-agent-browser-automation) — Playwright, Browserbase, mcp-chrome, Browser Use, Chrome DevTools
- [Computer Use Agents 2026: Claude vs OpenAI vs Gemini](https://www.digitalapplied.com/blog/computer-use-agents-2026-claude-openai-gemini-matrix) — desktop-level agent comparison
- [The 2026 Agentic Browser Landscape: Complete Market Map](https://www.browseract.com/blog/agentic-browser-landscape-2026) — market overview
- [Traditional vs Agentic Browsers: 2026 Comparison Guide](https://www.ruh.ai/blogs/traditional-vs-agentic-browser)
- [No Hacks: The Agentic Browser Landscape in 2026](https://nohacks.co/blog/agentic-browser-landscape-2026)
- [AI Browser Comparison 2027: Atlas vs Comet vs Dia](https://www.webfx.com/blog/ai/best-ai-browsers/) — consumer-facing AI browsers
- [ZTabs: AI Browser Automation 2026](https://ztabs.co/blog/ai-browser-automation-2026) — ChatGPT agent, Computer Use, browser-use, Playwright MCP
- [OpenReplay: Introduction to Agentic Browsers](https://blog.openreplay.com/agentic-browsers-introduction/)

### Tool Homepages
| Tool | Link |
|------|------|
| rodney | [skills/rodney/SKILL.md](../skills/rodney/SKILL.md) (this repo) |
| Chrome DevTools MCP | [github.com/anthropics/chrome-devtools-mcp](https://github.com/anthropics/chrome-devtools-mcp) |
| agent-browser | [github.com/vercel-labs/agent-browser](https://github.com/vercel-labs/agent-browser) |
| CloakBrowser | [github.com/CloakHQ/CloakBrowser](https://github.com/CloakHQ/CloakBrowser) · [cloakbrowser.dev](https://cloakbrowser.dev/) · [PyPI](https://pypi.org/project/cloakbrowser/) |
| Playwright MCP | [github.com/microsoft/playwright-mcp](https://github.com/microsoft/playwright-mcp) · [playwright.dev](https://playwright.dev/) |
| browser-use | [github.com/browser-use/browser-use](https://github.com/browser-use/browser-use) (96k+ ⭐) |
| Claude Computer Use | [platform.claude.com/docs/computer-use](https://platform.claude.com/docs/en/agents-and-tools/tool-use/computer-use-tool) |
| Browserbase | [github.com/browserbase/mcp-server-browserbase](https://github.com/browserbase/mcp-server-browserbase) · [browserbase.com](https://www.browserbase.com/) |
| Cloudflare Browser Run | [blog.cloudflare.com/browser-run-for-ai-agents](https://blog.cloudflare.com/browser-run-for-ai-agents/) |

### Chrome Connection (Critical)
| Link | What |
|------|------|
| [Chrome Blog: Changes to remote debugging switches (March 2025)](https://developer.chrome.com/blog/remote-debugging-port) | **THE breaking change:** `--remote-debugging-port` blocked on default profile since Chrome 136. Security measure against cookie theft via CDP. |
| [Chromium Issue #492069672](https://issues.chromium.org/issues/492069672) | Tracking issue: automation blocked when remote-debugging flags disabled by system policy. |
| [browser-use Issue #1520](https://github.com/browser-use/browser-use/issues/1520) | Chrome >= v136 no longer supports being driven over CDP on default profile — community discussion & workarounds. |
| [Heyuan: Chrome DevTools MCP Setup 2026](https://www.heyuan110.com/posts/ai/2026-03-17-chrome-devtools-mcp-guide/) | Complete guide with `--autoConnect`, `--user-data-dir` fix, three connection methods, troubleshooting. |
| [InnateBlogger: Connect AI Agent to Real Chrome](https://www.innateblogger.com/2026/03/connect-ai-agent-chrome-devtools-mcp.html) | `--autoConnect` setup, permission dialog, what the agent can see. |

### In-Repo Guides
| Guide | What |
|-------|------|
| [guides/rodney-setup.md](rodney-setup.md) | Rodney install & setup |
| [guides/chrome-dev.md](chrome-dev.md) | Chrome DevTools MCP setup |
| [guides/vcl-agent-browser.md](vcl-agent-browser.md) | Vercel agent-browser setup |
| [tests/eval_browsers.md](../tests/eval_browsers.md) | Terminal browser eval (w3m, chawan) |
| [tests/browserfortui_eval.md](../tests/browserfortui_eval.md) | Terminal browser results table |
| [testbed/cloakbrowser/](../testbed/cloakbrowser/) | CloakBrowser stealth/humanize/CF tests |

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 0.1.4 | 2026-06-01 | **Verified CloakBrowser profile-clone capability from official README.** Confirmed `launch_persistent_context(user_data_dir=...)` accepts any directory but fails for cookies/passwords due to Chrome 136+ App-Bound Encryption (Chromium issue #394919677). Documented `storage_state` JSON export/import as the **officially supported** way to transfer cookies+localStorage. Updated the CloakBrowser section with verified code examples and caveats. |
| 0.1.3 | 2026-06-01 | Added "What Are Your ACTUAL Options?" honest list at top of Connect section (Claude Computer Use ruled out). Updated CloakBrowser section to highlight Browser Profile Manager workaround. |
| 0.1.2 | 2026-06-01 | **Critical update: Chrome 136+ breaking change documented.** `--remote-debugging-port` is **blocked on default profile** for security — CDP connect (Puppeteer, Playwright, browser-use) no longer accesses your real cookies/logins. Only `--autoConnect` (DevTools MCP, Chrome 146+) and Claude Computer Use can control YOUR actual browser session. |
| 0.1.1 | 2026-06-01 | Added **Puppeteer MCP** as #10. Added **🔌 Connect to Existing Browser Session** section. |
| 0.1.0 | 2026-06-01 | Initial release. 9 tools compared. |
