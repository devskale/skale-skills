# Skale Skills - Agent Instructions

This repo contains **our own skills** (actively developed).
External skills (docx, xlsx, etc.) should be installed from upstream — see `RECOMMENDED-SKILLS.md`.

## Our Skills

| Skill | Command | Tests | What |
|-------|---------|-------|------|
| fetch-url | `fetch-url "url"` | ~89 | Web content extraction with smart fallback |
| web-search | `web-search "query"` | ~38 | Web search via SearXNG + Duck API |
| youtube | `youtube "query"` | ~38 | YouTube search via Invidious API with auto-fallback |
| vtd | `vtd transcript --url '...'` | ~49 | Video/audio/transcript downloader (yt-dlp) |
| rodney | `rodney start/open/stop` | ~54 | Headless Chrome automation. **Binary: Go fork at `~/code/clones/rodney` (branch `skale`) — build/test/release only on request (see its AGENTS.md)** |
| surf | `surf open/click/read` (macOS) | ~36 | Drive your real, logged-in Chrome via AppleScript |
| visualize | `visualize open/share/validate` | ~124 | Render any set of things as ONE self-contained HTML + share URL |
| d2 | `d2 validate/render` | ~46 | Diagrams as code (D2 language) — knowledge skill + helper scripts |
| figure | `node build/build_figures.mjs` | ~20 | Hand-drawn-style architecture figures (SVG/PNG compositor) |
| peep | `peep <command>` | ~55 | Read X/Twitter via the `peep` CLI (knowledge skill) |
| issues | `issues board/new/todo/…` | 52 | Cross-machine shared issue kanban (`.handoff/<project>/issues/`) — one markdown file per issue, synced dir per project |
| ~~viewimg~~ | ~~`viewimg img.jpg [--open]`~~ | ~~~16~~ | **DEPRECATED** — use `read img.jpg` instead. Archived to `skills/deprecated/viewimg/`. [Migration guide](docs/image-display-deprecation.md) |
| pdf2md | `pdf2md document.pdf` | ~30 | Convert PDFs to Markdown — pdfplumber (local), llamaparse fallback for scans (skale pdf API) |
| improve-ux | `improve-ux discover/add/rate/ledger` | ~96 | Improve UI/UX grounded in curated reference sites — progressive topic routing, verify loop, findings ledger (`ledger` cmd), ratings loop (`rate` cmd), site discovery |

Counts are approximate (`~`); suites include honest network-skip counters — a WARN
does not count as a pass. `tests/` also has `imagegen` (tests `extensions/imagegen.ts`),
`xmodel` (routing-matrix mock test for `extensions/xmodel.ts` — read handover, understand
param, view mode; no network needed), and `gdocs` (live smoke of the external `gog` CLI).

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

