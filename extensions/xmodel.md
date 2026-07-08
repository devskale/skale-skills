# xmodel — model/thinking fast-switcher

Fast-switch model + thinking-level presets from inside a pi session, with optional
automatic fallback to a free variant when the active provider rate-limits (HTTP 429/503/529).

Lives at `~/.pi/agent/extensions/xmodel.ts` (symlinked into the skale-skills repo).

## Commands

| Command | What |
|---|---|
| `/xm <name>` | Switch to preset `<name>` (sets model + thinking level) |
| `/xm` | Picker — switch preset (or `(off)`) |
| `/xm settings` | **Vision hub** — pi-style settings list for the vision pipeline (mode, vlm, compressor, brief) with global/project scope |
| `/xm vision [mode] [global\|project]` | Show, or set, the vision mode (`delegate` \| `switch` \| `off`) |
| `/xm edit [name]` | Add/edit a preset (provider, model, thinking, instructions) |
| `/xm rm [name]` | Remove a preset |
| `/xm models [query]` | Browse provider/model from the live registry |
| `/xm off` | Clear the active preset, restore defaults (**does not disable vision** — use `/xm vision off`) |
| `/xm version` | Show version |

## Config

Presets live in `~/.pi/agent/xmodel.json` (project-local `.pi/xmodel.json` overrides):

```jsonc
{
  "deep":       { "provider": "zai",        "model": "glm-5.2",            "thinkingLevel": "high",   "fallback": "deep-free" },
  "deep-free":  { "provider": "opencode",    "model": "deepseek-v4-flash-free", "thinkingLevel": "high" },
  "light":      { "provider": "zai",        "model": "glm-5.2",            "thinkingLevel": "off" },
  "vision":     { "provider": "opencode",    "model": "claude-sonnet-4-6",  "thinkingLevel": "medium" }
}
```

### Fallback resolution (first match wins)

1. **Explicit** `fallback` field on the active preset → switch to that preset.
2. **`<name>-free` convention** → e.g. active `deep` looks for `deep-free`.
3. **Any `*free*` preset** with a different model id → first match (last resort).

### Guards

- Only rate-limit/overload statuses trigger fallback: `429`, `503`, `529`.
- 30s cooldown prevents flapping between models.
- No infinite chain — if already on the best free model and it 429s, notifies instead of cascading.
- Badge (`↩ fallback: <name>`) clears on manual `/xm <name>` or `/xm off`.

## Status line

When a fallback is active, the status line shows `↩ fallback: <preset>`. `retry-after` header is surfaced in the notification when the provider sends one.

## Vision pipeline

When an image appears (a `read` of `*.png`, an MCP screenshot, an attached image) and the
main model can't see images, xmodel routes it through a vision pipeline. The mode lives under
`_vision` in the config files and is controlled by **`/xm settings`** or **`/xm vision`**.

| Mode | Behaviour |
|---|---|
| `delegate` *(default)* | Compress recent context → one VLM sub-call → feed the text analysis back. The main model never switches and never blows its context window. |
| `switch` | Legacy: flip the main model to a vision-capable model for the turn, then restore it at turn end. |
| `off` | Do nothing — the image is left untouched (inline rendering if the terminal supports it). |

### Seeing the image while delegating (`keepImage`)

By default `delegate` *replaces* the image with the VLM's text analysis (so the TUI shows text
only). Set **`keepImage: true`** to keep the original image inline in the result **and** append
the analysis — i.e. you see the picture, the model still gets the text. Toggle it in `/xm settings`
(→ **Keep image**) or set `"keepImage": true` under `_vision`.

This is safe because pi-ai strips image parts for non-vision models at send time
(`downgradeUnsupportedImages`) — the main model never receives the image bytes, only the
analysis. So it costs you nothing on the model side; you just also get to look at the image.

### Two-tier config (global canonical + project override)

`_vision` is read from both files and merged at the **field** level (project wins per field):

- global: `~/.pi/agent/xmodel.json` → `_vision` (canonical default)
- project: `<cwd>/.pi/xmodel.json` → `_vision` (override; trusted projects only)

```jsonc
{
  "_vision": {
    "mode": "delegate",          // delegate | switch | off
    "vlm": "opencode/claude-sonnet-4-6",   // optional; auto-picks if unset
    "compressor": "zai/glm-5.2",           // optional; uses active model if unset
    "maxBriefChars": 1500,
    "keepImage": true            // delegate mode: also show the image inline (see above)
  }
}
```

`/xm settings` shows each setting with its **effective value + source** (`· project` / `· global` /
`· default`) and a **Write scope** row that picks which file edits go to — mirroring pi's own
`/config` two-tier editor. `/xm vision delegate project` writes just that field to the project
file. Changes take effect immediately and persist; no `/reload` needed.

> **Note:** `/xm off` clears the active *preset* and restores model defaults. It does **not**
> touch the vision mode. Use `/xm vision off` (or `/xm settings` → Vision mode → `off`) to
> disable vision.
