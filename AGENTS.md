# Skale Skills - Agent Instructions

This repo contains **our own skills** (actively developed).
External skills (docx, xlsx, etc.) should be installed from upstream — see `RECOMMENDED-SKILLS.md`.

## Our Skills

| Skill | Command | Tests | What |
|-------|---------|-------|------|
| fetch-url | `fetch-url "url"` | ~49 | Web content extraction with smart fallback |
| web-search | `web-search "query"` | ~38 | Web search via SearXNG + Duck API |
| youtube | `youtube "query"` | ~38 | YouTube search via Invidious API with auto-fallback |
| vtd | `vtd transcript --url '...'` | ~49 | Video/audio/transcript downloader (yt-dlp) |
| rodney | `rodney start/open/stop` | ~37 | Headless Chrome automation |
| surf | `surf open/click/read` (macOS) | ~36 | Drive your real, logged-in Chrome via AppleScript |
| visualize | `visualize open/share/validate` | ~36 | Render any set of things as ONE self-contained HTML + share URL |
| d2 | `d2 validate/render` | ~41 | Diagrams as code (D2 language) — knowledge skill + helper scripts |
| figure | `node build/build_figures.mjs` | ~7 | Hand-drawn-style architecture figures (SVG/PNG compositor) |
| peep | `peep <command>` | ~55 | Read X/Twitter via the `peep` CLI (knowledge skill) |
| viewimg | `viewimg img.jpg [--open]` | ~16 | Show an image in the terminal (view-only, no VLM) |
| pdf2md | `pdf2md document.pdf` | ~30 | Convert PDFs to Markdown — pdfplumber (local), llamaparse fallback for scans (skale pdf API) |
| improve-ux | `improve-ux discover/add` | ~50 | Improve UI/UX grounded in curated reference sites — progressive topic routing, verify loop, findings ledger, site discovery |

Counts are approximate (`~`); suites include honest network-skip counters — a WARN
does not count as a pass. `tests/` also has `imagegen` (tests `extensions/imagegen.ts`)
and `gdocs` (live smoke of the external `gog` CLI).

## Installation (as a pi package)

This repo is a **pi package** — `package.json` declares a `pi` manifest (`./skills`, `./extensions/*.ts`, `./prompts`). One command sets everything up (all global skill commands in `~/.local/bin`, zcode symlinks, pi package sync — idempotent):

```bash
./install.sh                                        # full setup (or install.bat on Windows)
pi config                                           # activate only the pi skills you use
```

Under the hood it runs every `skills/*/install.sh`; the pi package itself installs/updates via:

```bash
pi install git:github.com/devskale/skale-skills   # install once, globally
pi config                                          # activate only the skills you use
```

Note: pi reads skills from its **package copy** at `~/.pi/agent/git/github.com/devskale/skale-skills/` (a full clone made by `pi install`) — not from a working checkout. Skill launchers auto-update that clone in the background every 7 days; `pi install` updates it on demand.

Default activation: **`web-search` + `fetch-url`** skills (extensions: heartbeat, xmodel, statusline, imagegen).

> **View vs. understand images:** `read` and the `viewimg` skill are **display-only** — they show an
> image inline / in the terminal but **never fire the VLM**. Understanding is **opt-in**: the `read_image`
> tool or `/readimg` command runs the vision model. `xmodel` is still active and powers this separation.

Full install, activate, filter, project-scope, update, and conflict docs: **[docs/installation.md](docs/installation.md)**.

## Credentials — credgoo (First-Class Citizen)

**All credentials go through credgoo.** No `.env` files with real tokens. No hardcoded secrets.

