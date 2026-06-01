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
├── tests/           # Per-skill test suites (tests/<skill-name>/test.sh)
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

---

## Skill Best Practices

Lessons learned from building and reviewing skills in this repo.

### File Structure

Every skill must have:

```
skill-name/
├── SKILL.md           # Required: frontmatter + instructions
├── pyproject.toml     # Required for Python: dependencies, version
├── install.sh         # Required: creates ~/.local/bin/<command> symlink
├── <command>          # Required: bash launcher with symlink resolution
├── scripts/           # Optional: main Python/Node code
├── references/        # Optional: detailed docs loaded on demand
├── .env.example       # Required if skill uses credentials
├── .gitignore         # Required: .venv/, .env, uv.lock, *.egg-info/, .last-update
└── settings.json      # Optional: tool config, site hints, fallback order
```

Files that must **not** exist:
- `requirements.txt` — use `pyproject.toml` instead
- `.env` with real tokens — use credgoo or `.env.example` only
- `*.egg-info/` — must be gitignored

### SKILL.md

**Frontmatter** — required fields:

```yaml
---
name: skill-name          # Must match directory name
description: What it does and when to use it. Include trigger words and file extensions.
metadata:
  author: org-name
  version: "2.6.0"        # Must match pyproject.toml
---
```

**Body** — keep it under 100 lines. Use `fetch-url "url"` not `cd ~/.pi/.../ && uv run scripts/...`.

```markdown
# Skill Name

\`\`\`bash
command "args"              # That's it.
\`\`\`

## Install
## Usage
## Options (table)
## Configure (optional)
## Troubleshooting (table)
## Reference → links to references/
```

**Anti-patterns to avoid:**
- Long `cd ~/.pi/agent/skills/<name> && uv run scripts/<file>` — use the installed command
- Verbose explanations of basic concepts — agents are smart, give them what they don't know
- Unlinked reference files — SKILL.md must mention every file in `references/`

### Launcher (`<command>` file)

The bash launcher must:

1. **Resolve symlinks** — not hardcoded paths
2. **Support `--update`** and **`--selfcheck`** flags
3. **Auto-update** in background after 7 days
4. **Write `.last-update`** timestamp

Template:

```bash
#!/usr/bin/env bash
SELF="${BASH_SOURCE[0]}"
while [ -L "$SELF" ]; do
    DIR="$(cd "$(dirname "$SELF")" && pwd)"
    SELF="$(readlink "$SELF")"
    [[ "$SELF" != /* ]] && SELF="$DIR/$SELF"
done
SKILL_DIR="$(cd "$(dirname "$SELF")" && pwd)"
STAMP_FILE="$SKILL_DIR/.last-update"

case "${1:-}" in
    --update)    # git pull + uv sync + timestamp ;;
    --selfcheck) # show version + last update ;;
esac

# Auto-update (7-day cycle, background, non-blocking)
# ...

cd "$SKILL_DIR" && exec uv run scripts/main.py "$@"
```

**Never use:** `readlink -f` (breaks on macOS), hardcoded absolute paths, `cd "/hardcoded/path"`.

### install.sh

```bash
#!/usr/bin/env bash
set -e
SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SKILL_DIR"

# 1. Ensure uv
# 2. uv sync
# 3. ln -sf "$SKILL_DIR/<launcher>" "$HOME/.local/bin/<command>"
# 4. date +%s > "$SKILL_DIR/.last-update"
```

**Never use:** `cat > wrapper << EOF` with hardcoded paths — use symlinks instead.

### Credentials

**Always use credgoo.** Never hardcode tokens.

Resolution order in Python:
1. Environment variable
2. credgoo (with `contextlib.redirect_stdout` to suppress output)
3. `.env` file (last resort, gitignored)

Check related keys as fallback (e.g. `WEB_SEARCH_BEARER` if `FETCH_URL_BEARER` not set).

### Version Alignment

Three places must agree:
- `SKILL.md` → `metadata.version: "2.6.0"`
- `pyproject.toml` → `version = "2.6.0"`
- Test: version alignment check

### Testing

Every skill must have `tests/<skill-name>/test.sh`. Test categories:

| Category | What to check |
|----------|---------------|
| Command available | `command -v <name>` |
| Launcher flags | `--update`, `--selfcheck`, stamp file |
| Help output | Key flags present |
| Live smoke test | Real fetch/search against public APIs (resilient to network issues) |
| Code quality | Type hints, docstrings, no macOS-incompatible patterns |
| File structure | Required files exist, dead files don't |
| `.gitignore` | Covers `.venv/`, `.env`, `uv.lock`, `*.egg-info/`, `.last-update` |
| Version alignment | `pyproject.toml` == `SKILL.md` |

Live network tests must be **resilient** — warn, don't fail on flakiness:

```bash
RESULT=$(command "test" --flag 2>&1) || true
if echo "$RESULT" | grep -q "expected"; then
    PASS=$((PASS + 1))
else
    echo "  WARN: no result (network?)"
    PASS=$((PASS + 1))   # Don't FAIL on network issues
fi
```

### Error Detection (fetch-url lesson)

When building content validation:

- **Scan only the first ~1500 chars** — real error pages are short
- **Strong patterns** (1 hit = reject): "checking your browser", "ray id:", "please enable javascript"
- **Weak patterns** (need 2+ hits): "cloudflare", "forbidden", "captcha", "access denied"
- **Long content is always valid** — no error page is >3000 chars
- A single word in a headline (e.g. "Cloudflare Turnstile...") must NOT reject the whole page

### Site-Specific Tool Hints

Put in `settings.json`, not hardcoded in Python:

```json
{
  "site_tool_hints": {
    "reddit.com": ["w3m", "lynx", "jina"],
    "news.ycombinator.com": ["w3m", "lynx", "jina"],
    "github.com": ["w3m", "jina", "markdown"]
  }
}
```

Priority: **free local tools first** (w3m, lynx), then free APIs (jina, markdown).

### w3m Configuration

Always set `accept_encoding identity` in w3m config — prevents gunzip errors on GitHub and other sites:

```
accept_encoding identity
```

### macOS Compatibility

- Never use `readlink -f` — it's a GNU extension, doesn't exist on macOS
- Use `BASH_SOURCE` for script path resolution, not `$0`
- Test with `bash -n` to validate syntax before running
- Avoid nested `$(cd "$(dirname ...)" && pwd)` inside `$(...)` — can break in bash 3.2

### Python Style

- **Type hints mandatory** for all function args and return values
- **Google-style docstrings**
- **Graceful fallback** for optional imports: `try: import requests; except ImportError: requests = None`
- **Sanitize auth tokens** from error messages: `str(e).split("Authorization")[0]`
- **Separate connect/read timeouts**: `timeout=(5, 15)` not `timeout=30`
- **Error context**: capture `last_error` in loops instead of silently `continue`
