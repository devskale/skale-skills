---
name: pdf2md
version: "1.4.3"
description: Bash skill — run `pdf2md <file.pdf>` in your shell (not an MCP tool). Convert PDFs to clean Markdown — local extraction, cloud-OCR fallback for scans. Use when the user wants a PDF as Markdown.
disable-model-invocation: true
---

# Skill: pdf2md

```bash
pdf2md document.pdf          # That's it.
```

Converts PDFs to Markdown. The default auto-selects the converter: **pdfplumber** (local, free) first; for scans (no text layer) it **falls back to llamaparse** (cloud OCR — the document is uploaded to LlamaCloud, US). Token comes from `credgoo FETCH_URL_BEARER` (same credential as the fetch-url `api` tool).

## Keep it simple

| ✗ Don't | ✓ Do |
|---------|------|
| `pdf2md scan.pdf --method llamaparse --tier fast --language de -v` | `pdf2md scan.pdf` |
| `pdf2md doc.pdf --method pdfplumber --out doc.md -v 2>&1` | `pdf2md doc.pdf --out doc.md` |

## Usage

```bash
pdf2md document.pdf                    # auto: pdfplumber, llamaparse fallback
pdf2md scan.pdf --method llamaparse    # force cloud OCR (scans, tables, multi-column)
pdf2md doc.pdf --out doc.md            # write file (stats to stderr) instead of stdout
```

Full options (llamaparse tiers, OCR language, timeout), size limits, error codes, credentials and the raw endpoint: **[references/api.md](references/api.md)**.

## Install

Ships in the **skale-skills** pi package. For a global `pdf2md` shell command, run the installer from **this skill's own directory**:

```bash
./install.sh        # → creates ~/.local/bin/pdf2md (uv auto-installed)
```

**Other agents (zcode, etc.):** symlink this directory into the agent's skills dir — it reads the same `SKILL.md`:

```bash
ln -s "$(pwd)" ~/.zcode/skills/pdf2md   # agent-neutral: any skills dir works
```

## Update

```bash
pdf2md --update       # git pull + uv sync
pdf2md --selfcheck    # version + last update
```

Auto-updates in background every 7 days.
