# Recommended External Skills

Skills not maintained here. Install from upstream sources.

## Quick Install

```bash
# Best skill managers
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

## Common Skills (get upstream, don't maintain locally)

| Skill | Best Source | Install |
|-------|-------------|---------|
| **docx** | Anthropic | `npx @anthropic-ai/skills add docx` or `skiller install docx` |
| **xlsx** | Anthropic | `npx @anthropic-ai/skills add xlsx` or `skiller install xlsx` |
| **markdown-converter** | Community | `skiller search markdown` |
| **command-creator** | Community | `skiller search command` |
| **readme-write** | Community | `skiller search readme` |
| **agent-skill-creator** | Community | `skiller search skill creator` |

## What We Maintain Here

Only **custom skills** we actively develop:

- **fetch-url** — web content extraction with smart fallback
- **web-search** — web search via SearXNG + Duck API
- **video-transcript-downloader** — yt-dlp wrapper, downloads + transcripts
- **youtube** — Invidious API video search
- **rodney** — headless Chrome automation
- **oebb-scotty** — Austrian rail API
- **todo** — TODO.md task tracking
- **improve-skill** — skill improvement from session transcripts

Everything else should come from upstream. Less duplication, less maintenance.
