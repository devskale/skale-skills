# xmodel — model/thinking fast-switcher

Fast-switch model + thinking-level presets from inside a pi session, with optional
automatic fallback to a free variant when the active provider rate-limits (HTTP 429/503/529).

Lives at `~/.pi/agent/extensions/xmodel.ts` (symlinked into the skale-skills repo).

## Commands

| Command | What |
|---|---|
| `/xm <name>` | Switch to preset `<name>` (sets model + thinking level) |
| `/xm` | Picker — switch preset (or `(off)`) |
| `/xm settings` | **Vision hub** — pi-style settings list for the vision pipeline (mode, vlm, compressor, brief, thinking) with global/project scope |
| `/xm vision [mode] [global\|project]` | Show, or set, the vision mode (`delegate` \| `view` \| `switch` \| `human` \| `off`) |
| `/readimg <file>` | **Understand an image** — run the VLM on a file and return the analysis. No args = help; `/readimg settings` = vision hub. |
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

### Design goal — show images inline, keep them out of the context

**The user wants to *see* images inline, and does NOT want them to bloat the model context.**
This is the load-bearing design goal for all image handling in these extensions (xmodel,
image-slim, imagegen). Every routing decision should satisfy both halves:

- **Show inline** — the pixels render in the terminal for the user (Kitty/iTerm2/Ghostty/WezTerm/Warp
  via the pi-tui `Image` component), or via the `view`/`human` display paths.
- **Keep out of context** — the model never receives the raw base64 payload unless it genuinely
  needs the pixels to do the task. A single `read` of a photo is ~580KB of base64; a handful of
  attachments can push the context to 100s of KB. Every image in the model payload is a real cost.

Concretely, this means:

1. **Display-only is the default.** `read` on an image moves the pixels into a session display
   entry for the user; the model gets a short handover note, never the bytes. Zero tokens, zero VLM.
2. **Understanding is opt-in and delegated.** When the task genuinely needs image content, the
   agent calls `read` with `understand: true` (or `read_image` / `/readimg`). xmodel routes that
   to a **VLM sub-call** (compress → VLM → text) so the *main* model receives only a text analysis
   — never the image bytes. This is the `delegate` mode, and it exists precisely to keep the main
   model's context small while still answering the user's question.
3. **`blockImages` is the safety net.** pi's `images.blockImages` (settings.json) filters image
   blocks on normal requests; `image-slim` closes the compaction hole. Together they ensure images
   stay on screen but stop costing tokens at every layer. Turning `blockImages` off re-enables the
   native vision-capable-main-model path (pixels go straight to the model) — that is the ONE case
   where the bytes legitimately enter the context, and it is a deliberate trade-off, not the default.
4. **The main model's vision capability is not the trigger.** A vision-capable main model does NOT
   automatically mean pixels should flow to it. `modelSeesPixels()` also requires `blockImages` to
   be off. Under `blockImages: true` (the recommended default), even a vision-capable main model
   gets the VLM text analysis, so the context stays lean.

**Rule of thumb:** if the user can see the image inline, the model should only see text about it.
The image bytes belong in the display layer, not the model context.

### Two different conversions — label vs. pixels

There are **two separate conversions** in the pipeline, and they are NOT the same thing:

- **pi's `processImage()` (pi-Kern, `read.js`)** — normalizes the **MIME label**, not the pixels.
  `normalizeSupportedImageMimeType()` maps `image/jpg`→`image/jpeg` and leaves PNG/JPEG/WebP/GIF
  as-is; only unknown formats (BMP, AVIF) are converted to PNG. So `read` on a WebP yields a
  WebP, not a PNG.
- **our `toDisplayPng()` (xmodel, `lib/image-utils.ts`)** — converts the **pixels** to PNG, and
  only at the **display/render** stage (the Kitty/iTerm2-Graphics APC). PNG stays byte-identical;
  non-PNG (WebP/JPEG/GIF/BMP) is transcoded via `sips` to PNG **and resized to 1200px** (so the
  APC payload is ~5× smaller).

This matters because pi's `encodeKitty()` hardcodes `f=100` (PNG) and ignores `mimeType` — so a
WebP sent as a PNG APC is silently discarded by the terminal. `toDisplayPng()` fixes that by
making the bytes actually PNG *before* the APC. See the `inline-image-not-rendering` issue for
full root-cause.

