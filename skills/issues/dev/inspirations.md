# Inspirations — external tools worth learning from

> Maintainer knowledge, NOT agent content: `dev/` is the skill-local home
> for developer-facing notes — it travels WITH the skill, but progressive
> disclosure never touches it (that's `references/`'s job). The agent using
> the skill never needs this; only the developer deciding where it grows.
> Every entry names what to take and what NOT to take. Checked 2026-11-01.

## issues

### kanzo — browser kanban + MCP server in one binary

<https://github.com/emanuele-em/kanzo> · Rust · AGPL-3.0 · ~315 ★ (1 week old)

A kanban board in the browser AND an MCP server in one 4 MB program. Agents
connect via MCP ("take the next task"), move cards live, comment with image
attachments. Sync = a private git repo, committed only at explicit
`kanzo sync` moments.

**Worth taking:**
- **The live board.** Agents move cards while you watch — our `board-html` is
  a static snapshot. A `--live` variant (auto-refresh/SSE) would make
  parallel sessions observable without touching the CLI design.
- **Git-sync in moments, not continuously.** Commits happen only at explicit
  sync points (single-writer moment, conflict → user picks). This is exactly
  the pattern behind our 2026-10-21 autocommit ban and the purge-snapshot:
  validated as architecture, not just incident.
- **Column gating as a hard rule.** "Agents leave the Backlog column alone
  until moved to todo" — our `## Excluded`/Candidates are convention; a
  per-column `agent-visible: false` config would be the hard variant.

**Not taking:** SQLite binary storage (our markdown is grep/diff/retro-able),
AGPL, the MCP-only agent surface (bash CLI is agent-agnostic).

### hex — local-first voice dictation

<https://github.com/anomalyco/hex> · Rust · macOS/Win/Linux

Hold a shortcut, speak, release — on-device transcription pastes into
whatever app has focus. Local model, no cloud for ordinary dictation;
"Modes" for corrections and app-specific behavior.

**Worth taking:**
- **Local-first as a stated product property.** Hex proves the "no account,
  no server, your data stays on device" pitch is a feature users pick — the
  same pitch `issues` lives by (works root on your machines, Syncthing, no
  SaaS). Worth saying it as loudly.
- **Dev channel + self-updater + signed releases.** Every dev push is a
  published build that updates itself — the grown-up version of our 7-day
  launcher checks. Relevant if `issues` ever ships as more than a script.
- **Modes (correction profiles).** App-specific behavior in one tool — the
  shape of our per-project `.issues/config` (triage vocab, modules) done
  visually.

**Not taking:** voice as an input surface for issues (nonsense for a kanban
CLI) — hex is here for the local-first + updater patterns.
