# Deprecated skills

These skills have been retired from the active package. They live here at `skills/deprecated/<name>/SKILL.md` for reference and archaeology.

**How they're kept out of the running agent:** the package manifest `package.json` → `pi.skills` is `["./skills", "!./skills/deprecated/**"]` — the **`!` glob-exclude** excludes everything under this directory at the **manifest level**, so it ships with the package and every user gets it. As a redundant safety net, the settings filter `!skills/deprecated/**` in `~/.pi/agent/settings.json` also excludes this tree. This filtering is the **only** mechanism that stops them loading — pi discovers `SKILL.md` **recursively**, so the extra depth alone does **not** hide them. If you remove both the manifest entry and the settings entry, every archived skill here comes back.

> **Use `!` (glob exclude), not `-` (force-exclude).** `matchesAnyExactPattern` (used for `-`) does exact string matching and **does not expand globs** — so `-skills/deprecated/**` is a silent no-op. The `!` form uses minimatch and correctly matches `skills/deprecated/**`. (Exact single-file entries like `-skills/youtube/SKILL.md` are fine as `-` since they're exact paths.)

| Skill | Was | Replaced by |
|---|---|---|
| `todo` | TODO.md task tracking for multi-step work | — |
| `agent-skill-creator` | Guide for creating skills for any AI agent | — |
| `agents-md-init` | Create and update AGENTS.md files | — |
| `command-creator` | Custom commands for pi and OpenCode | — |
| `improve-skill` | Improve skills from session transcripts | — |
| `readme-write` | Generate and update README.md files | — |
| [`viewimg`](viewimg/SKILL.md) | Display an image in the terminal (view-only, no VLM) | `read img.jpg` (native display) + `read_image`/`/readimg` (VLM). See [docs/image-display-deprecation.md](../../docs/image-display-deprecation.md) |

To use one anyway, symlink it to a depth pi scans:

```bash
ln -s "$PWD/skills/deprecated/<name>" ~/.pi/agent/skills/<name>
```

## Archiving a skill (convention)

When a skill is superseded, **archive** it here rather than deleting or leaving it live. Full checklist in [AGENTS.md → Deprecation & Archiving](../../AGENTS.md):

1. `git mv skills/<name> skills/deprecated/<name>` — move it into the excluded tree.
2. `git mv tests/<name> tests/deprecated/<name>` — keep the backward-compat suite with the code.
3. Add a row to the table above (Skill | Was | Replaced by).
4. Fix the `~/.local/bin/<cmd>` symlink to the new path.
5. Regenerate `SKILL-INDEX.md` (`uv run index-skills.py`).
6. Update `AGENTS.md` + any docs; point the migration guide at the new path.

**It stays excluded via the manifest glob filter (with a settings safety net), not the depth.** Do not rely on directory depth to hide a skill — pi loads `SKILL.md` recursively. The `!./skills/deprecated/**` entry in `package.json` → `pi.skills` is what keeps the whole archive out and ships with the package; the `!skills/deprecated/**` entry in `~/.pi/agent/settings.json` is the per-user safety net. Leave both in place (use `!`, the glob-exclude form — `-` force-exclude does exact matching and won't expand the `**`).

**Path-depth gotcha:** test scripts reach the repo root with `cd "$(dirname "$0")/../.."`. Moving a test one level deeper (to `tests/deprecated/<name>/`) silently lands it in `tests/` and every check fails with exit 127 — bump the `../` depth to match and re-run before committing.
