# ZCode Plugin — skale-skills as a first-class zcode extension (sketch)

Status: **idea/sketch** — not implemented. Source of truth for zcode's
extension model: the built-in `zcode-guide` plugin (`zcode-configuration-guide`).

## Why

Today skale-skills reaches zcode one skill at a time: the installer symlinks
`skills/<name>` into `~/.zcode/skills/`. That carries static skills only.
zcode's **plugin** system can ship everything else a pi extension would —
commands, hooks, MCP servers, subagents — as ONE installable, versionable unit
from this very repo.

zcode's five resource types (see `zcode-configuration-guide`):

| Resource | Form | What it means for skale-skills |
|---|---|---|
| Skills | dir + `SKILL.md` | our `skills/*` — already works |
| Commands | `.md` files | thin `/skale-*` slash commands (prompts, not code) |
| Hooks | config/`hooks.json` | shell scripts on 7 lifecycle events |
| MCP | JSON servers | dynamic tools — shared `mcp.json` already covers this |
| Agents | subagent definitions | e.g. a "firmenindex" research subagent |
| *(packaging)* | **plugin** | bundles all of the above |

## pi extension → zcode mapping (what ports, what doesn't)

| pi extension feature | zcode equivalent | parity |
|---|---|---|
| `registerTool` | MCP server tool | ≈ external process instead of in-process |
| `registerCommand` | Command (`.md`) or skill slash-command | ≈ markdown prompts, no arbitrary code |
| lifecycle events | Hooks: `SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PermissionRequest`, `PostToolUse`, `PostToolUseFailure`, `Stop` (exactly 7) | partial |
| `turn_start`/`turn_end` (busy tracking) | — no equivalent | ✗ |
| `ctx.ui.setStatus` (statusline countdown) | — `outputStyles` is recorded, not executed | ✗ |
| `ctx.ui.notify` | hook script output (feedback channel) | ≈ |
| `appendEntry` + reconstruct | native session persistence; built-in scheduler persists across restarts | ≈ |
| scheduled followUp beats | **built-in scheduling** (recurring automations, survive restarts) | ≈ stronger, but no idle-shift, no countdown |
| one TS file bundles everything | **plugin.json** bundles everything | ✅ same idea, declarative |

## The manifest (phase-1 sketch)

`.zcode-plugin/plugin.json` at the repo root (zcode also recognizes
`.claude-plugin/` and `.codex-plugin/` — one dir can serve several agents):

```json
{
  "name": "skale-skills",
  "description": "skale skills, commands and hooks for zcode",
  "skills": "./skills",
  "commands": "./zcode/commands",
  "hooks": "./zcode/hooks.json"
}
```

- `skills: "./skills"` — the WHOLE catalog ships with the plugin (d2, peep,
  youtube, pdf2md, …). No per-skill symlinks needed anymore.
- Minimal valid manifest needs only `name` (regex `^[a-z0-9][a-z0-9._-]{0,127}$`).

### Example command (`zcode/commands/skale-laws.md`)

```markdown
---
description: Convert a PDF (e.g. a Firmenbuch Jahresabschluss) to Markdown via pdf2md
argument-hint: <pdf-path>
---
Convert the PDF at $ARGUMENTS with the pdf2md skill (auto mode). Write the
markdown next to the input file and summarize the three key figures.
```

### Example hook (`zcode/hooks.json`)

```json
{
  "hooks": {
    "SessionStart": [
      { "type": "command", "command": "echo 'skale-skills plugin active (v$npm_package_version)'" }
    ]
  }
}
```

Plugin hooks enable the hook runner automatically (config-file hooks alone
need `hooks.enabled: true`).

## The heartbeat case (pi extension vs zcode)

The pi heartbeat extension (reminder + statusline countdown + idle-shift)
maps to zcode like this:

- **Recurring reminders** → zcode's built-in scheduler. "Remind me every
  5 minutes" = a recurring automation that re-invokes the agent — survives
  app restarts (pi's heartbeat dies with the process).
- **Idle-shift** (never fire mid-turn) → no equivalent; a beat arriving
  mid-turn is simply queued into the conversation.
- **Statusline countdown** → no equivalent today.
- **Status persistence + lost-heartbeat notice** → native (automations
  persist; their state is managed by zcode, not by us).

Conclusion: don't port heartbeat.ts. In zcode, scheduling is a platform
feature; our value-add would be at most a `/heartbeat` command that sets the
automation up with a sensible prompt.

## Install & precedence

- Install: zcode → **Settings → Plugin Management → Discover** → add this
  GitHub repo as marketplace/plugin source. Enable/disable state lives in
  `~/.zcode/cli/config.json` under `plugins`.
- Precedence: plugin roots are the **lowest** skill/command layer — user
  (`~/.zcode/skills`) and workspace (`<repo>/.zcode/skills`) override plugin
  copies. Our existing installer symlinks therefore keep winning over plugin
  skills; migration = drop the symlinks (or keep them for overrides).
- Secrets: never in the plugin. Credentials stay in credgoo/env.

## Rollout sketch

1. **Phase 1 — skills only.** Add `.zcode-plugin/plugin.json` with
   `skills: "./skills"`. Test via a local-directory marketplace. Deprecate
   the installer's zcode-symlink section once validated.
2. **Phase 2 — commands + a first hook.** A few `/skale-*` commands
   (pdf2md, firmenindex lookup, heartbeat-setup) and one SessionStart hook.
3. **Phase 3 — MCP + subagents.** Only if something genuinely needs a
   dynamic tool in zcode that a skill cannot do (so far: nothing — skills
   + built-ins cover our workflows).

## Open questions

- Does a plugin skill shadow or duplicate our installer symlinks in
  `~/.zcode/skills/` (same names → first-in-discovery wins → user scope
  wins)? Symlinks should be removed at plugin adoption.
- Hook payload/limits for the 7 events (stdin schema, timeouts) — validate
  in phase 2 with a no-op script.
- Marketplace naming: is `skale-skills` as both npm-pi-package and
  zcode-plugin name fine, or split repos later?
