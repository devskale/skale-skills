# Image Generation Extension

Pi extension that registers a `generate_image` tool the LLM can call. The
generated image is returned as an **image content block** (not just a path),
so the model sees its own output and can **iterate** on it — regenerate with
a refined prompt, adjust style, try variants.

> Status: design doc. The extension itself (`extensions/imagegen.ts`) is not
> implemented yet.

---

## Why an extension (not a skill)

Image generation is one of the few cases where the extension model wins:

- **Model reads the result** — the tool returns
  `{ type: "image", source: { type: "base64", mediaType: ..., data: ... } }`,
  so the image enters the conversation. The model can critique it ("lighting
  is too cold") and call the tool again. A skill only returns a path string;
  the pixels never reach the model.
- **No CLI reuse needed** — unlike `fetch-url` or the reference
  `generate-image` skill, this is purely an in-agent capability. No need for
  it to run from an arbitrary shell.

When iteration is *not* wanted and shell reuse *is*, the existing
`generate-image` Node skill (aiui) remains the right tool.

---

## Backends

Two image backends, both reached through the **uniinfer proxy** so the
extension has a single, uniform call. No backend branching in the extension.

| | Pollinations | TU |
|---|---|---|
| `model:` | `pollinations@flux` (and `kontext`, `nanobanana`, `seedream`, `ideogram-v4`, …) | `tu@z-image-turbo` |
| Auth | `Bearer $(credgoo pollinations)` | `Bearer $(credgoo tu)` |
| Latency | ~1.8 s | ~28 s |
| Typical output | JPEG 512×512 (~11 KB) | PNG 1024×1024 (~917 KB) |
| Best for | **Fast iteration** (default) | Final high-quality render |

### The `provider@modelid` convention

The proxy splits the `model` field on `@`:

- first segment → **provider** (selects backend + which credgoo key to fetch)
- remainder → **model id** (passed through verbatim to the backend)

```
pollinations@flux    →  GET  gen.pollinations.ai/image/<prompt>?model=flux&...
tu@z-image-turbo     →  POST aqueduct.ai.datalab.tuwien.ac.at/v1/images/generations
```

This is the entire routing contract — defined in the proxy's
`proxy_routers/media.py` via `parse_provider_model(..., allowed_providers=\
["pollinations","tu"])`. The extension just forwards `model` unchanged.

---

## Unified API contract

Both backends look identical at the edges:

```http
POST https://amd1.mooo.com:8123/v1/images/generations
Authorization: Bearer <credgoo key for the provider>
Content-Type: application/json

{ "model": "provider@modelid", "prompt": "...", "size": "WxH", "n": 1 }
```

```json
{
  "created": 1719264000,
  "model": "pollinations@flux",
  "data": [{ "b64_json": "<base64>", "url": "https://gen.pollinations.ai/..." }]
}
```

- `b64_json` is **always present** (proxy fetches the URL for backends that
  only return URLs and base64-encodes it). This is what the extension returns
  to the model and writes to disk.
- `url` is present for Pollinations, absent for TU. Optional — don't rely on it.

### Model discovery

```
GET https://amd1.mooo.com:8123/v1/image/models/pollinations   (no auth)
GET https://amd1.mooo.com:8123/v1/image/models/tu              (needs bearer)
```

Returns `{ object: "list", data: [{ id, object: "model", owned_by: "skaledev" }] }`.
Filter server-side: Pollinations models are the ones with `image` in
`output_modalities`. Hardcoded fallback (from `media.py`):
`flux, kontext, gptimage, gptimage-large, zimage, klein`.

---

## Credentials

Both backends require a key. Resolution per provider:

| Provider | Resolution order |
|---|---|
| `pollinations` | `POLLINATIONS_API_KEY` env → `credgoo pollinations` |
| `tu` | `TU_API_KEY` env → `credgoo tu` → `~/.pi/agent/auth.json` (`tu-aqueduct`) |

The proxy accepts a **direct provider key** as the Bearer (no `@encryption`
suffix needed). So `credgoo <provider>` output is passed straight through as
`Authorization: Bearer <key>`. If no key resolves, fail hard with a message
naming both options (`credgoo <provider>` or the relevant env var).

---

## Tool design (proposed)

```ts
pi.registerTool({
  name: "generate_image",
  parameters: Type.Object({
    prompt: Type.String(),
    model:  Type.Optional(Type.String()),  // "pollinations@flux" (default)
    size:   Type.Optional(Type.String()),  // "1024x1024" (default)
    n:      Type.Optional(Type.Number()),  // 1–4
    seed:   Type.Optional(Type.Number()),
  }),
  async execute(toolCallId, params, signal, onUpdate, ctx) { ... },
});
```

### Return shape (the whole point)

```ts
return {
  content: [
    { type: "text", text: `Saved ${n} image(s) to ${paths.join(", ")}` },
    { type: "image", source: { type: "base64", mediaType, data: b64 } },
    // (one image block per generated image)
  ],
  details: { provider, model, size, paths },
};
```

The image block lets the model **see** the result and iterate. The saved
path lets the user (and πui, via `uploads/`) reuse the file.

### Defaults

| Param | Default | Reason |
|---|---|---|
| `model` | `pollinations@flux` | ~1.8 s latency → cheap iteration |
| `size` | `1024x1024` | square, broadly supported |
| output dir | `./generated/` (or `./uploads/` if present, for πui web URLs) | matches the `generate-image` skill convention |

### Iteration model (v1)

**Prompt-only.** The model reads the image, rewrites the prompt, calls
`generate_image` again. Works with all current backends (text-to-image).

**Image-to-image** (edit/variation with a reference image — Pollinations
`kontext`, TU edit endpoints) is a later addition: an optional `input_image`
param (path or base64) routed to the edit endpoint. Out of scope for v1.

See [Image display & ASCII fallback](#image-display--ascii-fallback) below for
what happens when the model or terminal can't show the image.

---

## Image display & ASCII fallback

There are **two independent capabilities**, both of which can be missing.
The extension degrades gracefully through each.

| Capability | Means | Controlled by |
|---|---|---|
| **Terminal display** | the *user* can see the image inline | terminal image protocol (Kitty/iTerm2) surviving the multiplexer |
| **Model vision** | the *LLM* can see the image to iterate | the provider accepting image input blocks |

### Why inline display is broken under herdr

The dev stack is `ghostty → herdr → pi`. herdr is a terminal
multiplexer (like tmux). pi's `detectCapabilities()`
(`packages/tui/src/terminal-image.ts`) decides image support like this:

- tmux / screen → `images: null` (explicitly disabled — protocols unreliable)
- `TERM_PROGRAM=ghostty` → `images: "kitty"`

The problem: **`TERM_PROGRAM=ghostty` leaks through herdr** into pi's env, so
pi returns a **false positive** (`images: "kitty"`). pi then emits Kitty
graphics escape sequences, but herdr strips/mangles them the same way tmux
does — so **nothing renders**. pi has no herdr detection (only tmux/screen).

When `images: null`, pi falls back to a bare text placeholder
`[Image: foo.png [image/png] 1024x1024]` — no visual at all.

### The fix: ASCII/ANSI via chafa

[`chafa`](https://hpjansson.org/chafa/) is installed (`/opt/homebrew/bin/chafa`)
and renders an image to **plain text** — survives any multiplexer because it's
just characters and ANSI color, not a graphics protocol. Proven on the test
image (a red cube on white):

```
   _ _y$w= '=a_yy____ _____yygg
_g==~~        "~=@@@@@@@@@@@@@
yg@@@l              1@@@@@@@@@@@@
   ...
```

The extension must **not** trust pi's `getCapabilities()` (false positive
under herdr). It does its own detection:

```ts
function canRenderInline(): boolean {
  // Multiplexers strip Kitty/iTerm graphics protocols, even when
  // TERM_PROGRAM (ghostty/kitty) leaks through from the outer terminal.
  const mux = process.env.TMUX || process.env.SCREEN
    || process.env.HERDR_PANE_ID;          // herdr is a multiplexer too
  if (mux) return false;
  return true; // let pi's own detection (getCapabilities) decide the rest
}
```

Render strategy in `renderResult`:

- `canRenderInline()` true → emit Kitty/iTerm sequence (pi renders the pixel image)
- false → `execFileSync("chafa", ["--format","symbols","--symbols","block-half",
  "--color-space","rgb","--colors","256","--size",`${w}x${h}`, imgPath])` →
  emit the returned ANSI/ASCII as visible text

`chafa` flags:
- `--format symbols` is **mandatory** — without it chafa auto-detects the
  Kitty protocol (because `TERM_PROGRAM=ghostty` is set) and emits graphics
  escapes, which herdr then strips. Forcing `symbols` keeps output as text.
- `--symbols block-half` + `--colors 256` → compact ANSI color preview.
- `--symbols ascii -c none` → pure monochrome ASCII (max compatibility).

### ASCII as a model signal (double duty)

The same ASCII rendering fixes the **second** problem: when the active LLM
lacks vision (e.g. the `read` tool reported "Current model does not support
images"), returning only an image block gives the model nothing to iterate on.

So the tool result adapts to what the model can consume:

```ts
return {
  content: [
    { type: "text", text: `Saved to ${path}` },
    { type: "image", source: { type: "base64", mediaType, data: b64 } },
    // ALSO include ASCII when inline pixels won't reach the model/user:
    { type: "text", text: "\n" + chafaAscii },
  ],
};
```

A vision-capable model uses the image block; a text-only model still gets the
ASCII as a coarse visual signal to critique and refine against. One rendering,
two audiences.

### Preview size

ASCII previews are downscaled — `--size 64x24` is enough to convey
composition/color without flooding the transcript. The full-resolution file is
always saved to disk regardless.

---

## Reference: proven curl

Both verified working against the proxy:

```bash
# Pollinations — fast
curl -s -X POST https://amd1.mooo.com:8123/v1/images/generations \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $(credgoo pollinations)" \
  -d '{"model":"pollinations@flux","prompt":"a tiny red cube on white, centered","size":"512x512"}'

# TU — high quality
curl -s -X POST https://amd1.mooo.com:8123/v1/images/generations \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $(credgoo tu)" \
  -d '{"model":"tu@z-image-turbo","prompt":"a tiny red cube on white, centered","size":"1024x1024"}'
```

---

## Open questions

1. **Proxy URL** — `https://amd1.mooo.com:8123/v1` is hardcoded above. Should
   it be configurable (env / settings) so non-skale users can point at their
   own uniinfer instance?
2. **Preview format** — default to 256-color half-blocks (nicer) or pure ASCII
   (max compatibility, also safe as a model signal)? Proposal: half-blocks for
   display, ASCII for the model-signal text block.
3. **`/img` command** — interactive prompt → generate, as a shortcut? Optional.
4. **pi upstream** — herdr should arguably be added to pi's
   `detectCapabilities()` disable-list (like tmux/screen), so *all* image
   rendering across pi degrades correctly under herdr. Worth a PR separately
   from this extension.
