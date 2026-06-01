# Convention

This repo is the **source of truth** for all local skills, extensions, and prompts.
Pi does NOT load these directories directly — they must be symlinked or installed to be active.

## Directory Structure

```
skale-skills/
├── skills/          # Skill source files (SKILL.md in subdirs)
├── extensions/      # Extension source files (.ts or subdirs with index.ts)
├── prompts/         # Prompt template source files (.md)
├── notable/         # Reference cards for notable packages
├── index-skills.py  # Reindex tool
└── SKILL-INDEX.md   # Auto-generated index
```

## Adding Resources

### Skills

1. Create `skills/<name>/SKILL.md` with frontmatter (`name`, `description`)
2. Run `uv run index-skills.py` to update the index
3. To activate: `ln -s $(pwd)/skills/<name> ~/.pi/agent/skills/<name>`
4. To deactivate: `rm ~/.pi/agent/skills/<name>`

### Extensions

1. Create `extensions/<name>.ts` (single file) or `extensions/<name>/index.ts`
2. Run `uv run index-skills.py` to update the index
3. To activate: `ln -s $(pwd)/extensions/<name>.ts ~/.pi/agent/extensions/<name>.ts`
4. To deactivate: `rm ~/.pi/agent/extensions/<name>`

### Prompts

1. Create `prompts/<name>.md` with optional frontmatter (`description`)
2. Run `uv run index-skills.py` to update the index
3. To activate: `ln -s $(pwd)/prompts/<name>.md ~/.pi/agent/prompts/<name>.md`
4. To deactivate: `rm ~/.pi/agent/prompts/<name>`

## Notable Packages

Notable packages are external pi packages referenced in this repo. They are
**not active here** — this is a dev repo — but documented for reference and
so the index can discover their skills/extensions/prompts.

### Adding a notable package

Create `notable/<package-name>.md`:

```markdown
# pi-web-access

Web search, URL fetching, GitHub repo cloning, PDF extraction,
and video understanding for Pi coding agent.

- **Install:** `pi install npm:pi-web-access`
- **Repo:** https://github.com/nicobailon/pi-web-access
- **Provides:** librarian (skill)
- **Config:** optional API keys in `~/.pi/web-search.json`
- **Scope:** project (`.pi/settings.json`)
```

Required fields:
- **Install** — how to install it
- **Provides** — what skills/extensions/prompts it bundles (for index discovery)
- **Scope** — where it's referenced (`project` = `.pi/settings.json`, `global` = `~/.pi/agent/settings.json`)

Optional fields:
- **Repo** — link to source
- **Config** — any setup beyond install (API keys, env vars, config files)
- **Notes** — anything else worth knowing

### Removing a notable package

1. Remove the package from `.pi/settings.json` or `~/.pi/agent/settings.json`
2. Run `pi uninstall <package>` if it was installed
3. Delete `notable/<package-name>.md`
4. Run `uv run index-skills.py`

## Index

`SKILL-INDEX.md` is auto-generated. It shows:

- **Notable Packages** — external packages referenced here (not active in this dev repo)
- **Global Packages** — packages active in `~/.pi/agent/settings.json`
- **Skills** — local skills with global/package/notable status
- **Extensions** — local extensions with status
- **Prompts** — local prompts with status

Status badges:
- 🟢 **global** — symlinked to `~/.pi/agent/` (active everywhere)
- 🔵 **package** — provided by a global npm package (active everywhere)
- 📝 **notable** — provided by a project-local package (reference only, not active here)
- ⚪ **available** — in this repo but not active anywhere

## Skill Activation Methods (Pi)

Pi discovers skills from multiple locations. Pick the right method for the job:

### 1. Project-local (inline)

For skills tied to a single project — put them in the project's `.pi/skills/`:

```
my-project/
├── .pi/
│   └── skills/
│       └── deploy/
│           └── SKILL.md    # Auto-discovered, only active inside my-project/
```

No config needed. Pi scans `.pi/skills/` automatically.

### 2. Skillpacks (preferred for reusable, multi-skill bundles)

For themed skill collections (e.g. `socializer`, `youtuber`, `data-analyst`),
create a pack directory and register it in pi settings:

```
~/code/agents/packs/
├── socializer/              # X/Twitter + Reddit + Mastodon skills
│   ├── peep/SKILL.md
│   ├── reddit/SKILL.md
│   └── mastodon/SKILL.md
├── youtuber/                # Video workflow skills
│   ├── video-edit/SKILL.md
│   ├── thumbnail/SKILL.md
│   └── upload/SKILL.md
└── data-analyst/            # Data pipeline skills
    ├── csv-tools/SKILL.md
    └── charts/SKILL.md
```

Activate globally in `~/.pi/agent/settings.json`:
```json
{
  "skills": [
    "~/code/agents/packs/socializer",
    "~/code/agents/packs/youtuber"
  ]
}
```

Or per-project in `.pi/settings.json`:
```json
{
  "skills": [
    "~/code/agents/packs/data-analyst"
  ]
}
```

Pi discovers all `SKILL.md`-containing directories recursively within
the registered path. One pack can contain many skills.

### 3. Skills in standalone repos

For tools with their own repo (like peep), put the skill inside the repo:

```
peep/                       # github.com/devskale/peep
├── .pi/
│   └── skills/
│       └── peep/
│           └── SKILL.md
└── src/...
```

Activate via symlink (global) or settings entry (project-local):
```bash
# Global
ln -s ~/code/agents/skills/peep/.pi/skills/peep ~/.pi/agent/skills/peep
```
```json
// Project-local .pi/settings.json
{ "skills": ["~/code/agents/skills/peep/.pi/skills/peep"] }
```

### 4. Global single skills

For one-off global skills, symlink into `~/.pi/agent/skills/`:

```bash
ln -s ~/code/agents/skills/skale-skills/skills/web-search ~/.pi/agent/skills/web-search
```

### When to use which

| Method | Best for | Scope | Config needed |
|--------|----------|-------|---------------|
| Project-local | Single-project skills | Project only | None |
| **Skillpacks** | **Reusable themed bundles** | Global or project | settings.json |
| Standalone repo | Tools with their own repo | Global or project | Symlink or settings |
| Global symlink | One-off shared skills | Global | Symlink |

## Rules

- This repo is for **development only** — no project-local `.pi/skills/`, `.pi/extensions/`, `.pi/prompts/`
- Source files live here, activation happens via symlinks to `~/.pi/agent/` or settings entries
- Always run `uv run index-skills.py` after adding, removing, or renaming a resource
- Notable packages are documented, not activated — they live in `.pi/settings.json` for reference
- **Skillpacks are the preferred pattern** for reusable multi-skill bundles (`~/code/agents/packs/<name>/`)
- For project-local skills, use `.pi/skills/` in the project — no config needed
