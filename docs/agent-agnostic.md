# Agent-agnostic roadmap + repo review

> **Living document.** Status of the repo review and the agent-agnostic plan. Edited on the
> go — checkboxes are the source of truth for what is decided/done. Last updated: 2026-10-01.

## Verdict: is the repo good?

**Yes — on engineering it is ahead of every peer we compared against; on distribution it is
invisible.** The honest framing: this is a well-tested, well-documented skills repo with
~3 stars, competing in an ecosystem where visibility, not quality, is the scarce resource.

Strengths that are rare in the ecosystem (most peers have none of these):

- **Per-skill test suites** — 20 suites, ~700 assertions, honest WARN counters for
  network-dependent checks. None of the compared repos tests anything.
- **A gate**: `scripts/check.sh` on commit/push (lint, typecheck, docs integrity, suites).
- **Launchers with auto-update** (`~/.local/bin/<cmd>`, 7-day re-sync, `--selfcheck`).
- **Credential hygiene** via credgoo — no `.env` tokens, per-skill resolution order.
- **Deprecation discipline** — manifest-level excludes, archive + migration tables,
  `docs/deprecation.md` procedure.
- **Docs integrity as a test** — dead links and orphaned docs fail the suite.

Weaknesses, ranked:

1. **Distribution/visibility** — listed in none of the big directories (VoltAgent
   awesome-agent-skills, linny006, skills.sh aggregators). Peers with worse engineering
   have 1000× the reach.
2. **Install story is clone + script + symlink** for non-pi agents; no plugin manifests
   (superpowers ships 9 per-agent plugin dirs; anthropics ships `.claude-plugin`).
3. **Mixed identity** — `skills/` are agent-agnostic bash; `extensions/` are pi-only
   TypeScript; the README sells the whole thing as "for pi-agent".
4. **No `spec/`/`template/`** — anthropics/skills ships a spec and a skill template for
   contributors; our conventions live in CODING_RULES.md prose.

## Ecosystem comparison (2026-10-01)

