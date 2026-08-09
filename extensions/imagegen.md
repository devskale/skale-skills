# Image Generation Extension

Pi extension with two entry points, both backed by one shared core (`generateAndSave`):

- **`generate_image` tool** — the LLM calls it autonomously when you ask for an
  image. Returns an **image content block** (not just a path), so the model sees
  its own output and can **iterate** on it — regenerate with a refined prompt,
  adjust style, try variants.
- **`/imagegen` command** (alias `/img`) — direct, no-LLM generation:
  ```
  /imagegen a red cube on white --model tu@z-image-turbo --size 512x512
  /img a fox logo, flat vector            # alias; default model pollinations@dreamshaper
  ```
  Flags: `--model`/`-m`, `--size`/`-s`, `--n`/`-n`, `--seed`. Generates
  immediately, saves to `./generated/`, and renders the image **inline** in the
  chat via a registered message renderer (`pi.registerMessageRenderer`). Zero
  model tokens — the agent loop is bypassed.

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

Any image-capable model the **uniinfer proxy** catalog offers can be used —
the extension has no backend branching and no hardcoded provider list. It
reaches every backend through one uniform call:

```http
POST https://uniinfer.skale.dev/v1/images/generations
Authorization: Bearer <provider key>   (optional for keyless providers)
Content-Type: application/json

{ "model": "provider@modelid", "prompt": "...", "size": "WxH", "n": 1 }
```

### The `provider@modelid` convention

The proxy splits the `model` field on `@`:

- first segment → **provider** (selects backend + which credgoo key to fetch)
- remainder → **model id** (passed through verbatim to the backend)

```
pollinations@dreamshaper →  GET  gen.pollinations.ai/image/<prompt>?model=dreamshaper&...
tu@z-image-turbo        →  POST aqueduct.ai.datalab.tuwien.ac.at/v1/images/generations
openai@gpt-image-1       →  POST <openai>/images/generations
```

This is the entire routing contract — the extension just forwards `model`
unchanged. The proxy enforces which providers actually support image
generation; the extension discovers the full catalog and lets the proxy decide.

### Model discovery (OpenAI-compatible catalog)

```
GET https://uniinfer.skale.dev/v1/models   (no auth)
```

Returns the full OpenAI-compatible model list for **all** providers. The
extension filters to image-capable entries (explicit `type: "image"`, or an
`image` in `modalities.output`) and caches the result for 1h. This is how it
knows which `provider@modelid` values are available without any hardcoding.

---

## Credentials

Key resolution is generic and per-provider, in order: env var
(`<PROVIDER>_API_KEY`, e.g. `POLLINATIONS_API_KEY`) → `credgoo <service>` (the
provider name, or an override like `tu`/`pollinations`) → `~/.pi/agent/auth.json`.

Keyless providers (e.g. `pollinations`, `ollama`) work with **no Bearer at all**
— the extension only sends `Authorization` when a key resolves. Providers that
need a key and have none will surface the proxy's error, which names the
missing credential.

---

## Tool design (proposed)

