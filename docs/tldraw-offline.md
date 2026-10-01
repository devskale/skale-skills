# tldraw Desktop as an agent-driven canvas — idea



Status: **idea** — decided direction, deliberately not implemented. Nothing in this repo
depends on it. Listed in [ideas.md](ideas.md).

## Idea

Use the tldraw Desktop app (offline canvas) as a drawing surface an agent can drive
programmatically: open `.tldraw` / `.tldr` files, inspect and edit shapes, capture
screenshots, run JavaScript against the live editor, and add durable behavior
(clickable UI, animations, custom shapes) via `script/`.

The draw: sketches and diagrams stop being *generated* artifacts and become *editable
state*. An agent drops a rough board, the human rearranges it, hands it back — the agent
reads the shapes rather than re-deriving the layout from scratch. This is the editable-
source-of-truth property that `visualize` (one-shot HTML) deliberately does not have.

## What already exists

- **Skill:** `tldraw-offline`, bundled with the tldraw Desktop app itself
  (marker `<!-- installed-by:tldraw-desktop-agent-skills -->`).
- **Helper:** `tq` at `~/skills/tldraw-offline/tq`, which reads port + bearer token
  from `server.json`.
- **Server:** local HTTP on `http://localhost:7236`; port and token come from
  `~/Library/Application Support/tldraw (Nightly)/server.json`. The app must be running.

## Auto-install caveat

The app installs its skill into every agent directory it detects — `~/skills/`,
`~/.pi/agent/skills/`, `~/.cursor/skills/`, `~/.codex/skills/`, `~/.gemini/skills/`.

For Pi, a `disable-model-invocation` edit in the Pi copy may be overwritten on app
update. To keep the skill out of context while leaving the other agents' copies alone,
remove the Pi copy rather than editing it.

## Why it is only an idea here

Driving a third-party desktop app's local HTTP server from a shared skill package means
depending on an app that is not part of this repo's install path, on a specific
nightly build (`tldraw (Nightly)`), and on a port + bearer-token contract that can
change without notice. That is a much weaker foundation than the skills shipped here,
which are self-contained scripts with their own test suites.

Worth revisiting if someone actually wants a canvas skill: the adapter would be small,
and the interesting part — shape-level editing — is exactly what `visualize`'s output
cannot offer.
