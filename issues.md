# Issues

Open issues and feature requests for skale-skills resources (skills, extensions,
prompts). Append new issues at the bottom. Use the following template:

```
## [issue-N] <short title>

- **Resource:** <skill|extension|prompt name>
- **Type:** bug | enhancement | question
- **Severity:** low | medium | high
- **State:** open

<description>

### Expected
<what should happen>

### Actual
<what happens instead>

### Reproduce
<steps>

### Context
<versions, config, terminal, etc.>
```

Number issues sequentially (`issue-1`, `issue-2`, …). Move resolved issues into a
`## Resolved` section at the bottom with a one-line resolution note and date.

---

## [issue-1] xmodel: no command to toggle the vision mode (`_vision.mode`)

- **Resource:** xmodel (extension)
- **Type:** enhancement
- **Severity:** medium
- **State:** resolved

The vision pipeline (`_vision.mode`: `delegate` | `switch` | `off`) can only be
changed by editing `~/.pi/agent/xmodel.json` and reloading. There is no slash
command or agent-facing control for it, unlike presets which have `/xm <name>`,
`/xm off`, `/xm edit`, and the `switch_model` tool.

This is a discoverability and UX gap: a user who wants inline image rendering in
the TUI (instead of VLM delegation) has to know to edit a JSON file by hand. The
`/xm off` command is especially misleading here — its name suggests it disables
vision, but it only clears the active preset and restores model defaults
(`clearPreset()`); it has no effect on `_vision.mode`.

### Expected

A way to switch the vision mode from inside a session, e.g.:

```
/xm vision              # show current _vision.mode
/xm vision off          # disable vision delegation/switch entirely
/xm vision delegate     # delegate: compress -> VLM sub-call -> text feedback (default)
/xm vision switch       # legacy: flip main model to vision for the turn
```

Changing the mode should also persist to `~/.pi/agent/xmodel.json` (and/or a
project-local `.pi/xmodel.json`) so it survives restarts, and take effect
immediately without a manual `/reload`.

### Actual

`_vision.mode` is read only from config files (`loadVisionConfig()` /
`readVisionRaw()`). Nothing in the `/xm` command handler or the `switch_model`
tool writes it. `/xm off` calls `clearPreset(ctx)` and is unrelated to vision.

### Reproduce

1. Start pi with a non-vision-capable main model and `_vision.mode = "delegate"`.
2. `read` an image (or attach one).
3. Observe the image is replaced by `[xmodel vision · <vlm>]: …` text — the TUI
   never renders it inline, even though `terminal.showImages = true` and the
   terminal supports the Kitty graphics protocol.
4. Try `/xm off` → only clears the preset; the next image is still delegated.
5. The only way to get inline rendering is to hand-edit `xmodel.json` and
   `/reload`.

### Context

- xmodel v0.2.0
- pi 0.80.3
- Terminal: Ghostty (Kitty graphics protocol supported)
- Relevant code: `extensions/xmodel.ts` — `loadVisionConfig()`, `readVisionRaw()`,
  the `/xm` command handler, and the `tool_result` hook that calls
  `delegateVision()`.

### Notes / implementation sketch

- Add a `vision` subcommand to the existing `/xm` handler (next to `edit`, `rm`,
  `models`, `version`, `off`).
- Bare `/xm vision` prints the current mode + configured `vlm`/`compressor`.
- `/xm vision <mode>` updates the in-memory `visionCfg.mode` and persists the
  full `_vision` block back to the config file (merge, don't overwrite other
  `_vision.*` keys). Reuse the existing `writeGlobal()` / `readRaw()` helpers —
  note they currently skip `_`-prefixed keys, so writing `_vision` needs a small
  dedicated path (mirror how `readVisionRaw` reads it).
- Consider surfacing the current vision mode in the status line (e.g. near the
  `⇄ <preset>` badge) so the active behavior is visible at a glance.
- Doc update: `extensions/xmodel.md` lists `/xm` subcommands — add `vision` and
  clarify that `/xm off` clears the preset, not the vision mode.

---

## Resolved

- **[issue-1]** xmodel: vision-mode toggle — **resolved 2026-07-08.** Added `/xm settings`
  (pi-style `SettingsList` hub over xmodel's own `_vision` store) and `/xm vision [mode]
  [global|project]`. Two-tier config (global canonical + project override, field-level merge),
  writes through immediately, persists to `xmodel.json`, surfaces an `👁` status badge. Also
  fixed a latent bug where `/xm edit` / `/xm rm` silently wiped `_vision` from the global file.
  See `extensions/xmodel.md` → *Vision pipeline*.