| Repo | ★ | Model | Install | Agent-agnostic? | Tests |
|---|---|---|---|---|---|
| [obra/superpowers](https://github.com/obra/superpowers) | 294k | framework + dev methodology | plugin marketplaces | **9 plugin dirs** (claude, codex, cursor, devin, hermes, kimi, muse, opencode, .agents) | none |
| [anthropics/skills](https://github.com/anthropics/skills) | 179k | official reference + spec | clone & copy, `.claude-plugin` | spec is the standard (agentskills.io); ships `.claude-plugin` only | none |
| [emilkowalski/skills](https://github.com/emilkowalski/skills) | 43k | knowledge skills (design craft) | npx / skills.sh | agnostic (pure SKILL.md, no scripts) | none |
| [VoltAgent/awesome-agent-skills](https://github.com/VoltAgent/awesome-agent-skills) | 35k | directory (1000+ links) | n/a | n/a | n/a |
| [humanlayer/skills](https://github.com/humanlayer/skills) | 4.8k | workflow skills (interview-driven) | clone & copy | agnostic | none |
| [narumiruna/pi-extensions](https://github.com/narumiruna/pi-extensions) | 640 | pi-only extensions monorepo | pi package | pi-only | none |
| **devskale/skale-skills** | 3 | ops skills (bash) + pi extensions | pi package **and** symlink installer | skills agnostic, extensions pi-only | **20 suites** |

Takeaways:

- The **format war is over** — SKILL.md (name/description, progressive disclosure) is the
  open standard (agentskills.io). Our frontmatter (name/version/description) is
  standard-compatible; `version` is an allowed extra.
- **superpowers is the distribution model to copy**: one repo, per-agent plugin manifests,
  so every agent's native installer lists it.
- **Our differentiator is engineering** (tests/gate/launchers/creds). Nobody else has it,
  which is both the moat and the reason nobody has heard of us — we never listed anywhere.

## Audit: what is already agent-agnostic

| Piece | Status |
|---|---|
| `skills/*/SKILL.md` frontmatter | ✅ standard format (name/description required; version extra) |
| `skills/*` code (bash launchers) | ✅ agent-agnostic; 4 soft pi mentions (install hints in d2/figure docs, one fallback path in web-search launcher) — degrade gracefully |
| `~/.local/bin/<cmd>` launchers | ✅ agent-agnostic |
| `install.sh` + `scripts/link-agents.sh` | ✅ links to `~/.agents/skills` (standard) + optional `~/.zcode`, `~/.claude`, `~/.codex`; choice persisted in `~/.config/skale-skills/link-agents.conf` |
| `scripts/skill-filter.sh` | ⚠️ pi settings only (see decision below — stays) |
| `extensions/*.ts` (heartbeat, imagegen, statusline, xmodel) | ❌ pi-only (TypeScript against pi's extension API) |
| `prompts/` (learn.md) | ❌ pi manifest (`pi.prompts`) |
| `package.json` `pi` manifest | ❌ pi-only packaging |

## Decisions

- **pi stays the priority** — packaging, settings filter (`pi config` + `skill-filter.sh`),
  extensions, docs. The pi support is a feature, not a liability. Keep as-is.
- **`~/.agents/skills` is the agent-agnostic channel** — the spec-standard dir that
  zcode/opencode/spec-compliant agents (and pi itself) read natively. Already wired.
- **pi-priority is enforced, not hoped for** — pi scans `~/.agents/skills` at user
  precedence and wins every name collision against package skills, bypassing the
  package filter. `scripts/link-agents.sh` therefore manages a `!skills/<name>/**`
  exclusion for every linked skill in pi's user settings
  (`~/.pi/agent/settings.json`, overridable via `PI_SETTINGS`): pi keeps loading
  these skills from the package copy (filtered, versioned via `pi install`), other
  agents read the links unchanged. Name-scoped: exclusions only match our skill
  names, never foreign skills in the same dir. Verified against pi's discovery
  order (user-auto rank 3 < package rank 4 — user always wins; the exclusion is
  the only lever).
- **skill-filter.sh stays pi-only.** The settings-filter support is exactly the pi-first
  value the user wants kept; generalising it would mean reimplementing every other agent's
  settings model for near-zero demand.
- **extensions stay pi-only.** Porting TypeScript extensions to other agents is a rewrite
  per agent (different APIs). Keep them clearly labelled as the pi pack instead.

## Plan

Status: ☐ open · ◐ in progress · ☒ done

- ☒ **Audit** what is agnostic vs pi-locked (this page)
- ☒ **Decide identity**: agnostic skills core + first-class pi pack; pi keeps priority
- ☐ **README repositioning**: "agent-agnostic ops skills, first-class pi package" — the
  README currently undersells both the agnostic reach and the testing moat
- ☐ **Get listed**: PR to VoltAgent/awesome-agent-skills + linny006 list; check
  skills.sh / skillsmd submission paths (these aggregators are how emilkowalski got reach)
- ☐ **Verify the 4 agent dirs**: confirm which agents actually read `~/.agents/skills`
  natively today (spec-compliant list changes; re-check before extending
  `link-agents.sh` with more targets like opencode/gemini native dirs)
- ☒ **Soften the last functional pi-coupling**: `skills/web-search/search` fallback path
  `~/.pi/agent/skills/` — now probes agent skill dirs standard-first
  (`~/.agents/skills` → `~/.pi/agent/skills` → `~/.claude` → `~/.codex`); pi remains
  a first-class probe target, the agentskills.io standard dir just comes first
  (every spec-compliant agent, pi included, reads it). Tested in the suite.
- ☐ **Later / optional**: per-agent plugin manifests following the superpowers pattern
  (`.claude-plugin/`, plugin marketplace JSON) — only if we want marketplace reach;
  the symlink installer already covers file-based agents
- ☐ **Later / optional**: `template/` dir for new skills (anthropics pattern) —
  CODING_RULES.md prose today; a template + the lint gate would enforce it mechanically