### Display vs. understand (`read` vs. `read_image` / `/readimg`)

`read` on an image routes through a three-way matrix (v0.5.1):

- **Default (kein Verständnis gefordert)** = **anzeigen im Terminal** — the pixels move into a
  session display entry rendered inline for **you** (Kitty/iTerm2/Ghostty/WezTerm/Warp via the
  pi-tui `Image` component); the model — even a vision-capable one — gets only a short handover
  note, never the pixels. Zero tokens, zero VLM. In vision mode `view`, `read` routes to throway +
  browser instead (shared display).
- **Verstehen gefordert + Hauptmodell IST ein img-Modell** — pixels pass straight through to the
  model (native understanding, no detour). Trigger: `read` with `understand: true`.
- **Verstehen gefordert + Hauptmodell ist KEIN img-Modell** — **handover an ein img-Modell**:
  you still see the image inline, the model receives a VLM text analysis instead of pixels
  (the delegate pipeline: compress → VLM → text).

The agent decides "verstehen gefordert" from task context and re-calls `read` with
`understand: true` (brief built by the compressor sub-call) or `understand: '<what to
examine>'` — the focus string goes straight to the vision model, skipping the compressor
(fastest path). A protocol note in the system prompt teaches this; the handover note in
every display-only result points there too. `read_image` / `/readimg` remain the explicit
fallbacks — also for strict providers that strip extra `read` parameters — and `read_image`
accepts `url` (downloads to ~/.cache/webimg/ automatically), plus `thinking` + `focus`
params for deep, targeted analysis.

`generate_image` and `viewimg` (CLI, **deprecated** — use `read img.jpg` instead) stay on the
display axis; generated images still feed vision-capable models (they iterate on what they drew).
Only analysis-oriented tools (screenshots, MCP captures) still auto-delegate.

| Mode | Behaviour |
|---|---|
| `delegate` *(default)* | Compress recent context → one VLM sub-call → feed the text analysis back. The main model never switches and never blows its context window. |
| `view` | **SHARED display** — upload the image to throway + open it in a real browser, give the URL. No VLM, zero tokens. `read` images route here in this mode (all models); other analysis tools, non-vision models only. |
| `switch` | Legacy: flip the main model to a vision-capable model for the turn, then restore it at turn end. |
| `human` | Ask **you** to describe the image. Shows the image in a TUI overlay with a 30s countdown (resets on keypress) and feeds your description back as the analysis. Always keeps the image inline. |
| `off` | Do nothing for analysis tools — the image is left untouched. `read` still hands over display-only. |

### Seeing the image while delegating (`keepImage`)

By default `delegate` moves the pixels into a **session display entry** (`xmodel-view`) — you see
the image inline in the chat, the model never carries the bytes (display entries render from
`details` and never steer the LLM; image-slim keeps them out of compaction too). The tool result
keeps only the VLM's text analysis.

**`keepImage: true`** additionally keeps the original image block inline in the *tool result*
(legacy display path) — under `images.blockImages` it is stripped at send time, so the model still
only ever sees the analysis. Toggle it in `/xm settings` (→ **Keep image**) or set
`"keepImage": true` under `_vision`.

Either way the model side is identical: analysis text only. `keepImage` only decides whether the
image rides in the tool result (session file grows) or in the display entry.

### Two-tier config (global canonical + project override)

`_vision` is read from both files and merged at the **field** level (project wins per field):

- global: `~/.pi/agent/xmodel.json` → `_vision` (canonical default)
- project: `<cwd>/.pi/xmodel.json` → `_vision` (override; trusted projects only)

```jsonc
{
  "_vision": {
    "mode": "delegate",          // delegate | view | switch | human | off
    "vlm": "opencode/claude-sonnet-4-6",   // optional; auto-picks if unset
    "compressor": "zai/glm-5.2",           // optional; uses active model if unset
    "maxBriefChars": 1500,
    "keepImage": true,            // delegate mode: also keep the image in the tool result (legacy; default = display entry)
    "thinkingLevel": "off"       // vision sub-call + compressor thinking (off..xhigh). default = the child model's own default; "off" = fastest. Per-call override: read_image thinking param
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
