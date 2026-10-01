# Recommended External Skills

Skills not maintained here. Install from upstream sources.

## Quick Install

```bash
openskills install <org>/<repo>     # openskills CLI
npx @anthropic-ai/skills add <name> # Anthropic skills
```

## Where to Find Skills

| Source | What | URL |
|--------|------|-----|
| **Anthropic** | Official Claude skills (docx, xlsx, etc.) | https://github.com/anthropics/skills |
| **cursor/plugins** | Official Cursor plugin marketplace — skills + agents + rules + `mcp.json` for 80+ dev-tool/SaaS integrations (github, playwright, gmail, google-drive, …) and first-party workflows (`thermos`, `advisor`, `orchestrate`) | https://github.com/cursor/plugins |
| **emilkowalski** | Front-end craft: animation (web + Expo), Apple-style design, motion review, UI library picks, Swift. ~42k ★ | https://github.com/emilkowalski/skills |
| **humanlayer** | Advanced-workflow skills — agentic control loops, iterated CI loops, visual PRs, HTML explainers, CLAUDE.md rewriting. ~4.6k ★ | https://github.com/humanlayer/skills |
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

### cursor/plugins — official Cursor plugin marketplace

https://github.com/cursor/plugins — ~9k ★, MIT. A **multi-plugin marketplace**: each plugin is its
own top-level directory with a `.cursor-plugin/plugin.json` manifest, holding `skills/`, `agents/`,
`rules/`, and its own `mcp.json`. Root `.cursor-plugin/marketplace.json` lists all of them.

- **First-party workflows** (agents + skills) — `thermos` (deep security/correctness branch review
  with parallel subagents), `advisor` (consult a stronger model before major decisions / before
  declaring done), `orchestrate` (fan large tasks across parallel cloud agents), `pstack`,
  `pr-review-canvas`, `ralph-loop`, `create-plugin`, `cli-for-agent`.
- **SaaS integrations as MCP plugins** — `github`, `playwright`, `gmail`, `google-drive`,
  `google-calendar`, `vercel`, +70 more, each shipping a `mcp.json` you can lift into your own
  pi `mcp.json` (see [MCP setup](docs/browser-use/chrome-dev.md)).

Skills are plain `SKILL.md` files, and nested several levels deep, so **always pass `--full-depth`**:

```bash
# list what's available (99 skills as of 2026-09)
npx skills@latest add cursor/plugins -l --full-depth

# install one
npx skills@latest add cursor/plugins -s thermo-nuclear-review -g
```

> ⚠️ One known defect: `agent-compatibility`'s SKILL.md has a YAML parse error (unquoted `:` in a
> long `description:`) and is skipped by the installer with a warning. Everything else installs.

### emilkowalski/skills — front-end craft

https://github.com/emilkowalski/skills — ~42k ★, MIT, Markdown. 13 skills, all animation/UI/mobile
craft. The highest-signal ones:

| Skill | What |
|-------|------|
| `emil-design-eng` | The philosophy itself: UI polish, component design, animation decisions, invisible details |
| `animate` | Web animation with the decisions made in the right order and exact values |
| `animate-expo` | React Native / Expo + Reanimated + Gesture Handler, incl. off-device haptics |
| `apple-design` | Apple's interface + motion approach translated to the web (springs, sheets, translucent depth, typography) |
| `review-animations` | Reviews motion code against a high bar; **default to flagging, approval is earned** |
| `improve-animations` | Read-only codebase motion audit → prioritized plan for other agents to execute |
| `find-animation-opportunities` | Read-only: proposes motion with exact values, rejects what shouldn't move |
| `mobile-native` | Make a web app feel installed — 100vh, tap highlight, hover stickiness, notch |
| `pick-ui-library` | Opinionated library pick per task (OTP inputs, charts, command menus, toasts…) |
| `write-swift` | Modern Swift: value types, Swift 6 concurrency, `@concurrent`, Swift Testing, macros |
| `ask-sonner` | Sonner toast wiring + the failure modes (no show, double show, dark mode) |
| `animation-vocabulary` | Reverse lookup: vague motion description → the exact term |
| `prototype` | Builds several genuinely different UI versions behind a visual picker to promote one |

```bash
npx skills@latest add emilkowalski/skills -s emil-design-eng -g
```

### humanlayer/skills — advanced workflows

https://github.com/humanlayer/skills — ~4.6k ★, 147 forks, MIT, TypeScript. 6 skills, each its own
plugin under `plugins/` (so also nested — pass `--full-depth` if you install more than one by name).
These are interview-driven: they ask you questions and then *build* something.