Default activation: **`web-search` + `fetch-url` + `pdf2md`** skills (extensions: heartbeat, xmodel,
statusline, imagegen). pdf2md ships `disable-model-invocation: true` — executable as a pi skill,
never auto-loaded into context.
`./install.sh` seeds this default right after `pi install` (`scripts/skill-filter.sh seed-defaults`) —
pi checks ALL shipped skills by default otherwise. The seed is a whitelist
(plain patterns = include set in pi's filter model), so every other skill stays
opt-in via `pi config`. Idempotent + respects customization: an existing skills
filter is left untouched.

> **View vs. understand images:** `read img.jpg` is **display-only** (canonical, native pi image display) — it shows an
> image inline / in the terminal but **never fires the VLM**. Understanding is **opt-in**: the `read_image`
> tool or `/readimg` command runs the vision model. `xmodel` is still active and powers this separation.
> `viewimg` (deprecated) was the legacy CLI; use `read img.jpg` instead. [Migration guide](docs/image-display-deprecation.md).

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
| [docs/installation.md](docs/installation.md) | Install the pi package, activate only what you use, the **skill states** (aktiv/passiv/deaktiviert/löschen), and the loose-symlink conflict gotcha |
| [docs/development.md](docs/development.md) | Dev loop for skills & extensions — edit, ship upstream, then remove dev overrides |
| [docs/credgoo.md](docs/credgoo.md) | Credential management — setup, CLI, Python patterns, adding to new skills |
| [pi-architecture.md](pi-architecture.md) | How pi (the agent runtime) discovers packages, skills, extensions — background for this repo's layout |
| [docs/codex-learnings.md](docs/codex-learnings.md) | Grounding for the coding guidelines — what the Codex repo teaches about testing, boundaries & lint at scale |
| [docs/agent-agnostic.md](docs/agent-agnostic.md) | **Living review + roadmap**: repo verdict, ecosystem comparison, agent-agnostic plan with status |
| [docs/deprecation.md](docs/deprecation.md) | Deprecating a skill — the step-by-step and the load-bearing exclusion traps |
| [docs/ideas.md](docs/ideas.md) | **Ideas** — well-developed issues: decided directions, deliberately not implemented (the hub for all sketches) |
| [LAYOUT.md](LAYOUT.md) | The three "not shipped" states — idea / under review / deprecated, and how each is excluded from the package |
| [release-notes.md](release-notes.md) | Changelog of notable changes, newest first (`## Unreleased` at the top) |
| [docs/pi-web-access.md](docs/pi-web-access.md) | The third-party `pi-web-access` package (librarian skill) — what it provides and how it relates to our own web skills |
| [extensions/statusline.md](extensions/statusline.md) | statusline extension — what the footer shows and how to configure it |
| [extensions/heartbeat.md](extensions/heartbeat.md) | heartbeat extension — recurring reminder timer (`/heartbeat`), pause/resume/stop |
| [extensions/imagegen.md](extensions/imagegen.md) | imagegen extension — text-to-image generation, providers, and output handling |
| [extensions/image-slim.md](extensions/image-slim.md) | image-slim extension — strips image payloads from compaction summaries (blockImages doesn't cover compaction) |

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
npx skills@latest add <org>/<repo> -l # list/browse a repo's skills (--full-depth for nested ones)
# browse/discover: https://skills.sh
```

Notable upstreams worth a look: **[emilkowalski/skills](https://github.com/emilkowalski/skills)**
(~42k ★, animation/UI/mobile craft), **[humanlayer/skills](https://github.com/humanlayer/skills)**
(interview-driven agentic workflows), **[cursor/plugins](https://github.com/cursor/plugins)**
(Cursor's plugin marketplace — skills + agents + `mcp.json` per plugin).

See `RECOMMENDED-SKILLS.md` for the full list of sources and install commands.

## Running Tests

**The gate:** `bash scripts/check.sh` runs on every commit (wired via `core.hooksPath .githooks` —
run `git config core.hooksPath .githooks` once after cloning). Pre-push is a **depth ladder** —
fast by default, deeper checks on request: `git push` runs lint + typecheck only (~2s);
`CHECK=1 git push` adds the fast gate (skill-metadata + docs integrity); `RELEASE=1 git push`
runs the full regression (all suites; live-browser suites rodney/surf skip honestly unless
`LIVE_OK=1` — they drive the user's real desktop Chrome). Escape hatch for WIP pushes:
`PUSH_SKIP_TESTS=1 git push` skips all checks.

Per-skill suites (`~` counts above):

```bash
bash scripts/check.sh              # the gate: lint + typecheck + docs integrity
bash scripts/check.sh --full       # the gate + every suite below
bash scripts/extension-drift.sh    # is the running agent's package clone in sync?
bash tests/statusline/test.sh
bash tests/fetch-url/test.sh
bash tests/web-search/test.sh
bash tests/youtube/test.sh
bash tests/video-transcript-downloader/test.sh
bash tests/rodney/test.sh
bash tests/surf/test.sh              # live checks skip off-macOS
bash tests/deprecated/viewimg/test.sh  # DEPRECATED — archived, tests for backward-compat only
bash tests/pdf2md/test.sh             # live conversion skips without token
bash tests/improve-ux/test.sh         # structure, router, add; live discover WARNs offline
bash tests/visualize/test.sh
bash tests/d2/test.sh
bash tests/figure/test.sh
bash tests/peep/test.sh
bash tests/issues/test.sh         # issues kanban CLI (sandboxed ISSUES_DIR)
bash tests/imagegen/test.sh          # extensions/imagegen.ts
bash tests/heartbeat/test.sh         # extensions/heartbeat.ts
bash tests/skill-filter/test.sh      # scripts/skill-filter.sh (settings filter helper)
bash tests/skill-metadata/test.sh    # SKILL.md description hygiene (≤ 600 chars; What + Use-when)
bash tests/link-agents/test.sh      # scripts/link-agents.sh (~/.agents/skills for other agents)
bash tests/docs/test.sh             # docs integrity: dead links in hubs + orphaned docs files
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

**Edit-here ≠ runs-there:** pi loads extensions from the **package clone**
(`~/.pi/agent/git/.../skale-skills/`), never from this checkout — after editing
`extensions/`, the running agent is on old code until you push + `pi install` (or set a
temporary dev override, which you must remove before shipping). Check drift with
`scripts/extension-drift.sh`; the loop is documented in
[docs/development.md](docs/development.md).

### Best Practices (from CODING_RULES.md)

Full reference incl. launcher/install.sh templates, testing matrix, version alignment:
[CODING_RULES.md → Skill Best Practices](CODING_RULES.md#skill-best-practices).

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

Coding guidelines live in [CODING_RULES.md](CODING_RULES.md) — read it when writing or reviewing skill code. Grounded in [Learnings from the Codex repo](docs/codex-learnings.md): as implementation gets cheaper, tests, boundaries, and lint matter more, not less.

Always-on hard rules:

- Never modify code that tests observe — launcher flags (`--update`, `--selfcheck`), `.last-update`, env-var fallback order — to make a failing test pass. The test is the finding: report it.
- A change to skill behavior (flag parsing, backend fallback, output format) MUST add an integration test: a real invocation of the command.
- A correction that repeats in review goes into the Coding Guidelines; once stable and objectively checkable, automate it in `test.sh` and prune the prose.

## Learning ambition (capture → docs → tests)

This repo is a **living workshop**, not a finished product. Every session that surfaces a reusable lesson — a convention, a gotcha, a better pattern — should leave a trace. The pipeline, in order:

1. **Capture** — when a lesson appears (a bug we hit, a convention we invented, a trap we stepped in), record it where it belongs: `AGENTS.md` for load-bearing rules the agent must follow, `docs/` for deep-dive guides, `CODING_RULES.md` for coding guidelines.
2. **Bake into docs** — turn the one-off fix into a documented convention so the next agent doesn't rediscover it. Prefer a short load-bearing rule over a long explanation.
3. **Automate** — once a rule is stable and objectively checkable, encode it in a `test.sh` (or `scripts/lint.sh` for extensions) and prune the prose. The test is the enforcement; the doc becomes the pointer.
4. **Prune** — when a skill or pattern is superseded, archive it (see Deprecation below) rather than leaving it to rot in place.

**Guiding principle:** every real-world hit is an asset. If it cost us time or taught us something, it should outlive the session as a rule, a doc, or a test — not vanish with the conversation.

## Deprecation & Archiving

When a skill is superseded, **archive** it — move it to `skills/deprecated/`, keep history,
take it out of the active package. The full step-by-step and the load-bearing exclusion
traps (`!` vs `-`, the `./`-prefix no-op, path-depth on moved tests) live in
**[docs/deprecation.md](docs/deprecation.md)** — follow it, don't improvise. Folder
semantics (idea / under review / deprecated, and why the two `deprecated/` folders exist):
**[LAYOUT.md](LAYOUT.md)**. Helper: `scripts/skill-filter.sh`.

## Managing skills across agents

Install skills into pi or other agents with the ecosystem's standard tools:

```bash
openskills install <org>/<repo>       # multi-agent skill installer
npx @anthropic-ai/skills add <name>   # Anthropic skills
# browse/discover: https://skills.sh
```

**Our built-in way — the standard dir:** `./install.sh` asks **interactively which
agents** get the skills (standard `~/.agents/skills`, `~/.zcode/skills`,
`~/.claude/skills`, `~/.codex/skills`) and records the choice in
`~/.config/skale-skills/link-agents.conf`. Non-interactive: `./install.sh --agents`
(standard dir), `--no-agents`, or `SKALE_LINK_AGENTS=1|0`. Linking is done by
[`scripts/link-agents.sh`](scripts/link-agents.sh) — every non-deprecated skill
symlinked into the chosen dirs. pi, zcode (discovery #3), and spec-compliant
agents read `~/.agents/skills` natively. Opt-in per machine — pi's package filter
(seed-defaults whitelist) does NOT apply to skills found there, so linking
activates them for pi too. Deprecated skills are never linked (no other agent
has manifest exclusion).

The former `skiller` CLI is retired — see [`deprecated/`](deprecated/README.md).