```ts
pi.registerTool({
  name: "generate_image",
  parameters: Type.Object({
    prompt: Type.String(),
    model:  Type.Optional(Type.String()),  // "pollinations@dreamshaper" (default)
    size:   Type.Optional(Type.String()),  // "512x512" (default)
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

The generation **prompt is embedded into the file metadata** so it travels
with the image (no external DB): PNG `tEXt` chunks (`prompt` + `parameters`),
JPEG `COM` comment, or a sidecar `<file>.txt` for formats we can't edit
in-place (WebP/GIF/BMP). Read it back with:

```bash
exiftool -parameters <png>      # PNG tEXt
exiftool -Comment <jpg>         # JPEG COM
cat <file>.txt                 # sidecar (WebP/GIF/BMP)
```

### Defaults

| Param | Default | Reason |
|---|---|---|
| `model` | `pollinations@dreamshaper` | ~0.0001 pollen → cheapest iteration (flux is 0.0020) |
| `size` | `512x512` | compact, broadly supported (512–640px range keeps files small) |
| output dir | `~/.generated/` (or `./uploads/` if present in cwd for πui web URLs; `./generated/` elsewhere) | a single predictable home for generated images; override with `IMAGEGEN_OUTPUT_DIR` |

### Iteration model (v1)

**Prompt-only.** The model reads the image, rewrites the prompt, calls
`generate_image` again. Works with all current backends (text-to-image).

**Image-to-image** (edit/variation with a reference image — Pollinations
`kontext`, TU edit endpoints) is a later addition: an optional `input_image`
param (path or base64) routed to the edit endpoint. Out of scope for v1.

See [Image display & ASCII fallback](#image-display--ascii-fallback) below for
what happens when the model or terminal can't show the image.

### Self-healing default model (no hardcoded models/costs)

Nothing about models or prices is hardcoded. The extension discovers and learns
dynamically, persisting state to `~/.pi/agent/imagegen-state.json`:

- **Live model list** — fetched from the OpenAI-compatible `GET /models`
  catalog (cached 1h), filtered to image-capable models, so new/removed
  providers and models are picked up automatically.
- **Last-good model** — whichever model last generated successfully for a
  provider is remembered and used as the next default, so the default follows
  what actually works.
- **Learned costs** — per-model pollen cost is parsed from 402 responses
  (`"costs ~0.0020 pollen"`) and persisted. Fallback ordering is cheapest-first
  by learned cost, with unknown-cost models probed last.

On a **402 insufficient balance** (or any model failure), the extension falls
back through cheaper models automatically instead of failing hard — and the
winning model becomes the new remembered default, so the next call self-heals.
The static `DEFAULT_MODEL` (`pollinations@dreamshaper`) is only the initial
seed; it's overridden by learned state after the first success. Non-402 failures
of the requested model are surfaced as-is, not masked.

---

## Image display & ASCII fallback

There are **two independent capabilities**, both of which can be missing.
The extension degrades gracefully through each.

| Capability | Means | Controlled by |
|---|---|---|
| **Terminal display** | the *user* can see the image inline | terminal image protocol (Kitty/iTerm2) surviving the multiplexer |
| **Model vision** | the *LLM* can see the image to iterate | the provider accepting image input blocks |

### herdr: enable `experimental.kitty_graphics`

The dev stack is `ghostty → herdr → pi`. herdr has a full Kitty-graphics
**relay** (it re-encodes pane image placements for the outer terminal), but
it's gated behind an experimental flag that is **off by default**:

```toml
# ~/.config/herdr/config.toml
[experimental]
kitty_graphics = true
```

- **Flag on** → herdr relays the Kitty sequences pi emits → **images render
  inline**. (`TERM_PROGRAM=ghostty` leaks through herdr, so pi's
  `detectCapabilities()` already returns `images: "kitty"` and emits Kitty;
  herdr just has to forward it.)
- **Flag off (default)** → herdr drops those sequences → nothing renders, and
  you see only the chafa fallback below.

**tmux/screen** are different: there pi itself returns `images: null` (it
disables Kitty under tmux), so the chafa fallback always applies there.

### The fallback: ASCII/ANSI via chafa (tmux/screen only)

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

The extension detects the mux itself (it must not trust pi's
`getCapabilities()`, which has no mux detection):

```ts
function canRenderInline(): boolean {
  // tmux/screen: pi disables Kitty here (images: null). herdr is NOT special-cased —
  // it renders Kitty when the user enables experimental.kitty_graphics (off by
  // default); when off, the model-signal branch in execute() still adds ASCII.
  if (process.env.TMUX || process.env.SCREEN) return false;
  return true;
}
```

ASCII is added to the tool-result **content** (in `execute()`) when **either**
of two independent conditions holds — pi renders image blocks separately from
this text, so the two don't collide:

- **display fallback** — `!canRenderInline()` (tmux/screen): the terminal can't
  show pixels, so the user gets ANSI art instead.
- **model signal** — the active model can't see images (`!isVisionCapable`):
  pi-ai strips the image block for a non-vision model, so ASCII is the only
  visual it gets to iterate on. This fires even when pixels *do* render
  (e.g. herdr with the flag on) — redundant for the user, essential for the model.

chafa is invoked **async** via `execFile` (no shell; args as an array), so a
slow render never blocks the event loop.

`chafa` flags:
- `--format symbols` is **mandatory** — without it chafa auto-detects the
  Kitty protocol (because `TERM_PROGRAM=ghostty` is set) and emits graphics
  escapes, which the mux then strips. Forcing `symbols` keeps output as text.
- `--symbols block-half` + `--colors 256` → compact ANSI color preview.
- `--symbols ascii -c none` → pure monochrome ASCII (max compatibility).

### ASCII as a model signal (double duty)

The **model signal** is the more important of the two reasons: a text-only
LLM (the `read` tool will have reported "Current model does not support
images") gets a coarse visual signal instead of nothing — returning only an
image block would give it nothing to iterate on, since pi-ai strips image
parts for non-vision models. This fires regardless of the terminal, including
under herdr with the flag on (where the user *also* sees the real pixels).

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
curl -s -X POST https://uniinfer.skale.dev/v1/images/generations \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $(credgoo pollinations)" \
  -d '{"model":"pollinations@dreamshaper","prompt":"a tiny red cube on white, centered","size":"512x512"}'

# TU — high quality
curl -s -X POST https://uniinfer.skale.dev/v1/images/generations \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $(credgoo tu)" \
  -d '{"model":"tu@z-image-turbo","prompt":"a tiny red cube on white, centered","size":"512x512"}'
```

---

## Open questions

1. **Proxy URL** — default is `https://uniinfer.skale.dev/v1`; override with the
   `UNIINFER_PROXY_URL` env var to point at your own uniinfer instance.
2. **Preview format** — default to 256-color half-blocks (nicer) or pure ASCII
   (max compatibility, also safe as a model signal)? Proposal: half-blocks for
   display, ASCII for the model-signal text block.
3. **`/imagegen` command** — **done.** `/imagegen` (alias `/img`) is implemented
   as a direct, no-LLM command: parses flags, calls the shared `generateAndSave`
   core, and renders the result inline via `pi.registerMessageRenderer`.
4. **pi upstream** — pi's `detectCapabilities()` has no herdr awareness:
   under `ghostty→herdr` it returns `images: "kitty"` whether or not herdr's
   `experimental.kitty_graphics` is on. With the flag off that's a false
   positive (pi emits Kitty sequences herdr drops). Not actionable for this
   extension — the flag is the user's lever.
