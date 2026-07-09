# Recommended External Skills

Skills not maintained here. Install from upstream sources.

## Quick Install

```bash
skiller install <name>              # install a local skill across agents
npx @anthropic-ai/skills add <name> # Anthropic skills
openskills install <org>/<repo>     # openskills CLI
```

## Where to Find Skills

| Source | What | URL |
|--------|------|-----|
| **Anthropic** | Official Claude skills (docx, xlsx, etc.) | https://github.com/anthropics/skills |
| **numman-ali** | Large community collection | https://github.com/numman-ali/n-skills |
| **badlogic** | Pi-specific skills | https://github.com/badlogic/pi-skills |
| **moltbot** | Curated Claude skills | https://github.com/moltbot/skills |
| **OpenAI** | Official OpenAI skills | https://github.com/openai/skills |
| **mitsuhiko** | Agent scripts (Python) | https://github.com/mitsuhiko/agent-stuff |
| **steipete** | Agent scripts | https://github.com/steipete/agent-scripts |
| **openclaw** | Agent skills (handoff, autoreview, crabbox) | https://github.com/openclaw/agent-skills |
| **mattpocock** | Engineering skills (grill-me, tdd, diagnose, triage) | https://github.com/mattpocock/skills |
| **Vercel** | Agent skills | https://github.com/vercel-labs/agent-skills |
| **skills.sh** | Skill marketplace/manager | https://skills.sh/ |
| **skillsmp.com** | Skill marketplace | https://skillsmp.com/ |
| **context7** | Skill manager | https://context7.com/?tab=skills |

## Where to Find Extensions

| Source | What | URL |
|--------|------|-----|
| **earendil-works (pi)** | Official pi extension examples | https://github.com/earendil-works/pi/tree/main/packages/coding-agent/examples/extensions |
| **ogulcancelik** | Community pi extensions library | https://github.com/ogulcancelik/pi-extensions |

## Local Extensions

We maintain a few extensions in [`extensions/`](extensions/):

| Extension | What |
|-----------|------|
| **statusline** | Custom pi footer with machine name branding + session stats |

## Skill Managers

```bash
# openskills — multi-agent skill installer
npm install -g openskills
openskills install <org>/<repo>
openskills install <org>/<repo>/<skill>   # specific skill

# skiller — install local skills across multiple agents (pi, claude, opencode, ...)
skiller install <name>           # install skill
skiller remove <name>            # remove skill

# Anthropic skills
npx @anthropic-ai/skills add <name>
```

## Recommended Extensions (install with `pi install`)

> 💡 **Install `pi-mcp-adapter` first.** It's the most important pi extension — without it you can't use MCP servers (databases, browsers, external APIs) efficiently. One ~200-token proxy tool replaces hundreds of per-tool definitions that would otherwise burn your context window. This is the one install we suggest for every Pi setup: `pi install npm:pi-mcp-adapter`.

| Extension | What | Install |
|-----------|------|---------|
| **pi-herdr** | Herdr pane/tab/workspace orchestration from pi | `pi install npm:@ogulcancelik/pi-herdr` |
| **pi-web-browse** | Web search + page fetch via headless browser (CDP). Bypasses bot protection, persistent daemon for speed. Use when `fetch-url` and `web-search` get blocked. | `pi install npm:@ogulcancelik/pi-web-browse` |
| **pi-mcp-adapter** | Use MCP servers in Pi without burning context — one proxy tool (~200 tokens) instead of hundreds; servers start on demand, optional direct-tool registration. | `pi install npm:pi-mcp-adapter` |

## Recommended Tools

| Tool | What | Install |
|------|------|---------|
| **herdr** | Agent terminal multiplexer — workspaces, tabs, panes with agent awareness | `brew install herdr` or `curl -fsSL https://herdr.dev/install.sh \| sh` |

## Recommended Skills (get upstream, don't maintain locally)

| Skill | What | Best Source |
|-------|------|-------------|
| **docx** | Create/edit Word documents | `npx @anthropic-ai/skills add docx` |
| **xlsx** | Create/edit Excel spreadsheets | `npx @anthropic-ai/skills add xlsx` |
| **oebb-scotty** | Austrian rail planner (ÖBB) | [skills.sh](https://skills.sh) (search) |
| **peep** | X/Twitter — read, search, post, bookmarks, trending | [devskale/peep](https://github.com/devskale/peep) |
| **impeccable** | Design skill: shape, critique, harden, polish frontend UI + anti-pattern detector. Cross-harness (pi, Claude, Codex, Cursor, …). Setup guide: [`guides/impeccable-setup.md`](guides/impeccable-setup.md) | [pbakaus/impeccable](https://github.com/pbakaus/impeccable) · `npx impeccable install` |

## What We Maintain Here

Only **custom skills** we actively develop:

- **fetch-url** — web content extraction with smart fallback
- **web-search** — web search via SearXNG + Duck API
- **video-transcript-downloader** — yt-dlp wrapper, downloads + transcripts
- **youtube** — Invidious API video search with auto-fallback
- **rodney** — headless Chrome automation
- **browser-use** — persistent browser automation with session continuity
- **todo** — TODO.md task tracking
- **improve-skill** — skill improvement from session transcripts
- **agent-skill-creator** — guide for creating skills for any AI agent
- **agents-md-init** — create and update AGENTS.md files
- **command-creator** — create custom commands for Pi and OpenCode
- **readme-write** — generate and update README.md files
- **d2** — diagrams as code (D2 language). `openskills install devskale/skale-skills/skills/d2`

## API Docs

Reverse-engineered public APIs useful for agents:

- **[api/ryanair/](api/ryanair/)** — Ryanair fare search (free, no auth)
