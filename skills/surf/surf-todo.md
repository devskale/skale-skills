# Surf — TODO

Checkable roadmap. Workflow per item: **implement → validate (`tests/surf/furious.sh`) → commit → check the box.**

Status: `surf v0.1.0` — navigation, reads, click/fill, eval, select, shot.

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
- [ ] `shot "<sel>"` — element screenshot (scroll-into-view + getBoundingClientRect + `screencapture -R`)

## Tier 3 — nice to have

- [ ] `form 'sel1=val1' 'sel2=val2'` — batch fill
- [ ] `download "<sel>"` — trigger + monitor a download
- [ ] `activate <wN.tN>` / `find-tab "<query>"` — focus a tab / search tabs
- [ ] full-page screenshot (scroll + stitch)
- [ ] `cookie "<name>"` / localStorage read

## Won't do (out of mechanism — by design)

- Console logs / network / perf traces / Lighthouse / heap → needs CDP → **chrome-devtools-mcp**
- Headless → drives your *visible* Chrome → **rodney**
- Cross-platform (Linux/Windows) → AppleScript is macOS-only → **rodney** / **chrome-devtools-mcp**
- PDF export → Chrome print dialog not cleanly AppleScript-automatable → **rodney**
- Agentic / LLM-driven → `surf` is deterministic; you're the loop → **browser-use / Stagehand / Skyvern**

## Done

- [x] v0.1.0 — tabs/here/open/new/reload/back/fwd/close, title/url/text/html/attr/count/eval, click/fill, select (bg tabs), shot, setup (52/52 furious)
