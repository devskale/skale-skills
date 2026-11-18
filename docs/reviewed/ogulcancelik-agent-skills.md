# ogulcancelik/agent-skills

Status: **reviewed — not adopted** (2026-11-10)

<https://github.com/ogulcancelik/agent-skills> — MIT, two skills: `web-search`, `preflight`.
Install path shown by the author: `npx skills add ogulcancelik/agent-skills` (Vercel `skills`
CLI, skills.sh — supports pi via `~/.agents/skills/`).

## Why not adopted

### Not an install path for our own skills

The Vercel `skills` CLI copies skill directories only. For skale-skills that breaks four ways:

1. **No `install.sh` execution** — our skills need launchers in `~/.local/bin`, Python venvs
   outside the repo (`UV_PROJECT_ENVIRONMENT`), credgoo. Commands would fail with no launcher.
2. **Extensions/prompts invisible** — the CLI ships only `SKILL.md` dirs; the `pi` manifest
   in `package.json` (heartbeat, xmodel, statusline, imagegen) is ignored.
3. **`skills/deprecated/` gets discovered** — the CLI walks `skills/` 3 levels deep, so
   `skills/deprecated/viewimg` would reappear as installable.
4. **Bypasses the pi-package mechanism** — no versioning via `pi install`, no `pi config`
   filtering, no auto-updating package clone; collides with our pi-priority exclusions.

Canonical install stays: `pi install git:github.com/devskale/skale-skills` + `./install.sh`.

### web-search (his) vs web-search (ours)

His approach: persistent headless-browser daemon (HTTP API, port 9377) + CDP, scrapes
Google directly in a real browser (fingerprint-consistent UA/brands/device-memory),
DuckDuckGo-HTML fallback, bot-protection wait loop (30s), Google-consent auto-click,
result-set IDs with 10-min cache + selective `--fetch 1,3,5`, browser lifecycle rotation
(4h / 75 requests max, crash recovery).

| | ours | his |
|---|---|---|
| Backend | SearXNG + Duck API | Google scraped in real browser |
| Weight | 1 Python script | Bun + Playwright + resident daemon + browser |
| Bot-protected pages | no (→ rodney / fetch-url) | yes, core feature |
| Stability | depends on public SearXNG instance | depends on Google's tolerance |
| Categories (images/news/video) | yes | no |

**Verdict:** solves a different problem ("free search AND protected pages, zero API keys");
our stack solves "fast, light, reliable snippets" and already has rodney for protected pages.
No overlap that would replace anything.

Weak points in his approach: Google-scraping is whack-a-mole (locale-specific block
signals, consent selectors break constantly); heavy resource footprint; fixed ports;
sequential multi-fetch; his own SKILL.md needs a long daemon-troubleshooting section —
a tell for operational overhead.

### preflight

Pre-implementation risk-challenge workflow (fresh-context child agents challenge the plan
before coding, contract verification after). Explicitly experimental per the author.
Overlaps with our `code-review` skill (Standards/Spec axes). Not reviewed in depth —
revisit if it stabilizes.

## Worth stealing (ideas, deliberately not implemented)

1. **Result-set-ID + selective fetch** — `web-search` could cache result IDs and let
   `fetch-url` consume them directly, instead of copy-pasting URLs between the two.
2. **Bot-protection wait loop as a fetch-url fallback tier** — if SearXNG/HTTP fail,
   one browser attempt before escalating to rodney.
3. The daemon approach itself is what rodney already does — confirmation of our design,
   not a novelty.
