# Release Notes

Log of notable changes to skale-skills. Newest first.

## 2026-08-12

### visualize (new)
- **Added:** `visualize` skill — render any set of things as ONE self-contained HTML document and share a URL. Agent understands what you want to visualize, picks a structure (cards, grid, before-after, timeline, list, flow, hierarchy, comparison), builds a single portable HTML file, then opens it locally and uploads it to the throway store for a short-lived URL.
- **Launcher:** `visualize open <file>` / `visualize share <file>` / `visualize validate <file>`; `install.sh`/`install.bat` → `~/.local/bin/visualize`.
- **References:** `structures.md` (structure catalogue) + `html-patterns.md` (inline-CSS scaffold, SVG arrows, optional Mermaid).
- **Test suite:** `tests/visualize/test.sh` — 15 checks incl. live throway upload.

### extensions (imagegen)
- **Changed:** model discovery now probes the per-provider `/image/models/<provider>` endpoint (fallback: filtered `/models` catalog) — no hardcoded model names.
- **Added:** `isModelUnavailable` detection — a 400 model-unavailable (renamed/removed) is now a probe signal that falls through to an available model instead of failing hard; only genuine failures (auth/network/timeout) surface as-is.

### deprecated
- **Deprecated:** the `skiller` CLI moved to `deprecated/skiller/` (kept for reference). Its multi-agent-install niche is served by `openskills` / `npx @anthropic-ai/skills add` / `skills.sh`. Docs, README, and architecture diagrams updated to drop it.

## 2026-08-11

### rodney
- **Renamed:** the `jodney` skill back to **`rodney`** (matches `devskale/rodney`, working branch `skale`). Renamed skill dir `skills/jodney/` → `skills/rodney/`, `tests/jodney/` → `tests/rodney/`, `guides/jodney-setup.md` → `guides/rodney-setup.md`, and `test_jodney.sh` → `test_rodney.sh`.
- **Fixed:** env vars to match the `skale` branch — `RODNEY_CHROME_BIN`/`RODNEY_TIMEOUT` → `ROD_CHROME_BIN`/`ROD_TIMEOUT` (go-rod standard); kept `RODNEY_HOME`.
- **Removed:** the `--update` self-update command from docs — the `skale` branch no longer has it; install/refresh now `git clone -b skale` + `go build`.
- **Docs:** updated AGENTS.md, README, SKILL-INDEX, browser-tools comparison, surf/peep cross-refs, diagrams, and setup guides to the `rodney` name.

## 2026-08-09

### extensions
- **Added:** shared `extensions/lib/image-utils.ts` unifying `isVisionCapable`, `guessMime`, and `isValidImage` across xmodel + imagegen (each previously carried a copy).
- **Moved:** shared helper modules (`session-state.ts`, `xmodel-config.ts`, `xmodel-vision-utils.ts`, `image-utils.ts`) into `extensions/lib/` — a subdir pi doesn't auto-discover as extensions, so the `package.json` extension glob is clean again (no `!` exclusions). Extensions import via `./lib/<name>`.
- **Removed:** a Middle Man re-export (`isValidImage` now imported directly) and dead `extractFinalAssistantText`.

## 2026-08-09

### xmodel
- **Added:** extracted the pure config store into `extensions/xmodel-config.ts` and the stateless vision helpers into `extensions/xmodel-vision-utils.ts`. xmodel.ts dropped from 1719 → 1468 lines. The stateful vision pipeline (delegate/human/view) stays in xmodel.ts.

### surf
- **Changed:** split `help.sh` (920-line data monolith) into `help-overview.sh` (the categorized index) + `help-command.sh` (per-command detail + dispatcher). Verified byte-identical output for all 45 commands.
- **Documented:** `surf.sh` now declares THE SEAM — `run_js` (engine.sh) + `get_target` (target.sh) are the two load-bearing interfaces every command routes through; `$APP`/`$TARGET_FILE` are read-only shared config.

### package
- **Fixed:** helper modules (`session-state.ts`, `xmodel-config.ts`, `xmodel-vision-utils.ts`) are now excluded from the extension glob so pi doesn't try to load them as extensions.

## 2026-08-09

### fetch-url / web-search
- **Changed:** dropped the copy-pasted global-first `sys.path` credgoo bootstrap and the `credgoo_get` wrapper. Both now import `get_api_key` directly (declared dependency, resolved to credgoo 0.1.14). Missing keys log at DEBUG — silent by default, opt-in loud via a DEBUG handler. Removed the `contextlib.redirect_stdout` cargo-cult from docs.

