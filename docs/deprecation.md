# Deprecating a skill — the procedure

When a skill is superseded (like `viewimg` → `read img.jpg`), **archive** it rather than
deleting it or leaving it live: history stays for archaeology, the active package stays
clean. The folder semantics (why there are two `deprecated/` folders, and why they must
not merge) live in [LAYOUT.md](../LAYOUT.md); this page is the how-to.

## Steps

1. **Move** `skills/<name>/` → `deprecated/<name>/`. The exclusion ships with the
   package: `package.json` → `pi.skills` is `["./skills", "!deprecated/**"]` — the
   `!` glob-exclude keeps the whole archive out at the **manifest level**, so every user of
   the package gets it without touching their own settings.
2. **Move** `tests/<name>/` → `tests/deprecated/<name>/` alongside it (the backward-compat
   suite stays with the code).
3. **Add a row** to [`deprecated/README.md`](../deprecated/SKILLS-README.md)
   (Skill | Was | Replaced by).
4. **Fix the `~/.local/bin/<cmd>` symlink** — it points into the old path and silently
   breaks otherwise.
5. **Regenerate** `SKILL-INDEX.md` (`uv run index-skills.py`).
6. **Update references** in AGENTS.md and other docs; point the migration guide at the new
   path. `tests/docs/test.sh` fails on docs orphans, so a moved doc must be re-linked.
7. Keep the archived `SKILL.md`'s deprecation banner and migration table; the launcher
   stays functional for backward-compat but is frozen (no further development).

## Load-bearing traps

**Never prefix manifest glob-excludes with `./`.** pi matches patterns against
package-root-relative paths via minimatch, and `!./deprecated/**` silently matches
**nothing** — minimatch does not strip the leading `./`. Confirmed against pi's own matcher
(2026-09-21): `"./deprecated/**"` → false, `"deprecated/**"` → true. The
broken form shipped for weeks while deprecated skills stayed active on fresh installs.

**Use `!` (glob exclude), never `-` (force-exclude), for tree excludes.** `-` does exact
string matching and silently ignores the `**` glob — `-deprecated/**` is a no-op.
Exact single-file entries like `-skills/youtube/SKILL.md` are fine as `-`.

**Keep the settings filter as a redundant safety net.** pi discovers `SKILL.md`
recursively, so directory depth alone does **not** hide a skill — the manifest exclude
*and* the `!deprecated/**` entry in `~/.pi/agent/settings.json` are what keep the
archive out. Remove both and every archived skill comes back.

**Bump the path depth when moving a test deeper.** Test scripts reach the repo root with
`cd "$(dirname "$0")/../.."`. Moving one level deeper (e.g. `tests/viewimg/` →
`tests/deprecated/viewimg/`) lands the script in `tests/` instead of the root and every
check fails with exit 127. Always re-run the moved suite before committing.

## Helper: `scripts/skill-filter.sh`

Manages the settings/MCP filters so nobody hand-edits JSON and hits the `-` vs `!` trap.
It edits `~/.pi/agent/settings.json` (per-user filter); the **package-author** manifest
exclusion in `package.json` is edited directly (or via `./install.sh`), since it ships with
the package:

```bash
scripts/skill-filter.sh list                          # show package filters + MCP servers
scripts/skill-filter.sh disable skill deprecated      # → !deprecated/**  (whole tree)
scripts/skill-filter.sh disable skill viewimg         # → -deprecated/viewimg/SKILL.md
scripts/skill-filter.sh enable  skill viewimg         # → +deprecated/viewimg/SKILL.md
scripts/skill-filter.sh disable extension imagegen    # → -extensions/imagegen.ts
scripts/skill-filter.sh disable mcp chrome-devtools   # remove from ~/.config/mcp/mcp.json
```

It writes the correct `!` glob for tree excludes and `-`/`+` exact paths for single
resources (matching what `pi config` generates), and never touches real settings/MCP files
in its test suite (`tests/skill-filter/` runs against temp copies).
