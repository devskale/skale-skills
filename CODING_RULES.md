# CODING_RULES

Single source of truth for repo conventions and coding rules (replaces the former
CONVENTION.md). This repo is the **source of truth** for all local skills,
extensions, and prompts — they become active via the **pi package**
(`pi install git:github.com/devskale/skale-skills`, see
[docs/installation.md](docs/installation.md)); for live-dev overrides use the
session-only flags in [docs/development.md](docs/development.md).

Every rule here is **objectively checkable** — some already enforced via
`test.sh`/grep/lint, the rest as review checkpoints.

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
3. Ship: commit + push + `pi update` — the package activates it
4. Live-dev before shipping: `pi --skill skills/<name>/SKILL.md` (session-only, zero cleanup)

### Extensions

1. Create `extensions/<name>.ts` (single file) or `extensions/<name>/index.ts`
2. Run `uv run index-skills.py` to update the index
3. Ship: commit + push + `pi update`
4. Live-dev before shipping: `pi -ne -e ./extensions/<name>.ts`
   (`-ne` first — extension tool-name collisions are a hard load error, see [docs/development.md](docs/development.md))

**Shared helper modules** (imported by multiple extensions, no default factory)
go in `extensions/lib/*.ts` — a subdir pi does **not** auto-discover as extensions
(no `index.ts`/`package.json`), so they don't need `!` exclusions in the
`./extensions/*.ts` glob. Extensions import them via `./lib/<name>`.

### Prompts

1. Create `prompts/<name>.md` with optional frontmatter (`description`)
2. Run `uv run index-skills.py` to update the index
3. Ship: commit + push + `pi update`

## Notable Packages

External pi packages referenced here. **Not active in this dev repo** — documented
for reference and index discovery.

### Adding

Create `notable/<package-name>.md`:

```markdown
# pi-web-access

- **Install:** `pi install npm:pi-web-access`
- **Repo:** https://github.com/nicobailon/pi-web-access
- **Provides:** librarian (skill)
- **Config:** optional API keys in `~/.pi/web-search.json`
- **Scope:** project (`.pi/settings.json`)
```

Required fields: **Install**, **Provides**, **Scope**
(`project` = `.pi/settings.json`, `global` = `~/.pi/agent/settings.json`).
Optional: **Repo**, **Config**, **Notes**.

### Removing

1. Remove the package from `.pi/settings.json` or `~/.pi/agent/settings.json`
2. Run `pi uninstall <package>` if it was installed
3. Delete `notable/<package-name>.md`
4. Run `uv run index-skills.py`

## Index & Activation

`SKILL-INDEX.md` is auto-generated (`uv run index-skills.py` — always run it after
adding/removing/renaming a resource). Status badges:

- 🟢 **global** — symlinked to `~/.pi/agent/` (active everywhere)
- 🔵 **package** — provided by a global npm package (active everywhere)
- 📝 **notable** — project-local package (reference only, not active here)
- ⚪ **available** — in this repo but not active anywhere

| Method | Scope | Where documented |
|--------|-------|------------------|
| **pi package** (this repo) | global, filtered via `pi config` | [docs/installation.md](docs/installation.md) |
| Project-local `.pi/skills/` | project only, no config | pi docs |
| Settings entries (`"skills": [...]`) | global or project | [docs/installation.md](docs/installation.md) |
| Session-only flags (`pi --skill`, `pi -ne -e`) | one run, zero cleanup | [docs/development.md](docs/development.md) |
| Loose symlink into `~/.pi/agent/` | legacy — conflicts with the package | [docs/installation.md](docs/installation.md) |

## Repo Rules

- This repo is for **development only** — no project-local `.pi/skills/`, `.pi/extensions/`, `.pi/prompts/`
- Activation happens via the **pi package** (`pi install` + `pi config`), not loose symlinks
- Always run `uv run index-skills.py` after adding, removing, or renaming a resource
- Notable packages are documented, not activated

---

## Skill Best Practices

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

