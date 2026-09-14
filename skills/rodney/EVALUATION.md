# Rodney Evaluation (2026 landscape)

Assessment of rodney against the current browser-automation tool landscape, focused on
its role as a **CLI / agent** browser driver. This is a qualitative positioning review —
**it contains no benchmark numbers**, because there are no published, reproducible
head-to-head benchmarks that include rodney (go-rod). Any specific throughput/latency
figures you see elsewhere for rodney should be treated as unverified.

## What rodney is

- **CLI-first**, single long-running headless Chromium session (cookies, localStorage,
  navigation state persist across invocations).
- Built on [go-rod](https://github.com/go-rod/rod) (Go), downloaded Chromium binary.
- Persistent foreground commands (`mock`/`block`) for network interception.
- Accessibility tree, screenshots, PDFs, video, tabs, emulation — all from the shell.
- **Agent-friendly by design**: each call is a separate, fast, stateless CLI invocation
  that shares one browser process. No server to babysit, no SDK to embed.

## Landscape (2026)

| Tool | Paradigm | Best for | Rodney's edge / gap |
|------|----------|----------|---------------------|
| **Rodney** | CLI + persistent browser | Agent/script browser jobs, scraping, a11y, CI | Zero deps, session persistence, network mock/block, a11y from shell |
| **Puppeteer** | Node library | Programmatic Chrome control | Rodney needs no code; Puppeteer has richer programmatic API |
| **Playwright** | Node/Python library + test runner | Cross-browser E2E testing | Playwright: auto-wait, multi-browser, assertions, trace viewer |
| **Selenium** | Library + WebDriver | Legacy/enterprise, many languages | Heavier; W3C WebDriver standard |
| **Browser Use** | Agent framework | LLM-driven browsing with planning | Framework-level; rodney is a lower-level driver |
| **Browserless** | Cloud service | Scale, headless-as-a-service | Rodney is local/free; Browserless is managed+paid |

## Verdict

Rodney is **strong for its niche** (CLI/agent browser workflows) and complements — rather
than competes with — the testing frameworks. It is well-suited to agent use because it
removes the SDK/server layer and exposes a persistent browser as simple commands.

## Gaps (honest)

- **No auto-wait on `click`/`input`** — the biggest real-world flakiness source. An
  explicit `waitstable`/`wait` is required. Mitigation: agent retry + documented patterns.
- **Chromium only** — no Firefox/WebKit (vs Playwright).
- **No built-in retry** — handled at the agent layer (see TROUBLESHOOTING.md).
- **No stealth / bot-detection evasion** — some sites will block it.
- **No concurrency manager** — one active session; multi-browser needs manual `--local`
  dirs / `RODNEY_HOME`.
- **No assertion library** beyond `exists`/`visible`/`count`/`assert`.

## Suggested priority for upgrades

1. **Auto-wait helper** (e.g. `rodney waitauto <sel>` = wait for visible then act) — cuts
   the dominant flakiness source.
2. **MCP server** wrapper for first-class AI-agent integration.
3. **Session export/import** (state + cookies across machines).
4. **Pre-flight check** (`rodney check` — browser alive, port reachable, version).
5. **Recipe book** of battle-tested agent workflows.

> Note: these are recommendations, not commitments. The user has explicitly chosen
> **agent-native retry** over a built-in retry wrapper — so item "no built-in retry" is
> intentionally left to the agent layer.
