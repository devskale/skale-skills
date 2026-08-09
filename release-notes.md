# Release Notes

Log of notable changes to skale-skills. Newest first.

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
