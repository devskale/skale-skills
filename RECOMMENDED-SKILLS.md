# Recommended External Skills

Skills not maintained here. Install from upstream sources.

## Quick Install

```bash
skiller install <name>              # from crawled index
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
| **Vercel** | Agent skills | https://github.com/vercel-labs/agent-skills |
| **skills.sh** | Skill marketplace/manager | https://skills.sh/ |
| **skillsmp.com** | Skill marketplace | https://skillsmp.com/ |
| **context7** | Skill manager | https://context7.com/?tab=skills |

## Skill Managers

```bash
# openskills — multi-agent skill installer
npm install -g openskills
openskills install <org>/<repo>
openskills install <org>/<repo>/<skill>   # specific skill

# skiller — search and install from crawled index
skiller crawl                    # build index from skill-sites.md
skiller search <query>           # find skills
skiller install <name>           # install skill

# Anthropic skills
npx @anthropic-ai/skills add <name>
```

## Recommended Skills (get upstream, don't maintain locally)

| Skill | What | Best Source |
|-------|------|-------------|
| **docx** | Create/edit Word documents | `npx @anthropic-ai/skills add docx` |
| **xlsx** | Create/edit Excel spreadsheets | `npx @anthropic-ai/skills add xlsx` |
| **markdown-converter** | Convert docs to markdown (markitdown) | `skiller search markdown` |
| **command-creator** | Create agent commands | `skiller search command` |
| **readme-write** | Generate README.md files | `skiller search readme` |
| **agent-skill-creator** | Guide for creating skills | `skiller search skill creator` |
| **oebb-scotty** | Austrian rail planner (ÖBB) | `skiller search oebb` |

## What We Maintain Here

Only **custom skills** we actively develop:

- **fetch-url** — web content extraction with smart fallback
- **web-search** — web search via SearXNG + Duck API
- **video-transcript-downloader** — yt-dlp wrapper, downloads + transcripts
- **youtube** — Invidious API video search with auto-fallback
- **rodney** — headless Chrome automation
- **todo** — TODO.md task tracking
- **improve-skill** — skill improvement from session transcripts

## API Docs

Reverse-engineered public APIs useful for agents:

- **[api/ryanair/](api/ryanair/)** — Ryanair fare search (free, no auth)