### extensions (xmodel / heartbeat)
- **Added:** shared `extensions/session-state.ts` with `reconstructLastCustomEntry` + `isStaleCtxError`.
- **Changed:** xmodel + heartbeat now import these from the shared module instead of duplicating them; each keeps its own session handler wiring. statusline untouched (different read shape).

## 2026-08-09

### viewimg
- **Changed:** `viewimg` accepts **multiple files**; `--open` opens **all** images in **one** Preview window (tabs) via `open -a Preview` — Preview reuses its window across calls, so repeated `viewimg --open` never stacks up multiple windows.

### xmodel
- **Changed:** `read_image` is **opt-in** — the model must not autonomously call it right after a plain `read`/`viewimg` (those are display-only and fast). Only an explicit "understand/analyze" request fires the VLM.

### viewimg (new skill)
- **Added:** `viewimg` — show an image in the terminal **view-only** (never VLM). Renders as ANSI block art via `chafa`, or opens natively with `open` on macOS (`--open`). Understanding stays opt-in (`read_image` / `/readimg`).

## 2026-08-09

### figure / imagegen / d2
- **Changed:** generated/derived output now lands in the **XDG-standard** `$XDG_CACHE_HOME/generated/` (default `~/.cache/generated/`) — regenerable cache belongs in the cache dir per the XDG Base Directory Specification (web-grounded). No more hardcoded `~/generated/images` / `~/Pictures/generated` / `~/.generated`.
- **figure:** output dir resolves `$XDG_CACHE_HOME/generated` (override `FIGURE_OUT_DIR`); docs updated.
- **imagegen:** `outputDir()` resolves `$XDG_CACHE_HOME/generated` (override `IMAGEGEN_OUTPUT_DIR`); `uploads/` web-serving unchanged.
- **d2:** documented `~/.cache/generated/` as the default for rendered diagrams.

## 2026-08-09

### xmodel v0.4.0
- **Changed:** `read` (and `view`/`generate_image`) are now **display-only** — they show the image but **never trigger the VLM**. Understanding is opt-in.
- **Added:** `read_image` tool + `/readimg` command — explicit "understand" path that runs the VLM on an image and returns the text analysis. `/readimg` with no args shows help; `/readimg settings` opens the vision hub to pick the image model (`_vision.vlm`).
- **Added:** `analyzeImageFile` helper (VLM sub-call via child-pi `@file`), shared by `read_image` and `/readimg`.

### imagegen
- **Changed:** default model → `pollinations@dreamshaper` (cheapest); model discovery via the OpenAI-compatible `/models` catalog (any provider/modelid), generic key resolution, keyless providers supported.
- **Added:** self-healing default — remembers last-good model per provider, falls back through cheaper models on 402, learns costs from 402 responses (no hardcoded models/costs).

## 2026-06-22

### web-search
- **Fixed:** launcher had a hardcoded macOS path (`/Users/johannwaldherr/...`), broken on Linux. Replaced with portable symlink resolution.
- **Added:** `--update`, `--selfcheck`, 7-day auto-update, and a credgoo health check to the launcher.
- **Changed:** `install.sh` now symlinks `~/.local/bin/web-search` to the tracked `search` launcher (matching `fetch-url`'s pattern) instead of generating a script.

### statusline
- **Docs:** improved header doc-comment — documents the three intentional changes vs. the built-in footer (machineName prepend, Z.ai usage append, stats reorder for progressive skip) and the `(auto)` compaction caveat.

### repo / docs
- **Added:** `docs/installation.md` → "Loose-file conflicts" section — pi auto-loads `~/.pi/agent/skills/` symlinks and hand-copied `~/.pi/agent/extensions/*.ts`, which collide with the git package by **identity** (not content).
- **Added:** `docs/development.md` — the dev loop for skills & extensions: edit in the working tree → push upstream → `pi update --extension` → **then** remove dev overrides. Documents the critical catch (removing an override before the fix lands = silent regression).
- **Updated:** `AGENTS.md` Docs table links both new docs.

### context
- A dev-machine cleanup prompted these docs: stale `~/.pi/agent/skills/{fetch-url,web-search}` symlinks and a loose `~/.pi/agent/extensions/statusline.ts` were causing pi's `[Skill conflicts]` startup warning. Removed them so the git package is the sole source. (See `docs/installation.md`.)