→ **Full guide: [docs/credgoo.md](docs/credgoo.md)** — setup, CLI reference, Python patterns, adding credentials to new skills
→ **Source:** [github.com/devskale/python-openutils](https://github.com/devskale/python-openutils) (`packages/credgoo/`)

```bash
credgoo --setup                 # first-time setup
credgoo WEB_SEARCH_BEARER       # get a key
credgoo MY_NEW_SERVICE_KEY      # add to a new skill
```

```python
from credgoo import get_api_key

token = get_api_key("MY_SERVICE_KEY")
```

Resolution order: `env var` → `credgoo` → `.env` (last resort, gitignored)

Current services: `WEB_SEARCH_BEARER`, `FETCH_URL_BEARER`, `searx`

Rules: never commit real tokens, always gitignore `.env`. `get_api_key` never
prints to stdout (all output lives in the `credgoo` CLI), so no stdout
suppression is needed. A missing key is logged at DEBUG — silent by default;
configure a DEBUG handler on the `credgoo` logger to see it.

## Docs

| Doc | What |
|-----|------|
| [docs/installation.md](docs/installation.md) | Install the pi package, activate only what you use, and the loose-symlink conflict gotcha |
| [docs/development.md](docs/development.md) | Dev loop for skills & extensions — edit, ship upstream, then remove dev overrides |
| [docs/credgoo.md](docs/credgoo.md) | Credential management — setup, CLI, Python patterns, adding to new skills |
| [pi-architecture.md](pi-architecture.md) | How pi (the agent runtime) discovers packages, skills, extensions — background for this repo's layout |
| [docs/codex-learnings.md](docs/codex-learnings.md) | Grounding for the coding guidelines — what the Codex repo teaches about testing, boundaries & lint at scale |

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
| [surf.md](docs/browser-use/surf.md) | Surf — drive your real Chrome via macOS AppleScript (vs rodney / chrome-devtools-mcp) |
| [vcl-agent-browser.md](docs/browser-use/vcl-agent-browser.md) | Vercel agent-browser setup |
| [which-browser-tool.md](docs/browser-use/which-browser-tool.md) | Decision flow: which browser tool for which job |

### Other Guides

| Guide | What |
|-------|------|
| [guides/rodney-setup.md](guides/rodney-setup.md) | Rodney headless Chrome setup |
| [guides/impeccable-setup.md](guides/impeccable-setup.md) | Impeccable setup notes |

## Browser Automation — Chrome 136+ breaking change (load-bearing rule)

**Never** write a doc, script, or guide that suggests `chrome --remote-debugging-port=9222` against the
default profile — since Chrome 136 (March 2025) the flag is silently ignored there, `--user-data-dir`
gives you a blank separate profile, and App-Bound Encryption stops copied profiles from decrypting.
If you find a tutorial older than March 2025, verify before citing it. What still works, decision flows,
and tool comparisons: [docs/browser-use/browser-tools-comparison.md](docs/browser-use/browser-tools-comparison.md).
Our own tools (rodney, surf, CloakBrowser tests) are unaffected — they launch or drive their own browser.

## External Skills

Install from upstream, don't maintain locally:

```bash
openskills install <org>/<repo>       # multi-agent skill installer
npx @anthropic-ai/skills add <name>   # Anthropic skills
# browse/discover: https://skills.sh
```

See `RECOMMENDED-SKILLS.md` for full list of sources and install commands.

## Running Tests

No global runner, no CI. Per-skill suites (`~` counts above):

```bash
bash tests/fetch-url/test.sh
bash tests/web-search/test.sh
bash tests/youtube/test.sh
bash tests/video-transcript-downloader/test.sh
bash tests/rodney/test.sh
bash tests/surf/test.sh              # live checks skip off-macOS
bash tests/viewimg/test.sh
bash tests/pdf2md/test.sh             # live conversion skips without token
bash tests/improve-ux/test.sh         # structure, router, add; live discover WARNs offline
bash tests/visualize/test.sh
bash tests/d2/test.sh
bash tests/figure/test.sh
bash tests/peep/test.sh
bash tests/imagegen/test.sh          # extensions/imagegen.ts
bash tests/heartbeat/test.sh         # extensions/heartbeat.ts
bash tests/gdocs/test.sh             # live smoke, external gog CLI
```

Always run the relevant test after modifying a skill. Suites use PASS/FAIL/WARN
counters — WARN means "network-dependent, skipped honestly", never a hidden pass.

**Extensions** — run the quick lint/typecheck gate after touching `extensions/*.ts`:

```bash
bash scripts/lint.sh     # tsc --noEmit + Biome lint (scoped to extensions/)
```

**Test cadence:** run **focused** tests during development (exercise only the command/section you changed — a standalone snippet or a single feature), and run the **full regression suite** before release (i.e. right before a version bump + ship). Don't loop the whole suite on every edit.

## Development Workflow

### Best Practices (from CONVENTION.md)

Full reference incl. launcher/install.sh templates, testing matrix, version alignment:
[CONVENTION.md → Skill Best Practices](CONVENTION.md#skill-best-practices).

Every skill must have:
- `SKILL.md` — frontmatter (`name`, `description`, `version`) + short usage instructions
- Launcher script — symlink resolution, `--update`/`--selfcheck`, auto-update after 7 days
- `install.sh` — creates `~/.local/bin/<command>` launcher (Linux/macOS)
- `install.bat` — creates `%USERPROFILE%\.local\bin\<command>.bat` launcher (Windows)
- `.gitignore` — `.venv/`, `.env`, `uv.lock`, `*.egg-info/`, `.last-update`
- `tests/<name>/test.sh` — file structure, launcher flags, live smoke test, code quality

Never use: `readlink -f` (breaks macOS), `.env` with real tokens, `requirements.txt`.

**Pi package updates run `git clean -fdx`** inside the package, which deletes any
`.venv/`/`node_modules/`/`package-lock.json` in the repo path. Keep the Python
venv OUTSIDE the repo via `UV_PROJECT_ENVIRONMENT` (set in launcher + install.sh,
e.g. `$HOME/.cache/skale-skills/<skill>`), and run with `uv run --project` to
preserve the caller's cwd. Full guidance: [agent-skills-best-practices.md →
Python dependencies & pi package updates](docs/agent-skills-best-practices.md).

### Python

- Type hints mandatory
- Google-style docstrings
- Credentials via [credgoo](#credentials--credgoo-first-class-citizen)

### SKILL.md

- Under 100 lines
- Short commands (`fetch-url "url"`, not `cd ~/.pi/... && uv run scripts/...`)
- Link all `references/` files

## Coding

Coding guidelines live in [CONVENTION.md → Coding Guidelines](CONVENTION.md) — read it when writing or reviewing skill code. Grounded in [Learnings from the Codex repo](docs/codex-learnings.md): as implementation gets cheaper, tests, boundaries, and lint matter more, not less.

Always-on hard rules:

- Never modify code that tests observe — launcher flags (`--update`, `--selfcheck`), `.last-update`, env-var fallback order — to make a failing test pass. The test is the finding: report it.
- A change to skill behavior (flag parsing, backend fallback, output format) MUST add an integration test: a real invocation of the command.
- A correction that repeats in review goes into the Coding Guidelines; once stable and objectively checkable, automate it in `test.sh` and prune the prose.

## Managing skills across agents

Install skills into pi or other agents with the ecosystem's standard tools:

```bash
openskills install <org>/<repo>       # multi-agent skill installer
npx @anthropic-ai/skills add <name>   # Anthropic skills
# browse/discover: https://skills.sh
```

The former `skiller` CLI is retired — see [`deprecated/`](deprecated/README.md).
