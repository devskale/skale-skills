# Skale Skills

> A [pi](https://pi.dev) package of **skills, extensions, and prompts** for AI coding agents — works with pi, Claude Code, Codex, OpenCode, and anything that speaks skills/MCP.

One install gives your agent web fetch/search, YouTube, video/transcripts, diagramming, **headless *and* real-session browser control**, image generation, custom model providers, and a battery of workflow skills — all credential-safe via [credgoo](docs/credgoo.md).

---

## Architecture

![skale-skills architecture](docs/architecture.svg)

**pi** loads this package (skills + extensions + prompts); the **skiller** CLI manages skills across agents; skills reach **credgoo** for credentials and the **Web** for fetch / search / browser control. Source: [`docs/architecture.d2`](docs/architecture.d2) — edit and re-render with `d2 docs/architecture.d2 docs/architecture.svg`.

---

## ⭐ Featured: `surf` — drive your *real* Chrome

```bash
surf tabs                       # list every window/tab (w1.t3 refs)
surf select w2.t5               # pin a tab — drive it in the background, no focus steal
surf text "h1"                  # read text   ·   surf fill "input[name=q]" "skyvern"
surf click "button#submit"      # click       ·   surf scroll down 3
surf wait ".result" --timeout 20   # wait for async content
surf shot-el "h1" shot.png      # element screenshot
```

`surf` controls the browser you're **already logged into** (cookies/tabs intact) via macOS AppleScript — **no daemon, no debug port, no extension, no per-connection "Allow remote debugging?" dialog**. 30+ commands, CI-friendly assertions, `--json` output, zero deps. See [docs/browser-use/surf.md](docs/browser-use/surf.md) and the [surfw vs rodney vs chrome-devtools-mcp](docs/browser-use/surf.md#comparison-surf-vs-rodney-vs-chrome-devtools-mcp) matrix.

## What's included

### Skills

| Skill | What it does |
|---|---|
| **[surf](skills/surf)** ⭐ | Drive your real, logged-in Chrome via AppleScript — no ack, no deps |
| **[rodney](skills/rodney)** | Headless Chrome automation (scrape, screenshot, PDF, a11y, CI assertions) |
| **browser-use** | Persistent browser automation with session continuity |
| **[fetch-url](skills/fetch-url)** | Web content extraction with smart fallback (Reddit, SO, GitHub, docs) |
| **[web-search](skills/web-search)** | Web search via SearXNG + Duck API (images, news, videos) |
| **[youtube](skills/youtube)** | YouTube search via Invidious with auto-fallback |
| **video-transcript-downloader** | Download video/audio/subtitles/transcripts (yt-dlp) |
| **d2** | Diagrams-as-code with the D2 language |
| **todo** | TODO.md task tracking for multi-step work |
| **agent-skill-creator** | Guide for creating skills for any AI agent |
| **agents-md-init** | Create and update AGENTS.md files |
| **command-creator** | Custom commands for pi and OpenCode |
| **improve-skill** | Improve skills from session transcripts |
| **readme-write** | Generate and update README.md files |

### Extensions (pi)

| Extension | What it does |
|---|---|
| **heartbeat** | Recurring reminder/heartbeat timer the agent can start/stop |
| **statusline** | Custom footer — machine name, token stats, context usage |
| **xmodel** | Custom model providers (zai/GLM, opencode, zen.fg, local endpoints) |
| **imagegen** | Text→image (Pollinations/TU via uniinfer) with ASCII preview for iteration |

### Prompts

| Prompt | What it does |
|---|---|
| **learn** | Learning and study workflow |

## Install

### pi (native)

```bash
# Install everything
pi install git:github.com/devskale/skale-skills

# …or try without installing
pi -e git:github.com/devskale/skale-skills
```

Selective install — edit `~/.pi/agent/settings.json`:

```jsonc
{
  "packages": [{
    "source": "git:github.com/devskale/skale-skills",
    "skills": ["surf", "fetch-url", "web-search"],
    "extensions": ["extensions/heartbeat.ts", "extensions/statusline.ts", "extensions/xmodel.ts"]
  }]
}
```

Filter semantics: omit a key = load **all** of that type · `[]` = load **none** · plain names = **whitelist** · `"!skills/todo"` = exclude. See [docs/installation.md](docs/installation.md) (precedence + the loose-symlink conflict gotcha) and the [install runbook](docs/install-runbook.md).

### Other agents

```bash
npx skills@latest add devskale/skale-skills        # Claude Code, Codex, …
openskills install devskale/skale-skills           # OpenSkills

# or symlink any single skill (works everywhere)
ln -s "$PWD/skills/surf" ~/.pi/agent/skills/surf
ln -s "$PWD/skills/surf" ~/.claude/skills/surf
```

## Quick start

```bash
# Browse & automate your real Chrome (one-time: View → Developer → Allow JavaScript from Apple Events)
surf setup && surf tabs

# Fetch a page
fetch-url "https://news.ycombinator.com"

# Search the web
web-search "agentic browser 2026" --max 10

# Pull a YouTube transcript
vtd transcript --url 'https://youtube.com/watch?v=…'
```

## Credentials — credgoo

All keys flow through [credgoo](docs/credgoo.md) (no `.env` with real tokens, no hardcoded secrets):

```bash
credgoo --setup                 # first-time setup
credgoo WEB_SEARCH_BEARER       # fetch a key
```

Resolution: env var → credgoo → `.env` (gitignored, last resort). Current services: `WEB_SEARCH_BEARER`, `FETCH_URL_BEARER`, `searx`.

## `skiller` CLI

Discover, install, and remove skills across agents:

```bash
cd skiller && uv venv && source .venv/bin/activate && uv pip install -e .
skiller discovery <dir>     # scan a local dir for skills
skiller install <name>      # install across agents
```

See [`CONVENTION.md`](CONVENTION.md) and [`RECOMMENDED-SKILLS.md`](RECOMMENDED-SKILLS.md) (external skill sources).

## Docs

| Topic | Doc |
|---|---|
| Browser automation (surf, rodney, chrome-devtools-mcp comparison) | [docs/browser-use/](docs/browser-use/) |
| Skill flow diagrams (web-search, fetch-url, surf) | [docs/skill-diagrams.md](docs/skill-diagrams.md) |
| Install & precedence | [docs/installation.md](docs/installation.md) · [runbook](docs/install-runbook.md) |
| Dev loop (edit → ship → clean) | [docs/development.md](docs/development.md) |
| Credentials (credgoo) | [docs/credgoo.md](docs/credgoo.md) |
| Authoring best practices | [agent-skills](docs/agent-skills-best-practices.md) · [AGENTS.md](docs/agents-md-best-practices.md) · [pi-extensions](docs/pi-extensions-best-practices.md) |

## Repo layout

```
skills/      → 14 agent skills (surf, rodney, fetch-url, web-search, …)
extensions/  → pi extensions (heartbeat, statusline, xmodel, imagegen)
prompts/     → prompt templates (learn)
docs/        → guides + best-practices (browser-use, install, credgoo, …)
guides/      → setup guides (browser tools, Chrome DevTools, rodney)
api/         → reverse-engineered public APIs
skiller/     → skill discovery CLI (Python)
tests/       → per-skill test suites (e.g. tests/surf/furious.sh — 81 checks)
```

## Running tests

No global runner — each skill ships its own suite:

```bash
bash tests/fetch-url/test.sh
bash tests/web-search/test.sh
bash tests/rodney/test.sh
bash tests/surf/test.sh && bash tests/surf/furious.sh   # surf: structure + furious live validation
```

## Contributing

Every skill follows [`CONVENTION.md`](CONVENTION.md): `SKILL.md` + launcher (symlink resolution, `--update`/`--selfcheck`, auto-update) + `install.sh`/`install.bat` + `.gitignore` + `tests/<name>/test.sh`. Python skills use type hints + Google docstrings + credgoo. Never use `readlink -f` (breaks macOS) or `requirements.txt`.
