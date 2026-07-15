# Surf — TODO

Checkable roadmap. Workflow per item: **implement → validate (`tests/surf/furious.sh`) → commit → check the box.**

Status: `surf v1.1.1` — navigation/tabs, reads, assertions, interactions (click/fill/hover/select-option/submit/scroll/press), waits, screenshots, `--json`, classified JS-failure messages.

## Tier 1 — core gaps (real friction)

- [x] `wait "<sel>" [--timeout N]` — poll until element exists (exit 1 on timeout)
- [x] `wait-url "<substring>" [--timeout N]` — poll until `location.href` contains substring
- [x] `wait-stable [--timeout N]` — poll until DOM stops changing
- [x] `scroll down|up|top|bottom [N]` + `scroll-to "<sel>"`
- [x] clear, classified JS-failure messages (toggle-off vs incognito vs restricted tab) instead of raw Chrome errors
- [x] `hover "<sel>"`
- [x] `select-option "<sel>" "<value>"` (dropdown)
- [x] `press "<key>"` (key chords: `Enter`, `Tab`, `cmd+a`)
- [x] `submit "<sel>"`

## Tier 2 — pipeline/agent readiness

- [x] `exists "<sel>"` / `visible "<sel>"` (exit 1 if not)
- [x] `assert '<js>' [expected]` (exit 1 on mismatch)
- [x] `--json` output for `tabs`, `here`, `text`, `count`
- [x] `list "<sel>"` — JSON array of all matches' text (scrape lists)
- [x] `shot-el "<sel>"` — element screenshot (scroll-into-view + getBoundingClientRect + sips crop)

## Tier 3 — nice to have

- [ ] `form 'sel1=val1' 'sel2=val2'` — batch fill
- [ ] `download "<sel>"` — trigger + monitor a download
- [ ] `activate <wN.tN>` / `find-tab "<query>"` — focus a tab / search tabs
- [ ] full-page screenshot (scroll + stitch)
- [ ] `cookie "<name>"` / localStorage read

## Tier 4 — reliability & robustness

- [ ] robust JS-failure classification — replace the O(N) up-to-10-tab probe in `_explain_js_failure` with a cheaper deterministic signal (cache last-known global toggle; single sentinel probe on a known-good tab). Resolves the x.com/incognito/PWA ambiguity without a scan.
- [ ] stale-target resilience — `select` stores raw window/tab indices that silently break on reorder/close; capture the tab URL at select-time and re-resolve (or warn) when it changed.
- [ ] `wait-stable` via MutationObserver — current `body.innerHTML.length` diff loops forever on ads/spinners/clocks; switch to a no-mutation quiet window. *(highest leverage)*
- [ ] transient-retry — one silent retry on `execute javascript` before classifying failure (cuts false negatives after focus changes).

## Tier 5 — capability & reach

- [ ] `doctor` — one-shot diagnostic (✓/✗ + fix links): JS-from-AppleScript toggle on? Screen Recording granted? Accessibility granted? Chrome running? Collapses the permission-discovery cliff. *(highest leverage)*
- [ ] `batch` — one AppleScript, multiple JS steps, one JSON result; cuts per-command `osascript` launch overhead for agent loops while staying daemon-free. *(highest leverage)*
- [ ] `table "<sel>"` — scrape an HTML `<table>` to JSON `{headers, rows}` (common task; pure JS).
- [ ] rich-text `fill` — contenteditable fallback (`execCommand('insertText')` / dispatched `InputEvent`) for Notion/Gmail/Slack compose; plain `fill` only sets `.value`.
- [ ] consistent `--json` across all read/assert commands (`title`/`url`/`exists`/`click`/`fill`/… currently emit mixed bare strings / ad-hoc JSON).
- [ ] verify + document Brave/Edge/Arc — same Chromium AppleScript `execute … javascript` dictionary; `SURF_APP` plumbing + `_surf_pick_app` already exist, just untested. (Safari/Firefox genuinely excluded — different dictionaries.)

## Won't do (out of mechanism — by design)

- Console logs / network / perf traces / Lighthouse / heap → needs CDP → **chrome-devtools-mcp**
- Headless → drives your *visible* Chrome → **rodney**
- Cross-platform (Linux/Windows) → AppleScript is macOS-only → **rodney** / **chrome-devtools-mcp**
- PDF export → Chrome print dialog not cleanly AppleScript-automatable → **rodney**
- Agentic / LLM-driven → `surf` is deterministic; you're the loop → **browser-use / Stagehand / Skyvern**

## Done

- [x] v0.1.0 — tabs/here/open/new/reload/back/fwd/close, title/url/text/html/attr/count/eval, click/fill, select (bg tabs), shot, setup (52/52 furious)
