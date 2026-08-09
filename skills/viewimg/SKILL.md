---
name: viewimg
description: Display an image in the terminal (view-only, no VLM). Renders the image as colorful block art with chafa, or opens it in a native window with `open` on macOS. Use when you or the agent want to SHOW an image to the user without analyzing it.
version: 0.1.0
---

# viewimg — show an image (view-only)

Display an image in the terminal. **View-only — never analyzes, never fires the VLM.**
Understanding is a separate, explicit step (`read_image` / `/readimg`).

## Usage

```bash
viewimg <image-file> [--size WxH] [--open]
```

| Flag | Meaning |
|------|---------|
| `--size WxH` | chafa block size (default `60x30`) |
| `--open` | open in a native window instead of in-terminal (uses `open` on macOS) |
| `--no-color` | plain ASCII fallback (no ANSI color) |
| `--help` | usage |

## Behavior

- **Default:** renders the image as ANSI block art directly in the terminal via `chafa`.
- **`--open`:** opens the image in a native window (`open` on macOS) — crisp, real image.
- **Fallback:** if `chafa` is missing and no `--open`, falls back to `open` (macOS) / prints a hint.

## Why view-only?

`read` and `viewimg` only **display**. Understanding is opt-in: use `read_image` (tool)
or `/readimg` (command) when you actually need the image's contents. This keeps display
instant and never spends tokens on an unrequested VLM call.

## Install

```bash
bash install.sh   # creates ~/.local/bin/viewimg (Linux/macOS)
install.bat       # Windows
```

Requires `chafa` (brew install chafa) for in-terminal rendering; `open` is built into macOS.
