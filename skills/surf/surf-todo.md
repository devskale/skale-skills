# Surf — TODO

Checkable roadmap. Workflow per item: **implement → validate (`tests/surf/furious.sh`) → commit → check the box.**

Status: `surf v1.3.1` — modular `lib/` structure, stale-target resilient `select`, navigation/tabs, reads, assertions, interactions, waits (MutationObserver), screenshots, `--json`, `doctor`, `batch`, classified JS-failure messages.

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

- [x] `form 'sel1=val1' 'sel2=val2'` — batch fill *(v1.4.2)*
- [x] `download "<sel>"` — trigger + monitor a download *(v1.4.2; best-effort — Chrome v136+ temp-dir aware; "Ask where to save" blocks)*
- [x] `activate <wN.tN>` / `find-tab "<query>"` — focus a tab / search tabs *(v1.4.2: `find-tab "<q>" [--activate]`)*
- [x] full-page screenshot (scroll + stitch) *(v1.4.2: `shot-full`, Pillow stitch)*
- [x] `cookie "<name>"` / localStorage read *(v1.4.2: `cookie` [name], `localstorage` [key])*
- [x] `bookmarks` — read/search Chrome bookmarks *(v1.4.2: `bookmarks [query] [--profile] [--json]`)*

## Tier 4 — reliability & robustness

- [x] robust JS-failure classification — replace the O(N) up-to-10-tab probe in `_explain_js_failure` with a cheaper deterministic signal (single `about:blank` sentinel probe on the target window + incognito short-circuit). Resolves the x.com/incognito/PWA ambiguity without a scan. *(v1.4.1)*
- [x] stale-target resilience — `select` stores raw window/tab indices that silently break on reorder/close; capture the tab URL at select-time and re-resolve (or warn) when it changed. *(v1.3.1)*
- [x] `wait-stable` via MutationObserver — current `body.innerHTML.length` diff loops forever on ads/spinners/clocks; switch to a no-mutation quiet window. *(v1.2.0)*
- [ ] transient-retry — one silent retry on `execute javascript` before classifying failure (cuts false negatives after focus changes).

## Tier 5 — capability & reach

- [x] `doctor` — one-shot diagnostic (✓/✗ + fix links): JS-from-AppleScript toggle on? Screen Recording granted? Accessibility granted? Chrome running? Collapses the permission-discovery cliff. *(v1.2.0)*
- [x] `batch` — one AppleScript, multiple JS steps, one JSON result; cuts per-command `osascript` launch overhead for agent loops while staying daemon-free. *(v1.2.0)*
- [x] `table "<sel>"` — scrape an HTML `<table>` to JSON `{headers, rows}` (common task; pure JS). *(v1.4.3)*
- [x] rich-text `fill` — contenteditable fallback (`execCommand('insertText')` / dispatched `InputEvent`) for Notion/Gmail/Slack compose; plain `fill` only sets `.value`. *(v1.4.3: auto-detected; returns `mode`)*
- [x] consistent `--json` across all read/assert commands (`title`/`url`/`exists`/`click`/`fill`/… currently emit mixed bare strings / ad-hoc JSON). *(v1.4.3: title/url/html/attr/exists/visible/assert; click/fill already JSON)*
- [ ] verify + document Brave/Edge/Arc — same Chromium AppleScript `execute … javascript` dictionary; `SURF_APP` plumbing + `_surf_pick_app` already exist, just untested. (Safari/Firefox genuinely excluded — different dictionaries.)

## Won't do (out of mechanism — by design)

- Console logs / network / perf traces / Lighthouse / heap → needs CDP → **chrome-devtools-mcp**
- Headless → drives your *visible* Chrome → **rodney**
- Cross-platform (Linux/Windows) → AppleScript is macOS-only → **rodney** / **chrome-devtools-mcp**
- PDF export → Chrome print dialog not cleanly AppleScript-automatable → **rodney**
- Agentic / LLM-driven → `surf` is deterministic; you're the loop → **browser-use / Stagehand / Skyvern**

## Done

- [x] v1.4.3 — Tier 5: `table` scraper; rich-text `fill` (contenteditable auto-detect, `mode` field); consistent `--json` on title/url/html/attr/exists/visible/assert. Fix: title/url dispatch now passes `"$@"` (--json was silently dropped). furious 124/124.
- [x] v1.4.2 — Tier 3 commands: `form` (batch fill), `find-tab` (--activate), `bookmarks` (--profile/--json), `cookie`, `localstorage`, `download` (Chrome v136+ temp-dir aware), `shot-full` (scroll + Pillow stitch). furious 111/111.
- [x] v1.4.1 — robust JS-failure classification: O(1) `about:blank` sentinel probe (mirrors `doctor`'s validated toggle test) + incognito short-circuit; drops the O(N) 10-tab scan and `surf tabs` subprocess re-entry. furious 101/101.
- [x] v1.4.0 — self-discoverable help: `surf help` categorized overview + `surf help <command>` / `surf <command> --help` per-command detail (usage, return, example, see-also); new `lib/help.sh`. Bash-3.2-safe (no associative arrays).
- [x] v1.3.1 — modular `lib/` (engine/target/nav/read/wait/interact/assert/shot/meta/main); stale-target resilient `select` (URL-sticky, re-pins on drift); github-org stats + drift tests (98/98 furious)
- [x] v1.2.0 — `doctor`, `batch`, `wait-stable` (MutationObserver); JSON tab helpers in tests (93/93 furious)
- [x] v0.1.0 — tabs/here/open/new/reload/back/fwd/close, title/url/text/html/attr/count/eval, click/fill, select (bg tabs), shot, setup (52/52 furious)
