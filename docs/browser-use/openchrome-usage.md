---
name: openchrome-usage
description: "OpenChrome MCP server — setup, cookie sync, real-session browsing, smoke test results. Validated on macOS."
version: 0.1.0
date: 2026-06-06
---

# OpenChrome — Usage Guide

> OpenChrome is an MCP server that controls a real Chrome browser via CDP, with atomic cookie sync from your existing Chrome profile. Free, open source (MIT).
>
> **Repo:** [github.com/shaun0927/openchrome](https://github.com/shaun0927/openchrome) · **npm:** `openchrome-mcp` · **Version tested:** 1.12.7

---

## How It Works

OpenChrome has a **three-tier profile strategy** for handling the Chrome 136+ restrictions:

```
┌──────────────────────────────────────────────────────────────────┐
│  TIER 1: Real profile                                            │
│  Chrome is NOT running → launch with real --user-data-dir       │
│  ✅ Your actual cookies, logins, extensions                      │
│  ⚠️ Only works when Chrome is completely closed                  │
├──────────────────────────────────────────────────────────────────┤
│  TIER 2: Persistent profile + cookie sync (DEFAULT)              │
│  Chrome IS running → use ~/.openchrome/profile/                  │
│  Cookies synced via atomic sqlite3 .backup from real profile     │
│  ✅ Your cookies work (verified: GitHub login as @devskale)       │
│  ✅ Persistent across OpenChrome restarts                        │
│  ⚠️ Sync is a snapshot — cookies stale after sync time           │
├──────────────────────────────────────────────────────────────────┤
│  TIER 3: --restart-chrome (aggressive)                           │
│  Kills running Chrome, relaunches with debug port                │
│  ✅ Gets your real running profile                               │
│  ❌ Kills your browser (your tabs close)                         │
└──────────────────────────────────────────────────────────────────┘
```

### Why Cookie Sync Works on macOS (Validated)

**The claim:** OpenChrome copies cookies from your real Chrome profile to `~/.openchrome/profile/` and they decrypt correctly.

**Why it works on macOS:**
- Chrome on macOS encrypts cookies with **v10 AES-CBC** using a key stored in the **macOS Keychain** under `"Chrome Safe Storage"`.
- This key is tied to the **macOS user account**, NOT the Chrome profile path.
- Any Chrome instance running as the same macOS user can decrypt cookies from any `--user-data-dir`.

**Why it may NOT work on Windows:**
- Chrome on Windows uses **DPAPI + App-Bound Encryption (v20)** for some cookies.
- v20 encryption ties the decryption key to the **browser process and profile path**.
- Cookies copied to a different `--user-data-dir` may fail to decrypt.
- sweet-cookie (which documents this) skips v20 cookies with a warning.
- OpenChrome has **no special v20 handling** — it just copies the SQLite file.

**Verified in this test:**
```bash
# GitHub session cookie in OpenChrome's persistent profile
$ sqlite3 ~/.openchrome/profile/Default/Cookies \
  "SELECT host_key, name FROM cookies WHERE host_key='github.com' AND name='user_session';"
github.com|user_session

# Encryption version: v10 (Keychain, per-user)
$ sqlite3 ~/.openchrome/profile/Default/Cookies \
  "SELECT hex(substr(encrypted_value,1,4)) FROM cookies WHERE host_key='github.com' AND name='user_session';"
7631309C  # = "v10" + 0x9C → v10 AES-CBC

# Decryption: ✅ succeeds (Keychain key accessible by same macOS user)
# Navigated to github.com → logged in as @devskale (Skale.io Developer Account)
```

---

## Setup

### Install

```bash
npm install -g openchrome-mcp
openchrome --version  # 1.12.7
```

### For MCP Clients (Claude Code, Cursor, etc.)

```bash
# Auto-configures your MCP client
openchrome setup                       # Claude Code
openchrome setup --client codex        # Codex CLI
openchrome setup --client opencode     # OpenCode
```

Restart your MCP client. Chrome auto-launches on first tool call (if Chrome is not already running).

**Manual config** (Cursor, VS Code, Windsurf, etc.):
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

### For CLI Usage (HTTP Daemon Mode)

The `oc run` / `oc navigate` shortcuts use `--server-mode` which launches a **headless temp-profile Chrome** — NOT your real cookies. To use your synced cookies, you need the HTTP daemon:

```bash
# 1. Set auth (required for HTTP mode)
export OPENCHROME_ALLOW_UNAUTHENTICATED_HTTP=1  # local dev only

# 2. Start the daemon
openchrome serve --port 9333 --auto-launch --http 3102

# 3. Use it
OPENCHROME_HTTP_PORT=3102 openchrome navigate "https://github.com" --reuse --json
```

---

## The Gotcha: When Chrome Is Already Running

**This is the most common scenario and the biggest friction point.**

Chrome 136+ ignores `--remote-debugging-port` on the default profile. If Chrome is already running:

1. `--auto-launch` **fails** — can't start a second Chrome instance
2. `--restart-chrome` **kills your Chrome** — you lose open tabs
3. Manual Chrome launch with your real profile **silently opens a tab in the existing instance** — debug port never opens

### The Working Workaround

Launch Chrome manually with OpenChrome's persistent profile (which has synced cookies):

```bash
# Step 1: Start Chrome with persistent profile + debug port
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --remote-debugging-port=9333 \
  --user-data-dir="$HOME/.openchrome/profile" \
  --profile-directory="Default" \
  --no-first-run \
  --no-default-browser-check \
  "about:blank" &

# Step 2: Start OpenChrome serve (connects to existing Chrome)
export OPENCHROME_ALLOW_UNAUTHENTICATED_HTTP=1
openchrome serve --port 9333 --http 3102

# Step 3: Browse with your synced cookies
OPENCHROME_HTTP_PORT=3102 openchrome navigate "https://github.com" --reuse --json
# → Logged in as @devskale ✅
```

### Port Conflicts

If Chrome Beta (or another Chrome variant) is using port 9222:

```bash
# Check what's on 9222
lsof -i :9222

# If Chrome Beta is there but not serving CDP → use a different port
openchrome serve --port 9333 ...
```

---

## CLI Quick Reference

```bash
# Navigate
OPENCHROME_HTTP_PORT=3102 openchrome navigate "https://example.com" --reuse --json

# Read page (DOM mode)
OPENCHROME_HTTP_PORT=3102 openchrome run read_page --arg tabId=TAB_ID --reuse --json

# Read page (accessibility tree — get refs for clicking)
OPENCHROME_HTTP_PORT=3102 openchrome run read_page --arg tabId=TAB_ID --arg mode=ax --reuse --json

# Click (must use fresh refs from read_page)
OPENCHROME_HTTP_PORT=3102 openchrome run interact --arg ref=ref_10 --arg action=click --arg tabId=TAB_ID --reuse --json

# Screenshot
OPENCHROME_HTTP_PORT=3102 openchrome run page_screenshot --arg tabId=TAB_ID --arg path=/tmp/screenshot.png --reuse --json

# List tabs
OPENCHROME_HTTP_PORT=3102 openchrome run tabs_context --reuse --json

# Form input
OPENCHROME_HTTP_PORT=3102 openchrome run form_input --arg ref=REF --arg value="text" --arg tabId=TAB_ID --reuse --json

# Run JavaScript
OPENCHROME_HTTP_PORT=3102 openchrome run javascript_tool --arg code="document.title" --arg tabId=TAB_ID --reuse --json

# Assert (contract-based)
OPENCHROME_HTTP_PORT=3102 openchrome run oc_assert --arg contract='json:{"type":"text","contains":"Example Domain"}' --reuse --json
```

---

## Smoke Test Results

> **Date:** 2026-06-06 · **macOS arm64** · **Chrome stable v148** · **OpenChrome v1.12.7**

| Test | Result | Detail |
|------|:------:|--------|
| Install (`npm i -g`) | ✅ | 119 packages, 6s |
| Connect to Chrome (CDP) | ✅ | Found Chrome on port 9333, connected |
| Navigate (example.com) | ✅ | Title "Example Domain", 11 elements |
| Read page (DOM) | ✅ | Full DOM tree with `[ref_N]` IDs, **9ms** |
| Read page (a11y) | ✅ | Accessibility tree with `ref_N @eN` IDs |
| Click (interact) | ✅ | Clicked "Learn more" → navigated to iana.org, **12ms** |
| Screenshot | ✅ | 21KB PNG, 1920×1080, **66ms** |
| **Cookie sync + GitHub login** | ✅ | **Logged in as @devskale** via synced cookies |
| Hint engine | ✅ | Auto-detected stale refs, suggested recovery |
| Doctor diagnostic | ✅ | Found port 9222 conflict with Chrome Beta |
| 118 tools registered | ✅ | Full tool surface available |

---

## Cookie Sync Internals

### What Gets Synced

OpenChrome copies from your real Chrome profile to `~/.openchrome/profile/`:

| Data | Method | Works? |
|------|--------|:------:|
| **Cookies** (SQLite) | Atomic `sqlite3 .backup` | ✅ macOS, ⚠️ Windows v20 |
| **Local Storage** (LevelDB) | Recursive file copy | ✅ |
| **IndexedDB** | Recursive file copy | ✅ |
| **Preferences** | Copy + patch (suppress crash prompts) | ✅ |
| **Passwords** | ❌ Not synced | — |
| **Extensions** | ❌ Not synced | — |
| **History** | ❌ Not synced | — |

### Sync Metadata

```bash
$ cat ~/.openchrome/sync-metadata.json
{
  "lastSyncTimestamp": 1780763891768,        # when sync happened
  "sourceProfileHash": "1780763826098.7388:3014656",  # mtime:size of source Cookies
  "syncCount": 1,                            # number of syncs
  "sourceProfileDir": ".../Google/Chrome"    # where cookies came from
}
```

OpenChrome uses `sourceProfileHash` to detect staleness. If the real Chrome cookie DB hasn't changed since last sync, it skips re-syncing.

### When Sync Happens

- On first `openchrome serve --auto-launch`
- When persistent profile is stale (real cookie DB modified since last sync)
- NOT on every tool call — only on serve startup

### Staleness

Cookies synced at time T will become stale as your real Chrome session evolves. For long-lived sessions (GitHub, Google), this is fine. For short-lived tokens (OAuth flows, CSRF nonces), stale cookies may cause auth failures.

**Fix:** Restart OpenChrome serve to trigger a fresh sync.

---

## macOS vs Windows

| | macOS | Windows |
|---|:---:|:---:|
| Cookie encryption | v10 AES-CBC + Keychain | v10 DPAPI + v20 App-Bound |
| Key binding | macOS user account | Profile path + browser process (v20) |
| Cookie sync works? | ✅ **Yes** (validated) | ⚠️ v10 yes, **v20 NO** |
| Keychain access needed? | Yes (prompts once) | N/A |
| `sqlite3` available? | ✅ Built-in | ❌ May need install |
| Alternative for v20 | N/A | Chrome extension exporter |

---

## Comparison with Alternatives

| | OpenChrome | Chrome DevTools MCP | agent-browser | browser-use |
|---|:---:|:---:|:---:|:---:|
| Gets your real cookies | ✅ via sync | ✅ via --autoConnect | ✅ via --profile | ✅ via --profile |
| Chrome already running? | ⚠️ manual launch needed | ✅ connects to it | ❌ copies profile | ❌ copies profile |
| Cookie sync method | Atomic SQLite .backup | N/A (uses live Chrome) | File copy | File copy |
| Persistent profile | ✅ `~/.openchrome/profile/` | N/A | ✅ `--session-name` | ❌ |
| Stale sync detection | ✅ mtime hash | N/A | ❌ | ❌ |
| CLI one-shots | ⚠️ needs HTTP daemon | ❌ MCP only | ✅ direct CLI | ✅ direct CLI |
| MCP server | ✅ (118 tools) | ✅ (~29 tools) | ❌ CLI only | ✅ MCP mode |
| Parallel sessions | ✅ | ❌ | ❌ | ❌ |
| Hint engine | ✅ | ❌ | ❌ | ❌ |
| Contract assertions | ✅ `oc_assert` | ❌ | ❌ | ❌ |
| Token efficiency | Good (ref IDs) | Verbose | Best (~50 tokens) | Poor (LLM per step) |
| Setup complexity | High (5+ steps for CLI) | Low (one toggle) | Low (brew install) | Medium |

---

## When to Use OpenChrome

**Use it when:**
- You need **parallel authenticated sessions** (this is its killer feature)
- You want contract-based testing (`oc_assert`)
- You're building complex agent flows and need the hint engine + recovery system
- You're on macOS and want your real cookies without killing Chrome

**Don't use it when:**
- You just need to connect to your already-running Chrome → **Chrome DevTools MCP** is simpler
- You just need a quick CLI scrape → **rodney** or **agent-browser** are faster
- You're on Windows with v20 App-Bound cookies → cookie sync won't work

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `openchrome doctor` shows port 9222 conflict | Use `--port 9333` and launch Chrome manually on 9333 |
| Auto-launch fails ("Chrome is not running with remote debugging") | Chrome is already running. Launch manually with `--user-data-dir=~/.openchrome/profile` |
| HTTP mode refuses unauthenticated | Set `OPENCHROME_ALLOW_UNAUTHENTICATED_HTTP=1` |
| `STALE_REF` error on click | Call `read_page` first to get fresh refs, then click |
| `oc run` / `oc navigate` hangs | Uses `--server-mode` (headless). Switch to HTTP daemon + `--reuse` |
| Cookies not working on a site | Restart serve to re-sync. Some short-lived tokens go stale. |
| `--auto-connect` fails | Chrome must be launched with `--remote-debugging-port=0` first. See `docs/auto-connect.md`. |
| sqlite3 not found | macOS: built-in. Linux: `apt install sqlite3`. Required for atomic cookie sync. |

---

## References

- [OpenChrome GitHub](https://github.com/shaun0927/openchrome)
- [Getting Started](https://github.com/shaun0927/openchrome/blob/main/docs/getting-started.md)
- [Auto-connect docs](https://github.com/shaun0927/openchrome/blob/main/docs/auto-connect.md)
- [CLI docs](https://github.com/shaun0927/openchrome/blob/main/docs/cli.md)
- [Chrome cookie encryption on macOS](https://gist.github.com/creachadair/937179894a24571ce9860e2475a2d2ec) — "Chrome Safe Storage" in Keychain
- [sweet-cookie: Chromium v20 App-Bound Encryption](https://github.com/steipete/sweet-cookie#chromium-v20-app-bound-encryption) — v20 cookies skip + warn
- [Chrome Blog: remote-debugging-port changes](https://developer.chrome.com/blog/remote-debugging-port) — the Chrome 136+ breaking change
- [Full comparison: browser-session-reuse.md](browser-session-reuse.md) · [browser-tools-comparison.md](browser-tools-comparison.md)
