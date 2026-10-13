---
name: browser-tools-comparison
description: "Compare agent browser tools: rodney, Chrome DevTools MCP, agent-browser, CloakBrowser, Playwright MCP, browser-use, Claude Computer Use, Browserbase, Cloudflare Browser Run. Feature matrix, benchmarks, token costs, graveyard."
version: 0.2.0
date: 2026-10-11
---

# Agent Browser Tools — Comparison

> Compact reference. Session-reuse details live in [browser-session-reuse.md](browser-session-reuse.md);
> the surf/rodney/chrome-devtools pick lives in [which-browser-tool.md](which-browser-tool.md).

## Tools Compared

| # | Tool | Type | Protocol | In this repo? |
|---|------|------|----------|---------------|
| 1 | [rodney](#1-rodney) | CLI → headless Chrome (Go) | CDP | ✅ skills/rodney |
| 2 | [Chrome DevTools MCP](#2-chrome-devtools-mcp) | MCP → live Chrome | CDP | ✅ chrome-dev.md |
| 3 | [agent-browser](#3-agent-browser-vercel-labs) | CLI + Rust daemon | CDP | ✅ vcl-agent-browser.md |
| 4 | [CloakBrowser](#4-cloakbrowser) | Stealth Chromium (Python) | CDP | ✅ testbed |
| 5 | [Playwright MCP](#5-playwright-mcp) | MCP server | CDP | ❌ external |
| 6 | [browser-use](#6-browser-use) | Python agent framework | Playwright | ❌ external |
| 7 | [Claude Computer Use](#7-claude-computer-use-anthropic) | API tool (desktop) | screenshots | ❌ external |
| 8 | [Browserbase MCP](#8-browserbase-mcp) | Cloud MCP | CDP | ❌ external |
| 9 | [Cloudflare Browser Run](#9-cloudflare-browser-run) | Cloud MCP | CDP | ❌ external |
| 10 | [Puppeteer MCP 🧟](#10-puppeteer-mcp--walking-dead) | MCP server | CDP | ❌ graveyard |

## Quick Pick

| Need | Best tool | Also consider |
|------|-----------|--------------|
| **Connect to my running Chrome** (cookies, tabs, logins) | **Chrome DevTools MCP** (`--autoConnect`) | OpenChrome, agent-browser `--profile` |
| Headless (no UI, background) | **rodney**, **agent-browser** | CloakBrowser, Playwright MCP |
| Headed (visible) for debugging | **Chrome DevTools MCP**, **rodney `--show`** | agent-browser dashboard |
| Simple scraping, screenshots, forms | **rodney** | agent-browser |
| Token-efficient agent loops | **agent-browser** (~50 tok/snapshot) | rodney |
| Anti-detect / bot evasion | **CloakBrowser** | Browserbase (stealth) |
| Full AI agent framework (Python) | **browser-use** | — |
| Cloud scale, no local browsers | **Browserbase MCP** | CF Browser Run |
| Cross-browser testing (Fx/Safari) | **Playwright MCP** | — |
| CI/CD smoke tests, assertions | **rodney** | Playwright MCP |
| Network read (console/perf/Lighthouse) | **Chrome DevTools MCP** | — |
| Network mock/block | **rodney** | agent-browser (also *reads* network) |

## Chrome 136+ — the one constraint that changes everything

> Since March 2025 (Chrome 136), `--remote-debugging-port=9222` is **silently ignored on the default profile**. With `--user-data-dir` you get a **blank profile** — no cookies, no logins. App-Bound Encryption also blocks decrypting copied-profile cookies (macOS excepted — see [OpenChrome's verified cookie sync](browser-session-reuse.md)).
>
> **Only ways to your real session:** Chrome DevTools MCP `--autoConnect` (Chrome 146+, toggle once in `chrome://inspect/#remote-debugging`), extension-based bridges, or cookie extractors (sweet-cookie). Full breakdown → [browser-session-reuse.md](browser-session-reuse.md). Source: [Chrome blog](https://developer.chrome.com/blog/remote-debugging-port).

---

## 1. rodney

**What:** Headless Chrome from the terminal. Go static binary (~17 MB) → CDP → Chrome. **No daemon, no Node, no Python runtime** — the Python wheel is a 30-line `os.execvp` shim. Lightest RAM of any full browser tool (~400–600 MB clean box).

**Strengths:** pure CLI · built-in assertions (`exists`, `visible`, `count`, `assert`) · a11y tree (`ax-tree`) · PDF, element screenshots, file downloads · network interception (`mock`/`block`) + XPath selectors (verified 0.11.0) · session isolation (`--local`) · `--show` for visible mode · 63 tests in our suite.

**Weaknesses:** CSS/XPath only (no semantic locators) · interception is write-only (no console/network/perf *reading* — that's chrome-devtools-mcp) · no batch mode · single-line JS eval · heavy SPAs can timeout.

**Low-RAM / SSH box flags** (≤512 MB):

```bash
rodney start --args="--single-process --disable-gpu \
  --disable-software-rasterizer --disable-dev-shm-usage \
  --js-flags='--max-old-space-size=128'"
```

**Best for:** scraping, screenshots, forms, a11y audits, CI smoke tests, low-RAM boxes.
**Links:** [rodney-setup.md](../../guides/rodney-setup.md) · [SKILL.md](../../skills/rodney/SKILL.md) · `bash tests/rodney/test.sh`

## 2. Chrome DevTools MCP

**What:** MCP server (~29 tools) that attaches to your **already-running Chrome** — the only CDP path to your real session (Chrome 146+ `--autoConnect`; the `chrome-autoallow` wrapper clicks the consent dialog). Setup → [chrome-dev.md](chrome-dev.md).

**Strengths:** your actual browser (tabs, cookies, localStorage) · DOM snapshots, network, perf traces, console, Lighthouse · `--slim` mode · lazy connect, auto-disconnect after 10 min idle.

**Weaknesses:** headed only · needs Chrome running (human's browser) · no assertions · single session.

**Best for:** debugging/inspecting a live session, "what's on my screen now".

## 3. agent-browser (Vercel Labs)

**What:** Rust CLI + daemon, downloads its own Chrome for Testing. Token-efficient a11y snapshots with `@ref` IDs (~50 tokens). Best-in-class profile/state reuse. Smoke-tested 6/6 (2026-06-02): 771ms launch, **2.2s real-GitHub-cookie profile reuse**.

**Strengths:** `@ref` snapshots (cheapest reads) · semantic locators (`find --role/--text/--label`) · network intercept incl. *read* (`network route`, `capture`) · batch mode · diff (snapshot/screenshot) · `--profile "Default"` copies your Chrome profile to temp dir · `--auto-connect state save` + `--state file` auth import · `--session-name` auto persist · AES-256-GCM state encryption · dashboard at `localhost:4848`.

**Weaknesses:** no assertions (use rodney for CI) · daemon must run · `--profile` is read-only snapshot, may hit App-Bound Encryption · can't attach to your *running* Chrome · Windows ARM64 broken (0.25.x).

**Best for:** agent loops where token cost matters, semantic-locator workflows, CLI profile reuse.
**Links:** [vcl-agent-browser.md](vcl-agent-browser.md) · [agent-browser.dev/sessions](https://agent-browser.dev/sessions)

## 4. CloakBrowser

**What:** Stealth Chromium that passes bot detection — **30/30 tests** (FingerprintJS, PixelScan, BrowserScan, Cloudflare). Drop-in Playwright replacement, source-level C++ fingerprint patches (42).

**Strengths:** humanize mode (Bézier mouse, typing physics, scroll overshoot) · session persistence · Cloudflare bypass verified · MIT wrapper.

**Weaknesses:** ~200 MB custom binary · Python-only (no CLI/MCP) · no agent layer · proprietary binary license.

**Session transfer (verified from README):** copying `user_data_dir` **fails** (App-Bound Encryption, [Chromium #394919677](https://issues.chromium.org/issues/394919677)). The supported path is Playwright `storage_state` JSON export/import (cookies + localStorage only; fingerprint-bound cookies like `cf_clearance` may still be rejected). The self-hosted Profile Manager (Docker, `cloakhq/cloakbrowser-manager`) gives persistent per-profile cookies + fingerprints — but its own personas, not your Chrome's.

**Best for:** protected sites, anti-detect, Cloudflare challenges.
**Links:** [CloakHQ/CloakBrowser](https://github.com/CloakHQ/CloakBrowser) · [cloakbrowser.dev](https://cloakbrowser.dev/)

## 5. Playwright MCP

**What:** Official Microsoft Playwright as MCP server. Chromium/Firefox/WebKit.

**Strengths:** cross-browser · auto-waiting · trace viewer · codegen · a11y snapshots · console + network via MCP · Docker image.

**Weaknesses:** heaviest install (3 engines) · Node.js dependency · no stealth · Docker version is headless-Chromium only.

**Best for:** cross-browser testing, visual regression, teams on Playwright, reliable default.

## 6. browser-use

**What:** Python framework for LLM-driven browser agents (117k★). `ChatBrowserUse()` model is 3–5× faster on browser tasks. CLI with ~50ms daemon latency, MCP mode (`uvx browser-use --mcp`).

**Strengths:** full agent loop (planning, memory) · `from_system_chrome()` profile reuse · Bright Data pairing for anti-detect · cloud browser support.

**Weaknesses:** profile copy is disk-hungry (4 GB+ per session, 28s load) · stale daemon sockets after crashes · Python SDK CDP bug [#4688](https://github.com/browser-use/browser-use/issues/4688) — use the CLI · token-hungry (full page context per step) · overkill for simple scraping.

**agent-browser vs browser-use (profile reuse):** agent-browser wins CLI reuse — 2.2s vs 28s load, ~100 MB vs 4 GB disk, automatic vs manual state persist, Rust vs Python daemon stability. browser-use wins LLM-driven autonomy.

**Best for:** multi-step tasks where the LLM decides ("book a flight under $500").
**Links:** [browser-use/browser-use](https://github.com/browser-use/browser-use) · [CLI docs](https://docs.browser-use.com/open-source/browser-use-cli)

## 7. Claude Computer Use (Anthropic)

**What:** API tool — screenshots of your desktop, LLM moves mouse/keyboard. SOTA on WebArena among single-agent systems. Any app, not just browsers.

**Strengths:** your real screen + sessions by definition · handles dynamic UI, sometimes CAPTCHAs · zero selector logic.

**Weaknesses:** Anthropic-only · expensive (screenshot roundtrip per action, ~2k–10k tokens) · no programmatic selectors · latency per step.

**Best for:** Claude-based desktop automation, visual-first tasks.
**Links:** [Computer Use docs](https://platform.claude.com/docs/en/agents-and-tools/tool-use/computer-use-tool)

## 8. Browserbase MCP

**What:** Cloud browsers with Stagehand — natural-language actions ("click Sign Up"). Nothing local.

**Strengths:** no local install · scales horizontally · stealth options · session recording + live view.

**Weaknesses:** paid API · external infra latency · Stagehand default model is Gemini.

**Best for:** cloud scale, natural-language-first workflows.

## 9. Cloudflare Browser Run

**What:** Cloudflare's edge browsers as MCP (renamed from Browser Rendering, 2026-04; 120 concurrent browsers).

**Strengths:** edge latency · CF-scale infra · no local browser.

**Weaknesses:** very new · CF lock-in · fewer features than Browserbase.

## 10. Puppeteer MCP 🧟 (walking dead)

> **Verified 2026-10-04: no maintained official Puppeteer MCP server exists.** The reference server (`@modelcontextprotocol/server-puppeteer`) is deprecated on npm (2025-05); `@anthropic-ai/puppeteer-mcp` never existed (old doc error); community servers dead. **Use Playwright MCP for the MCP path.** The puppeteer *library* itself is alive and excellent.

**Library strengths:** CDP-native (best raw protocol access) · Chromium-first · lighter than Playwright · Firefox via BiDi (limited).
**Library weaknesses:** JS/TS only · no WebKit · manual waits · no trace viewer.

**Playwright vs Puppeteer verdict (for agents):** default to **Playwright** — auto-waiting (fewer failed LLM steps), cross-browser, traces/codegen, Python/.NET bindings. Drop to **puppeteer** only for Chromium-only CDP-heavy work (raw `createCDPSession()` network/perf tooling). Neither is token-efficient natively — agent-browser and rodney beat both for LLM loops.

---

## Feature Matrix

| Feature | rodney | Chrome DevTools MCP | agent-browser | CloakBrowser | Playwright MCP | browser-use | Claude Comp. Use | Browserbase | CF Browser Run |
|---------|--------|-------------------|---------------|-------------|----------------|-------------|-----------------|-------------|----------------|
| **Connect existing Chrome** | ❌ | ✅ **autoConnect** | ❌ | ❌ | ⚠️ CDP (blank profile) | ⚠️ via backend | ✅ desktop | ❌ cloud | ❌ cloud |
| **Keeps your cookies/logins** | ❌ own | ✅ **yours** | ⚠️ profile copy | ⚠️ storage_state | ❌ blank profile | ⚠️ profile copy | ✅ your screen | ❌ cloud | ❌ cloud |
| **Headless** | ✅ default | ❌ | ✅ default | ✅ default | ✅ | ✅ | ❌ | ✅ | ✅ |
| **Headed** | ✅ `--show` | ✅ *is* your browser | dashboard | ✅ | ✅ | ✅ | ✅ always | cloud view | cloud view |
| **Selectors** | CSS/XPath | CSS/JS | a11y `@ref` + semantic | Playwright CSS/XPath | CSS + text + role | LLM-driven | visual | natural language | natural language |
| **Stealth/anti-detect** | ❌ | ❌ | ❌ | **✅ 30/30** | ❌ | partial | ✅ (paid) | ✅ | ✅ (CF infra) |
| **Screenshots / PDF** | ✅ / ✅ | viewport / ❌ | ✅ / ✅ | ✅ / via PW | ✅ / ✅ | ✅ / ✅ | ✅ / ❌ | ✅ / ❌ | ✅ / ❌ |
| **Assertions built-in** | ✅ | ❌ | ❌ | ❌ | via expect | custom | ❌ | ❌ | ❌ |
| **Network intercept** | ✅ mock/block | ✅ read | ✅ read+route | via PW | ✅ | via PW | ❌ | ✅ | ✅ |
| **Console/perf/Lighthouse read** | ❌ | ✅ | ✅ network | ❌ | ✅ console | via DOM | ❌ | ✅ | ✅ |
| **Batch/chain** | ❌ | ❌ | ✅ | via scripts | ✅ | ✅ agent loop | ❌ | ✅ | ✅ |
| **State persist** | session cookies | browser profile | ✅ save/load | ✅ sessions | context storage | ✅ | ❌ | cloud sessions | cloud sessions |
| **Cross-browser** | ❌ | ❌ | ❌ | ❌ | **✅ Ch/Fx/WK** | ✅ Ch/Fx | ✅ desktop | ❌ | ❌ |
| **Token efficiency** | ~200 | verbose | **~50** | medium | ~300–800 | low (1–5k/step) | very low (screenshots) | ~300–800 | ~300–800 |
| **Install size** | small | small | med | large (~200MB) | huge (3 browsers) | large | zero | small (npm) | small (npm) |
| **Cost** | free | free | free | free | free | $$ (LLM calls) | $$$ (API) | $ (cloud) | $ (cloud) |
| **CI friendly** | ✅ | ❌ | ✅ | ✅ | ✅ | possible | ❌ | ✅ | ✅ |

## What Each Tool Actually Is (verified via `file`/`otool`/`strings`)

| Tool | Binary | Runtime | Daemon? |
|------|--------|---------|---------|
| rodney | 11.5 MB **Go** static (go-rod/rod) | none (`os.execvp` shim) | ❌ |
| agent-browser | native **Rust** | native | ✅ Rust daemon |
| CloakBrowser | ~200 MB stealth Chromium + Py wrapper | Playwright/Python | per session |
| browser-use | Python package | Playwright + Python | ✅ Python daemon (socket) |
| Playwright/Puppeteer MCP | Node.js package | Node.js | ✅ MCP server |

## Benchmarks (2026-06-05, macOS arm64, 3 runs, example.com)

### Speed (ms, lower = better)

| Operation | rodney | agent-browser | CloakBrowser | Winner |
|-----------|--------|---------------|--------------|--------|
| Cold start / open | 843 | **769** | 2,104 | agent-browser |
| Navigate | 991 | *(in open)* | **140** | CloakBrowser |
| Page read | **35** | 172 | **6–14** | rodney + Cloak |
| Click | 219 | **174** | 995–30,000 ⚠️ | agent-browser |
| Stop | **31** | 281 | implicit | **rodney 9×** |
| **Total workflow** | 2,119 | **1,396** | ~3,200 | **agent-browser 34% faster** |

### RAM (clean Linux box estimate)

| Tool | Est. RAM | Why |
|------|----------|-----|
| **rodney** | **~400–600 MB** | zero daemon — Go binary → CDP → Chrome, nothing lingers |
| agent-browser | ~600–900 MB | Rust daemon + Chrome stay alive between calls |
| CloakBrowser | ~500–750 MB | Playwright + Python + stealth Chromium |

**Trade-off:** agent-browser's warm daemon wins long loops (20+ steps); rodney wins single-shot scripts and starved boxes. Under 256 MB RAM use w3m/chawan; 256–512 MB use rodney `--single-process` (see flags above).

## Token Cost (per navigate + extract roundtrip)

| Tool | Approx tokens |
|------|--------------|
| **agent-browser** | **~50** |
| rodney | ~200 |
| Playwright MCP | ~300–800 |
| Chrome DevTools MCP | ~500–1,500 |
| browser-use | ~1,000–5,000+ |
| Claude Computer Use | ~2,000–10,000+ |

For 20–100-step loops, agent-browser is ~20× cheaper than Claude Computer Use.

## Combinations That Work

| Combination | Pattern |
|-------------|---------|
| CloakBrowser + rodney | stealth Chromium as `ROD_CHROME_BIN` → anti-detect scraping with rodney's CLI |
| CloakBrowser + browser-use | swap Playwright for CloakBrowser in agent loops |
| rodney + Chrome DevTools MCP | rodney automates, DevTools MCP debugs failures |
| agent-browser + rodney | cheap reads in loops, assertion-heavy tests in CI |
| browser-use + agent-browser | LLM decides, agent-browser reads cheaply between steps |

⚠️ One active browser automation tool at a time, or explicit ports — don't fight over 9222.

## Graveyard (verified 2026-10-04 via GitHub/npm/PyPI)

**Dead:** OpenAI Operator (absorbed into ChatGPT, 2025-08) · ChatGPT Atlas (2026-08) · Instant Checkout (2026-03) · MultiOn.

**Walking dead:** `mcp-chrome` hangwin (12.4k★, silent since 2026-01) · Real Browser MCP (0★) · `agentauth-py` (no source since 2025-03 — use **sweet-cookie**) · `@modelcontextprotocol/server-puppeteer` (deprecated) · `@anthropic-ai/puppeteer-mcp` (never existed).

**Renamed:** chrome-mcp → [livemcp](https://github.com/Magi-Labs/livemcp) (alive) · CF Browser Rendering → Browser Run.

**Alive (spot-check 2026-10):** OpenChrome, CloakBrowser (31.9k★), Nanobrowser (13.9k★), agent-browser (43.5k★), browser-use (117k★), Playwright MCP (37.8k★), Stagehand, Skyvern, Airtop, sweet-cookie.

## References

- **[Chrome blog: remote-debugging-port changes](https://developer.chrome.com/blog/remote-debugging-port)** — the 2025 breaking change
- [browser-use #1520](https://github.com/browser-use/browser-use/issues/1520) — Chrome 136 CDP breakage discussion
- [Webfuse: Top 5 Browser MCP Servers 2026](https://www.webfuse.com/blog/the-top-5-best-mcp-servers-for-ai-agent-browser-automation)
- In-repo: [browser-session-reuse.md](browser-session-reuse.md) · [which-browser-tool.md](which-browser-tool.md) · [chrome-dev.md](chrome-dev.md) · [vcl-agent-browser.md](vcl-agent-browser.md) · [terminal-browsing.md](terminal-browsing.md) · [api-sniffing.md](api-sniffing.md)

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 0.2.0 | 2026-10-11 | **Compacted ~70%** (1,698 → ~330 lines): session-connect section and 11.x session-tool catalog folded into [browser-session-reuse.md](browser-session-reuse.md) (single source of truth); decision flow folded into [which-browser-tool.md](which-browser-tool.md); two feature matrices merged; Playwright-vs-Puppeteer deep dive compressed to verdict; ASCII architecture art dropped (verified binary table kept). All benchmarks, token costs, graveyard data, and per-tool facts preserved. |
| 0.1.6 | 2026-10-04 | Dead & walking-dead audit (Puppeteer MCP corrected, livemcp rename, graveyard appendix). |
| 0.1.5 | 2026-06-05 | Benchmark results; rodney architecture; low-RAM flags. |
| 0.1.4 | 2026-06-01 | CloakBrowser profile-clone verified (App-Bound Encryption blocks copy; storage_state is the supported path). |
| 0.1.2 | 2026-06-01 | Chrome 136+ breaking change documented. |
| 0.1.0 | 2026-06-01 | Initial release. |
