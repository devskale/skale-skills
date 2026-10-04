---
name: terminal-browsing
description: "Terminal-based browsing intelligence — w3m and chawan (cha) for humans and agents: when a text browser beats a real one, verified breakage (GitHub gzip, JS walls, Reddit block), the text-web endpoints that still work, and where terminal browsers sit in the agent ladder (fetch-url → w3m/cha → rodney)."
version: 0.1.0
date: 2026-10-04
---

# Terminal-Based Browsing — Our Intelligence

> Distilled from our own evals (2026-02-14, re-verified 2026-10-04) — opinions
> and breakage we have actually reproduced, not a link collection.

## Why terminal browsing matters (for us)

Three distinct users share one niche:

1. **Humans on SSH / low bandwidth / low RAM** — a 2 MB text browser renders
   orf.at or Wikipedia where headless Chrome eats 500+ MB.
2. **Agents reading the web** — an agent wants *text* anyway. A terminal
   browser's dump mode is a layout-aware text extractor — closer to "what a
   human reads" than raw HTML, far cheaper than a vision model on screenshots.
3. **TUI workflows** — pi, herdr, tmux: a browser that opens a *window* breaks
   the workflow; something that dumps to stdout composes.

## The ladder (agents should walk it in this order)

```
fetch-url / plain HTTP     →  w3m -dump / cha -d   →  rodney / surf
   (no JS, cheapest,          (layout-aware text,       (full JS, cookies,
    readability-extracted)      no JS in w3m,             screenshots, PDFs)
                                 QuickJS in chawan)
```

**The middle rung is the most underused.** Most agents jump from fetch-url
straight to a real browser; but for text-heavy sites a dump renders tables,
lists and headings in reading order — often better than naive readability
extraction, at zero marginal cost.

## w3m vs chawan — our verdict

| | **w3m** | **chawan (cha)** |
|---|---|---|
| Engine | C, classic | Nim, modern |
| JavaScript | ❌ none | ✅ QuickJS (real JS, in the terminal!) |
| Interactive mode | pager-like | vi-like (it *is* a pager) |
| Dump to stdout | `w3m -dump` ✅ | `cha -d` ✅ |
| Maintenance status | stable, slow-moving | active (sourcehut; our mirror: devskale/chawan, synced daily) |
| Our verdict | **the reliable default** | technically superior (JS!), but less battle-tested here |

Our eval history (2026-02, macOS): chawan rendered Hacker News and Wikipedia
(with JS errors); w3m won on simplicity. Chawan's QuickJS angle is the one
feature that could make a terminal browser *sufficient* for JS-light modern
sites — no second rung needed.

## Verified breakage (reproduced 2026-10-04)

| Site | w3m -dump | Note |
|------|-----------|------|
| orf.at | ✅ | full navigation text |
| en.wikipedia.org | ✅ | |
| news.ycombinator.com | ✅ | clean reading order |
| lite.duckduckgo.com/lite | ✅ | the DDG endpoint that works |
| google.com | ⚠️ | cookie banner only |
| **github.com** | ❌ | `gunzip: unknown compression format` — stable across months, our oldest reproducer |
| **reddit.com** | ❌ | **newly broken** — returned content in Feb 2026, empty now (JS wall / block) |
| old.reddit.com | ⚠️ | renders, but thin |

Breakage classes, in observed frequency:
1. **JS-required walls** (DDG main, Reddit now) — the dominant killer.
2. **Protocol quirks** (GitHub's gzip handling in w3m) — rare but stable.
3. **Cookie/consent walls** (Google) — content behind the banner.
4. **Cloudflare-style bot gates** — usually 403 before the browser even matters.

## The text-web endpoints that still work

When a terminal browser (or plain curl) is your client, prefer the text-friendly
surface of a site:

- `lite.duckduckgo.com/lite` instead of duckduckgo.com
- `old.reddit.com` instead of reddit.com (thin but text)
- Hacker News (no alternate endpoint needed)
- Wikipedia (fully text-first by design)
- `.json`/API endpoints where a site offers them (HN: `hn.algolia.com/api/v1/search?query=…`)

## Recommendations (our policy)

- **Agent reading a page:** `fetch-url` first. If extraction looks mangled
  (tables, nested lists), try `w3m -dump` as the second call before reaching
  for rodney.
- **Human, quick look inside a TUI/SSH session:** w3m.
- **JS-light modern site, terminal only:** chawan (QuickJS) — but verify;
  our Feb eval showed JS errors on Wikipedia.
- **JS-heavy site, screenshots, PDFs, logins:** stop hopping — rodney
  (isolated) or surf (your session). The terminal rung ends here.

## History of our evals

- **2026-02-14** — w3m 0.5.6 vs chawan 0.3.3 on macOS (results:
  [tests/browserfortui_eval.md](../../tests/browserfortui_eval.md),
  raw notes: [tests/eval_browsers.md](../../tests/eval_browsers.md))
- **2026-10-04** — re-verified on this machine: GitHub gzip still broken,
  Reddit newly blocked, orf.at/Wikipedia/HN/lite-DDG still fine. w3m only
  (chawan no longer installed here).

## References

- w3m — <https://w3m.sourceforge.net/>
- chawan — sourcehut `~bptato/chawan` · unofficial daily mirror: [devskale/chawan](https://github.com/devskale/chawan)
- Related skills: [fetch-url](../../skills/fetch-url/) · [rodney](../../skills/rodney/) · [surf](../../skills/surf/)
- Full browser tool landscape: [browser-tools-comparison.md](browser-tools-comparison.md) · decision flow: [which-browser-tool.md](which-browser-tool.md)
