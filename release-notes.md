# Release Notes

Log of notable changes to skale-skills. Newest first.

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
