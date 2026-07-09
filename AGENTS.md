# Skale Skills - Agent Instructions

This repo contains **our own skills** (actively developed) and the `skiller` CLI.
External skills (docx, xlsx, etc.) should be installed from upstream — see `RECOMMENDED-SKILLS.md`.

## Our Skills

| Skill | Command | Tests | What |
|-------|---------|-------|------|
| fetch-url | `fetch-url "url"` | 49 | Web content extraction with smart fallback |
| web-search | `web-search "query"` | 38 | Web search via SearXNG + Duck API |
| youtube | `youtube "query"` | 32 | YouTube search via Invidious API with auto-fallback |
| vtd | `vtd transcript --url '...'` | 43 | Video/audio/transcript downloader (yt-dlp) |
| rodney | `rodney start/open/stop` | 32 | Headless Chrome automation |

## Installation (as a pi package)

This repo is a **pi package** — `package.json` declares a `pi` manifest (`./skills`, `./extensions/*.ts`, `./prompts`). Install it; don't symlink individual files (symlinks + the package co-load as different identities → conflicts; see [docs/installation.md](docs/installation.md)).

### Install once, globally

```bash
pi install git:github.com/devskale/skale-skills
```

Clones to `~/.pi/agent/git/github.com/devskale/skale-skills`, writes to `~/.pi/agent/settings.json`.

### Default state (current global config)

```jsonc
// ~/.pi/agent/settings.json
{ "packages": [{
  "source": "git:github.com/devskale/skale-skills",
  "skills": ["fetch-url", "web-search"],  // only these load; rest OFF
  "extensions": []                        // all extensions OFF
}]}
```

**Filter semantics** (verified from pi source — these decide what loads):

| `skills` / `extensions` array | Result |
|---|---|
| key **omitted** | load **all** of that type |
| `[]` | load **none** (explicitly off) |
| `["name1", "name2"]` (plain) | load **only** named (whitelist) |
| `"!pattern"` | exclude glob matches |
| `"+path"` / `"-path"` | force include / exclude an exact path |

Plain-name includes match by skill **directory name** (e.g. `"rodney"`). Paths match relative to package root (e.g. `"+skills/rodney/SKILL.md"`).

### Turn skills/extensions on — two ways

**1. Interactive (`pi config`)** — recommended for ad-hoc toggling:
```bash
pi config              # TUI: space=toggle, esc=close
                        # shows BOTH scopes — toggle under (user) or (project)
```
Writes `+path`/`-path` patterns to the scope's settings; restart pi to apply.

**2. Per-project opt-in** — when only some projects need a resource:
```bash
cd ~/code/some-project
pi install git:github.com/devskale/skale-skills -l   # -l → .pi/settings.json (project)
pi config                                              # toggle what THIS project needs
```
The project entry **replaces** the global one for that project, so re-list anything you still want there.

### Howto: install a specific extension (e.g. statusline, xmodel)

Extensions are `[]` (off) by default. To turn specific ones on **everywhere**, use **plain includes** (whitelist form):
```jsonc
// ~/.pi/agent/settings.json — change the package entry
{ "packages": [{
  "source": "git:github.com/devskale/skale-skills",
  "skills": ["fetch-url", "web-search"],
  "extensions": ["extensions/statusline.ts", "extensions/xmodel.ts"]  // only these load
}]}
```
Or per-project via `pi config` after the `-l` install above.

> ⚠️ **`+path` gotcha:** force-includes (`"+extensions/x.ts"`) re-enable within an otherwise-on set — used **alone** they turn the whole type on (plain-name whitelist is what limits loading). For "only these", use plain paths/names as above. The `pi config` TUI manages this for you; hand-editing is where it bites.

> **Conflict rule:** tool-registering extensions (e.g. `imagegen.ts`) **cannot** co-load as both a package copy and a loose symlink — fatal error. Event-only extensions (`statusline`) tolerate it. Keep it simple: use the package, delete loose copies. Full detail: [docs/installation.md](docs/installation.md).

### Update

```bash
pi update git:github.com/devskale/skale-skills   # one package
pi update --all                                    # pi + all packages
```

## Credentials — credgoo (First-Class Citizen)

**All credentials go through credgoo.** No `.env` files with real tokens. No hardcoded secrets.