| Skill | What |
|-------|------|
| `design-control-loop` | Interviews you to design an agentic control loop (sensor / controller / actuator / disturbances) for your codebase, then builds it as runnable components + a scheduled agent workflow |
| `build-iterated-agentic-loop` | Repo-local skill + a matching iterated coding-agent GitHub Actions workflow, prompt, memory file, reference templates |
| `visual-pr` | PR with a concise visual outline so reviewers can actually see the change |
| `show-me` | Explains the current topic with diagrams, code-shape sketches, focused HTML artifacts |
| `improve-claude-md` | Rewrites CLAUDE.md using `<important if>` blocks to improve instruction adherence |
| `narrow-react-prop-types` | Narrows React prop types to live code paths instead of Storybook/test/mock-only states |

```bash
npx skills@latest add humanlayer/skills -s design-control-loop -g
```

> Claude Code-shaped: several assume `CLAUDE.md` and `/`-invocation. The `SKILL.md` bodies are
> portable, but check each one for Claude-specific paths before relying on it in another agent.

## Where to Find Extensions

| Source | What | URL |
|--------|------|-----|
| **earendil-works (pi)** | Official pi extension examples | https://github.com/earendil-works/pi/tree/main/packages/coding-agent/examples/extensions |
| **ogulcancelik** | Community pi extensions library | https://github.com/ogulcancelik/pi-extensions |

## Local Extensions

We maintain a few extensions in [`extensions/`](extensions/):

| Extension | What |
|-----------|------|
| **heartbeat** | Recurring reminder/heartbeat timer the agent can start/stop |
| **statusline** | Custom pi footer with machine name branding + session stats |
| **xmodel** | Model/thinking fast-switcher + opt-in vision pipeline (`read` stays display-only) |
| **imagegen** | Text→image tool + `/imagegen` command with self-healing defaults and ASCII preview |

## Skill Managers

```bash
# openskills — multi-agent skill installer
npm install -g openskills
openskills install <org>/<repo>
openskills install <org>/<repo>/<skill>   # specific skill

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
| **ponytail** | Ruleset that makes your AI coding agent write the **least code that works** — stdlib over custom, native over deps, one line over fifty (YAGNI ladder). “The lazy senior dev for your AI agent.” | [ponytail.dev](https://ponytail.dev) · [GitHub](https://github.com/DietrichGebert/ponytail) |

### Matt Pocock's Skills (`mattpocock/skills`) — recommended, install globally

Engineering skills for real work: `grill-me`, `tdd`, `diagnosing-bugs`, `triage`, `code-review`, `implement`, `research`, `prototype`, `domain-modeling`, `codebase-design`, and ~25 more. **Install globally once** so every project sees the same version — no per-project `skills-lock.json` drift.

```bash
# Install once, globally (user-level)
npx skills@latest add mattpocock/skills -g -y
```

Files land at `~/.agents/skills/`; Pi auto-discovers them via symlinks in `~/.pi/agent/skills/`. One source of truth, available in every project.

```bash
# Update all global skills to latest
npx skills@latest update -g

# Remove specific skills (or all) from the global scope
npx skills@latest remove -g -y <skill>...   # e.g. remove -g -y tdd grill-me
npx skills@latest remove -g -y -s '*'       # all global skills
```

> ⚠️ **`pi config` / `pi config -l` does not manage these.** `mattpocock/skills` ships no pi manifest, so it is **not** a pi package — `pi config` only toggles resources from installed packages. These skills load via `~/.pi/agent/skills/` symlinks, so add and remove them with the `skills` CLI above, not `pi config`. To temporarily disable one without removing it, delete the symlink from `~/.pi/agent/skills/` (re-add with `npx skills@latest add mattpocock/skills -g -y`).

## What We Maintain Here

Only **custom skills** we actively develop:

- **surf** — drive your real, logged-in Chrome via AppleScript (no daemon, no debug port)
- **web-search** — web search via SearXNG + Duck API
- **fetch-url** — web content extraction with smart fallback
- **figure** — hand-drawn architecture/pipeline figures from a small spec
- **video-transcript-downloader** — yt-dlp wrapper, downloads + transcripts
- **youtube** — Invidious API video search with auto-fallback
- **rodney** — headless Chrome automation
- **d2** — diagrams as code (D2 language). `openskills install devskale/skale-skills/skills/d2`

## API Docs

Reverse-engineered public APIs useful for agents:

- **[api/ryanair/](api/ryanair/)** — Ryanair fare search (free, no auth)
