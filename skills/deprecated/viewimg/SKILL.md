---
name: viewimg
description: DEPRECATED — use `read img.jpg` or `read_image` instead. Display an image in the terminal (view-only, no VLM). Renders the image as colorful block art with chafa, or opens it in a native window with `open` on macOS.
version: 0.1.0
---

# viewimg — **DEPRECATED** — use `read img.jpg` instead

> **⚠️ DEPRECATED:** This skill is superseded by `read img.jpg` (native pi image display) + `read_image`/`/readimg` (VLM analysis). See [docs/image-display-deprecation.md](../../../docs/image-display-deprecation.md) for the full migration guide.
>
> `viewimg` will be removed in a future release. No further development.

Display an image in the terminal. **View-only — never analyzes, never fires the VLM.**
Understanding is a separate, explicit step (`read_image` / `/readimg`).

## Migration

| Old | New |
|-----|-----|
| `viewimg img.jpg` | `read img.jpg` |
| `viewimg img.jpg --open` | `open -a Preview img.jpg` (macOS) |
| `viewimg img.jpg --size 40x20` | `read img.jpg` (auto-sizes) |
| `viewimg img1.jpg img2.jpg --open` | `open -a Preview img1.jpg img2.jpg` (macOS) |

See [migration guide](../../../docs/image-display-deprecation.md) for details.

## Usage

```bash
viewimg <image-file>... [--size WxH] [--open] [--no-color] [--help]
```

| Flag | Meaning |
|------|---------|
| `--size WxH` | chafa block size (default `60x30`) |
| `--open` | open **all** images together in **one** native window (uses `open -a Preview` on macOS) |
| `--no-color` | plain ASCII fallback (no ANSI color) |
| `--update` | pull the latest skill via git |
| `--selfcheck` | version, install dir, last update, chafa availability |
| `--help` | usage |

## Behavior

- **Default:** renders each image as ANSI block art directly in the terminal via `chafa`.
- **`--open`:** opens **all** images in **one** Preview window (tabs) via `open -a Preview` —
  no multiple windows, even across repeated calls (Preview reuses its window).

## Why view-only?

`read img.jpg` only **displays**. Understanding is opt-in: use `read_image` (tool)
or `/readimg` (command) when you actually need the image's contents. This keeps display
instant and never spends tokens on an unrequested VLM call.

> `viewimg` was the original CLI for display-only image viewing. `read img.jpg` is now the
> canonical path — pixel-perfect TUI rendering, no chafa dependency, zero-token VLM handoff.
> See [docs/image-display-deprecation.md](../../../docs/image-display-deprecation.md).

## Install

```bash
bash install.sh   # creates ~/.local/bin/viewimg (Linux/macOS)
install.bat       # Windows
```

Requires `chafa` (brew install chafa) for in-terminal rendering; `open` is built into macOS.

> **No-op install:** since `read img.jpg` replaces this skill, running `install.sh` is
> optional. Only needed if you want the legacy `viewimg` shell command for backward compat.
