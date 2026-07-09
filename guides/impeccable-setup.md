# Impeccable — Setup Guide

## What

A design skill for AI coding agents: shapes, critiques, and hardens frontend
interfaces, and lints UI for AI-generated anti-patterns. Cross-harness — works
in pi, Claude Code, Codex, Cursor, Gemini CLI, OpenCode, Kiro, GitHub Copilot.

- **Source:** https://github.com/pbakaus/impeccable
- **Docs:** https://impeccable.style
- **CLI (npm):** `impeccable` — run any command with `npx impeccable <cmd>`

It is an **external** skill (not maintained in this repo). Install it per
machine/project with its own CLI; it drops a skill folder into your agent's
harness directory (e.g. `.pi/skills/impeccable/`).

## 1. Install the skill (per project or global)

`npx impeccable install` auto-detects every agent harness on your machine and
installs into the ones it finds. Run it from your project root for a project
install, or from `~` for a global install.

```bash
# Project install (recommended — skills travel with the repo)
cd ~/code/your-project
npx impeccable@latest install

# Or global (installed into ~/.pi, ~/.claude, ~/.codex, …)
cd ~
npx impeccable@latest install
```

The installer is interactive: it lists detected harnesses and asks which to
target. Skills land at `<harness>/skills/impeccable/` (pi: `.pi/skills/impeccable/`).
Updates and CI detection hooks are installed alongside.

**One machine, multiple agents?** Just run it once — it fans out to all detected
harnesses (pi, Claude, Codex, Cursor, Gemini, OpenCode, Kiro, Copilot).

## 2. Update / check for new versions

```bash
npx impeccable@latest check     # is an update available?
npx impeccable@latest update    # update the installed skills + hooks
```

The skill prints an `UPDATE_AVAILABLE` directive in `/impeccable` output when a
new version exists. It never blocks the current task.

## 3. First-time project setup — `/impeccable init`

Every project needs **two root files** before impeccable produces on-brand work.
Run this once per codebase (stop here if `/impeccable` already reports
PRODUCT.md + DESIGN.md present):

```
/impeccable init
```

It crawls the codebase once, interviews you briefly, then writes:

| File | Role | Answers |
|------|------|---------|
| `PRODUCT.md` | Strategic | Who/what/why: register, users, purpose, brand personality, anti-references, principles |
| `DESIGN.md` | Visual | How it looks: palette, typography, components, spacing (machine-readable spec) |
| `.impeccable/live/config.json` | Live mode | Pre-configures `/impeccable live` so it boots straight into variant mode |

**Register is the key decision** — it shapes everything downstream:

- `brand` — marketing, landing pages, campaigns, portfolios. *Design IS the product.*
- `product` — app UI, dashboards, admin, tools. *Design SERVES the product.*

Pick the one that describes the **primary** surface. It can be overridden per
task later.

## 4. Start working

Invoke it from your agent as `/impeccable …` (or whatever slash-command prefix
your harness uses). The three entry points:

```
/impeccable                          # bare → reads your project state and
                                     #   recommends the 2-3 best next commands
/impeccable <command> [target]       # run a specific command on a target
/impeccable <command>                # command help / flow without a target
```

### Commands you'll reach for first

| Command | When |
|---|---|
| `craft <feature>` | Build a feature end-to-end (shapes UX first, then builds) |
| `shape <feature>` | Plan the UX/UI before writing any code |
| `critique <surface>` | Scored UX review with prioritized issues (P0/P1/P2) |
| `audit <target>` | Technical checks: a11y, contrast, performance, responsive |
| `polish <target>` | Final pre-ship quality pass (reads the latest critique as its backlog) |
| `harden <target>` | Production-readiness: errors, edge cases, undo/safety, i18n |
| `live` | Pick elements in the browser and generate visual variants in place |

The full menu (24 commands: build / evaluate / refine / enhance / fix /
iterate) is one bare `/impeccable` away — it tailors the recommendation to your
register and current git/dev-server state.

### Typical first-session flow

1. `/impeccable init` — set up PRODUCT.md + DESIGN.md (once per project).
2. `/impeccable critique <main-surface>` — get a scored baseline + priority list.
3. Pick the top P1 → `/impeccable harden <surface>` (or `polish` / `clarify`).
4. `/impeccable live` — iterate visually in the browser while the dev server runs.

## 5. The anti-pattern detector (standalone + hooks)

impeccable ships a deterministic detector for AI-UI tells (side-stripe borders,
gradient text, off-palette colors, overused fonts, eyebrows, …). Three ways to
use it:

```bash
# Standalone scan of files or URLs
npx impeccable detect app/ components/ --json
npx impeccable detect https://your-site.example

# From inside the skill (same detector, no network)
node .pi/skills/impeccable/scripts/detect.mjs --json app components

# As a hook — auto-runs after direct UI edits and surfaces findings
/impeccable hooks on        # enable
/impeccable hooks status    # inspect
```

**Suppressing a finding you intend to keep** — two options:

- Inline ignore (travels with the file):
  ```html
  <!-- impeccable-disable overused-font -- exported brand doc -->
  <span style="font-family: Inter"></span> <!-- impeccable-disable-line overused-font -->
  ```
- Project config: `.impeccable/config.json` →
  `detector.ignoreRules` / `detector.ignoreFiles` / `detector.ignoreValues`.

The detector loads your `DESIGN.md` / `.impeccable/design.json` so it can flag
colors and fonts that drift outside your own system.

## 6. Where state lives

| Path | Holds |
|---|---|
| `.pi/skills/impeccable/` (per harness) | The skill itself: SKILL.md, reference/, scripts/ |
| `.impeccable/` (project root, gitignored) | `critique/` snapshots, `live/` config, `design.json`, `config.json` |
| `PRODUCT.md`, `DESIGN.md` (project root) | Commit these — they are the design source of truth |

Add `.impeccable/` to `.gitignore`. Keep `PRODUCT.md` and `DESIGN.md` in git —
every impeccable command reads them before doing work, and the detector uses
DESIGN.md to define your palette.

## 7. Verify

```bash
# Skill is installed and current
npx impeccable@latest check

# Project is set up
/impeccable            # should report PRODUCT.md + DESIGN.md present, not NO_PRODUCT_MD

# Detector runs on your code
npx impeccable detect app/ --quiet
```

Done. Restart your agent if the skill isn't picked up on first install.