**Body** — keep it under 100 lines (**enforced**: add a line-count check to the
skill's `test.sh`). Use `fetch-url "url"` not `cd ~/.pi/.../ && uv run scripts/...`.

**Keeping it short** — full curated list:
[docs/agent-skills-best-practices.md](docs/agent-skills-best-practices.md) §5 "Size budget":

- SKILL.md is the **routing layer**, not the knowledge base — what/when, one start
  command, the 2–3 most load-bearing gotchas, links to `references/`.
- **Assume the model is smart** — write only what it can't know; every paragraph must
  justify its token cost.
- **Gotchas > 5** → `references/gotchas.md` (top 2–3 stay inline); details move to
  `references/`, examples to `assets/` — move, don't delete.
- Bullets over prose; one worked example, not three.

**Anti-patterns:**
- Long `cd ~/.pi/agent/skills/<name> && uv run scripts/<file>` — use the installed command
- Verbose explanations of basic concepts
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

`--update` and auto-update must **never** operate in the caller's cwd — the git
root is walked up from `SKILL_DIR` (`GIT_ROOT`), not from `pwd`.

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

---

## Coding Rules (always-on)

Grounded in [Learnings from the Codex repo](docs/codex-learnings.md) — as
implementation gets cheaper, tests, boundaries, and lint matter *more*, not less.

### Invocation & cwd

- Skills are invoked **bare**: `web-search "query"`, `fetch-url "url"` — from
  **any** cwd. No leading `cd <dir> &&`, no `export PATH=`, no fully-qualified
  launcher path.
- Launcher and scripts must be **cwd-independent**:
  - Launcher resolves `SKILL_DIR` via `BASH_SOURCE[0]` + symlink loop — never cwd.
  - Scripts resolve config/data files via `Path(__file__).parent` (→ absolute
    `SKILL_DIR`-relative paths) — never `os.getcwd()`, never bare relative paths.
  - No artifacts (temp files, downloads, output) in the caller's cwd.
- `cd "$SKILL_DIR" && exec uv run …` is acceptable **only** when the script
  doesn't read/write relative to the caller's cwd. It runs the script with
  `SKILL_DIR` as its cwd (the caller's *shell* cwd is unaffected — child process),
  so relative writes land in the skill dir, not the caller's. When output belongs
  to the caller's cwd, use:
  ```bash
  uv run --project "$SKILL_DIR" "$SKILL_DIR/scripts/main.py" "$@"
  ```

**Review stop** — fix, don't document, if any of these appear as the "usual"
invocation in a skill, guide, or agent prompt:
- `cd <anywhere> && <skill-command>`
- `export PATH="$HOME/.local/bin:$PATH"` as a prerequisite
- Full launcher path (`~/.pi/agent/skills/.../search`) as the standard call
- `cd "$SKILL_DIR" && uv run` in a launcher whose script writes to the caller's cwd

### Test Integrity

(Codex: "Never add or modify any code related to `CODEX_SANDBOX_*`")

- Code that tests observe — launcher flags (`--update`, `--selfcheck`), sentinel
  files (`.last-update`), env-var fallback order, output format — is **frozen**.
  A test that looks like it's in the way is the finding: report it, never "fix"
  it away.
- Test behavior that can regress; prune fake rigor — tests of statically defined
  values, negative tests of removed logic.
- Behavior changes (flag parsing, backend fallback, output format) MUST add an
  **integration test** — a real invocation of the command.

### Unambiguous Call Sites

(Codex enforces with a custom lint — 38 rules)

- Keyword arguments over positional `True`/`None`/magic numbers:
  `fetch(url, timeout_ms=1000)`, not `fetch(url, True, None, 1000)`.
- When an external API can't take keywords, comment each argument with its exact
  parameter name: `foo(/*enabled*/ False, 1000 /*timeout_ms*/)`.

### Migrations Leave Tombstones

(Codex's TUI migration)

Stage big behavior changes: new path alongside the old → flip the default →
delete the old path → leave a **tombstone** so it can't creep back: a grep
assertion in `test.sh` that fails if the old pattern returns (e.g. a retired
backend must not be re-imported). One-time cleanup erodes on a repo many agents
touch; CI doesn't forget.

### Credentials

- **Always use credgoo.** Never hardcode tokens, never commit `.env` with real
  secrets. Full guide: [docs/credgoo.md](docs/credgoo.md); resolution order in
  [AGENTS.md → Credentials](AGENTS.md#credentials--credgoo-first-class-citizen).
- Resolution order: env var → `credgoo` → `.env` (last resort, gitignored).
- Check related keys as fallback (e.g. `WEB_SEARCH_BEARER` if `FETCH_URL_BEARER` not set).
- `.env.example` is required when a skill uses credentials.

### Versions

Three places must agree:
- `SKILL.md` → `metadata.version: "2.6.0"`
- `pyproject.toml` → `version = "2.6.0"`
- Test: version alignment check

Default bump is **patch (+0.0.1)** — for every change, regardless of size. Minor
(+0.1.0) or major only when the user asks explicitly. Same policy for the repo
`package.json`. Bump commits are separate `chore:` commits — stage `package.json`
alone, never together with the change.

### Venv & Dependencies

**Keep the venv OUT of the repo** — pi runs `git clean -fdx` inside a package
after every update, which deletes any `.venv/`/`node_modules/`/`package-lock.json`
in the package path. Set in **BOTH launcher and install.sh**:

```bash
export UV_PROJECT_ENVIRONMENT="${UV_PROJECT_ENVIRONMENT:-$HOME/.cache/<pkg>/<skill>}"
```

Never commit `.venv/`, `node_modules/`, or `package-lock.json`. See
[docs/agent-skills-best-practices.md](docs/agent-skills-best-practices.md) →
Python dependencies & pi package updates.

### macOS Compatibility

- Never use `readlink -f` — GNU-only, doesn't exist on macOS
- Use `BASH_SOURCE` for script path resolution, not `$0`
- Validate syntax with `bash -n` before running
- Avoid nested `$(cd "$(dirname ...)" && pwd)` inside `$(...)` — can break in bash 3.2

### Python Style

- **Type hints mandatory** for all function args and return values
- **Google-style docstrings**
- **Graceful fallback** for optional imports: `try: import requests; except ImportError: requests = None`
- **Sanitize auth tokens** from error messages: `str(e).split("Authorization")[0]`
- **Separate connect/read timeouts**: `timeout=(5, 15)` not `timeout=30`
- **Error context**: capture `last_error` in loops instead of silently `continue`

---

## Testing

Every skill must have `tests/<skill-name>/test.sh`. Test categories:

| Category | What to check |
|----------|---------------|
| Command available | `command -v <name>` |
| Launcher flags | `--update`, `--selfcheck`, stamp file |
| cwd independence | run from a foreign dir; no artifacts left behind |
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

## Linting & Typechecking (extensions)

Run the repo's quick check on `extensions/*.ts` before shipping changes:

```bash
bash scripts/lint.sh            # typecheck + Biome lint
bash scripts/lint.sh --fix      # + Biome safe auto-fixes
bash scripts/lint.sh --type     # typecheck only
bash scripts/lint.sh --lint     # Biome lint only
# or: npm run lint / lint:fix / typecheck
```

- **Two gates:** `tsc --noEmit` (strict) + Biome lint (`biome check`, scoped to `extensions/`).
- **Self-healing toolchain:** deps install into `~/.cache/skale-skills/lint/`
  (NOT the repo) — same `git clean -fdx` protection as `UV_PROJECT_ENVIRONMENT`.
- **Type symlinks:** `scripts/lint.sh` recreates `node_modules/@earendil-works/*`
  symlinks and a local `tsconfig.json` if missing — both gitignored, never commit.
- **Biome config** is a correctness gate (unused imports/params/vars = errors),
  not a reformatter.
- **Exit code** non-zero on any error — use it in CI or a pre-push hook.

## Content Validation Lessons (fetch-url)

- **Scan only the first ~1500 chars** — real error pages are short
- **Strong patterns** (1 hit = reject): "checking your browser", "ray id:", "please enable javascript"
- **Weak patterns** (need 2+ hits): "cloudflare", "forbidden", "captcha", "access denied"
- **Long content is always valid** — no error page is >3000 chars
- A single word in a headline must NOT reject the whole page

**Site-specific tool hints** go in `settings.json`, not hardcoded in Python:

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

**w3m config:** always set `accept_encoding identity` — prevents gunzip errors
on GitHub and other sites.

## Rules Ladder

Where a guideline goes (from [docs/codex-learnings.md](docs/codex-learnings.md)):

1. A correction shows up **repeatedly in review** → write it here so the next
   human or agent sees it **before** making the same mistake.
2. Once the rule is stable and objectively checkable → **automate it**
   (assertion in `test.sh`, grep check, lint) and prune the prose.
   Expensive-and-checkable rules earn automation; judgment calls stay prose.