→ **Full guide: [docs/credgoo.md](docs/credgoo.md)** — setup, CLI reference, Python patterns, adding credentials to new skills
→ **Source:** [github.com/devskale/python-openutils](https://github.com/devskale/python-openutils) (`packages/credgoo/`)

Quick reference:

```bash
# First-time setup
credgoo --setup

# Get a key
credgoo WEB_SEARCH_BEARER

# Add to a new skill
credgoo MY_NEW_SERVICE_KEY
```

```python
# Standard pattern in Python
from credgoo import get_api_key
import contextlib, io

with contextlib.redirect_stdout(io.StringIO()):
    token = get_api_key("MY_SERVICE_KEY")
```

Resolution order: `env var` → `credgoo` → `.env` (last resort, gitignored)

Current services: `WEB_SEARCH_BEARER`, `FETCH_URL_BEARER`, `searx`

Rules: never commit real tokens, always gitignore `.env`, always suppress credgoo stdout in Python.

## Docs

| Doc | What |
|-----|------|
| [docs/installation.md](docs/installation.md) | pi install, precedence, and conflict gotchas (canonical = git package) |
| [docs/development.md](docs/development.md) | Dev loop for skills & extensions — edit, ship upstream, then remove dev overrides |
| [docs/credgoo.md](docs/credgoo.md) | Credential management — setup, CLI, Python patterns, adding to new skills |

### Best Practices Guides (from skaleshare)

Deep-dive authoring guides distilled from specs, research, and real-world skills/extensions.

| Doc | What |
|-----|------|
| [docs/agent-skills-best-practices.md](docs/agent-skills-best-practices.md) | SKILL.md frontmatter, progressive disclosure (3-level), skill taxonomy, script bundling, security, failure modes |
| [docs/agents-md-best-practices.md](docs/agents-md-best-practices.md) | AGENTS.md inclusion test, section structure, anti-patterns, size limits, nested files, cross-tool compat |
| [docs/pi-extensions-best-practices.md](docs/pi-extensions-best-practices.md) | Pi extension patterns — tool registration, schema design, state/event lifecycle, mode awareness, gates, distribution |

### Browser Automation — [docs/browser-use/](docs/browser-use/) → [README](docs/browser-use/README.md)

| Doc | What |
|-----|------|
| [browser-tools-comparison.md](docs/browser-use/browser-tools-comparison.md) | Agent browser tools compared (10+ tools, feature matrix, Chrome 136+ breaking changes) |
| [browser-session-reuse.md](docs/browser-use/browser-session-reuse.md) | Strategies for reusing real Chrome sessions |
| [openchrome-usage.md](docs/browser-use/openchrome-usage.md) | OpenChrome skill usage guide |
| [chrome-dev.md](docs/browser-use/chrome-dev.md) | Chrome DevTools MCP setup |
| [vcl-agent-browser.md](docs/browser-use/vcl-agent-browser.md) | Vercel agent-browser setup |

### Other Guides

| Guide | What |
|-------|------|
| [guides/rodney-setup.md](guides/rodney-setup.md) | Rodney headless Chrome setup |

## Browser Automation — Chrome 136+ Breaking Changes

> ⚠️ **Current Chrome stable: v149** (June 2026). The Chrome 136+ restrictions are still in effect. **Do not assume `chrome --remote-debugging-port=9222` works** — it doesn't, on the default profile.

### What is broken (since Chrome 136, March 2025)

1. **`--remote-debugging-port=9222` is IGNORED on the default profile.**
   - Chrome opens, but the debug port never listens. No error, no warning — just silent failure.
   - Affects all `puppeteer.connect()`, `chromium.connectOverCDP()`, Puppeteer/Playwright MCP, agent-browser, etc.
   - **Reason:** Google blocked it for security (info-stealers were stealing cookies via CDP).
   - Source: [developer.chrome.com/blog/remote-debugging-port](https://developer.chrome.com/blog/remote-debugging-port)

2. **`--user-data-dir=/some/path` is REQUIRED, but gives you a SEPARATE profile.**
   - The flag works only when pointing to a non-default directory.
   - That directory starts blank — none of your cookies, logins, or extensions.
   - You can copy your real profile there, but see #3.

3. **App-Bound Encryption (Chrome 136+) prevents decrypting copied profile data.**
   - Cookies and passwords in the default profile are encrypted with a key tied to the OS user account + profile path.
   - Chromium issue #394919677: *"app-bound will be changed to not decrypt data if a custom `--user-data-dir` is used."*
   - **Result:** Copying `~/.../Google/Chrome/Default` to `/tmp/some-dir` does NOT give you working cookies.
   - Source: [issues.chromium.org/issues/394919677](https://issues.chromium.org/issues/394919677)

### What still works (in priority order)

| Use case | Tool | How |
|----------|------|-----|
| **Reuse your real Chrome session (best)** | **Chrome DevTools MCP** | `--autoConnect` on Chrome 146+ stable. Toggle once in `chrome://inspect/#remote-debugging`. |
| Reuse your Chrome cookies via Python (macOS/Linux) | **agentauth-py** | `pip install agentauth-py && agent-auth grab <domain>` — reverse-engineers App-Bound Encryption. |
| Reuse real Chrome via MCP, no debug port | **Hangwin mcp-chrome** | Chrome extension + local bridge. |
| Reuse real Chrome via MCP, with human-in-loop | **Playwright MCP Bridge Extension** | Microsoft's official extension, sideloaded. |
| Just need a fresh isolated browser | **rodney** (our tool) | `rodney start && rodney open <url> && rodney stop`. Already in this repo. |
| Need a stealth anti-detect browser | **CloakBrowser** (our testbed) | Stealth Chromium, own browser. |
| Need an MCP for any browser | **Playwright MCP** | Cross-browser, no real-session reuse by default. |

### Rules for any browser automation in this repo

- **Never** write a doc, script, or guide that suggests `chrome --remote-debugging-port=9222` against the default profile — it doesn't work.
- If you find a tutorial older than March 2025, **verify** before citing it.
- For our own tools (rodney, CloakBrowser tests): they launch their own browser — Chrome 136+ doesn't affect them.
- Full comparison + decision flows: [docs/browser-use/browser-tools-comparison.md](docs/browser-use/browser-tools-comparison.md)

## External Skills

Install from upstream, don't maintain locally:

```bash
# Install
skiller install <name>           # install a local skill across agents
npx @anthropic-ai/skills add <name>  # Anthropic skills
openskills install <org>/<repo>  # openskills CLI

# Browse and discover
# https://skills.sh  ·  `skiller discovery <dir>` (scan a local dir)
openskills install <org>/<repo>  # openskills CLI

# Also check: https://skills.sh
```

See `RECOMMENDED-SKILLS.md` for full list of sources and install commands.

## Running Tests

No global runner. Per-skill test suites:

```bash
bash tests/fetch-url/test.sh
bash tests/web-search/test.sh
bash tests/youtube/test.sh
bash tests/video-transcript-downloader/test.sh
bash tests/rodney/test.sh
```

Always run the relevant test after modifying a skill.

## Development Workflow

### Best Practices (from CONVENTION.md)

Every skill must have:
- `SKILL.md` — frontmatter (`name`, `description`, `version`) + short usage instructions
- Launcher script — symlink resolution, `--update`/`--selfcheck`, auto-update after 7 days
- `install.sh` — creates `~/.local/bin/<command>` launcher (Linux/macOS)
- `install.bat` — creates `%USERPROFILE%\.local\bin\<command>.bat` launcher (Windows)
- `.gitignore` — `.venv/`, `.env`, `uv.lock`, `*.egg-info/`, `.last-update`
- `tests/<name>/test.sh` — file structure, launcher flags, live smoke test, code quality

Never use: `readlink -f` (breaks macOS), `.env` with real tokens, `requirements.txt`.

### Python

- Type hints mandatory
- Google-style docstrings
- Credentials via [credgoo](#credentials--credgoo-first-class-citizen)

### SKILL.md

- Under 100 lines
- Short commands (`fetch-url "url"`, not `cd ~/.pi/... && uv run scripts/...`)
- Link all `references/` files

## API Docs

Reverse-engineered public APIs at `api/`:

- `api/ryanair/ryanair.md` — Ryanair fare search (free, no auth)

## Skiller CLI

```bash
cd skiller && uv venv && source .venv/bin/activate && uv pip install -e .
skiller --help
```

Key commands: `discovery`, `install`, `remove`, `list`.

See `skiller/` and `CONVENTION.md` for full details.
