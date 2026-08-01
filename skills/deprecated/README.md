# Deprecated skills

These skills have been retired from the active package and are **no longer auto-loaded** by `pi install`. They live here at `skills/deprecated/<name>/SKILL.md` — one level deeper than pi scans (it discovers only `skills/<name>/SKILL.md`), so the loader skips them. Kept for reference and archaeology.

| Skill | Was |
|---|---|
| `todo` | TODO.md task tracking for multi-step work |
| `agent-skill-creator` | Guide for creating skills for any AI agent |
| `agents-md-init` | Create and update AGENTS.md files |
| `command-creator` | Custom commands for pi and OpenCode |
| `improve-skill` | Improve skills from session transcripts |
| `readme-write` | Generate and update README.md files |

To use one anyway, symlink it to a depth pi scans:

```bash
ln -s "$PWD/skills/deprecated/<name>" ~/.pi/agent/skills/<name>
```
