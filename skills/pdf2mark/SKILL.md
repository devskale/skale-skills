---
name: pdf2mark
version: "1.7.0"
description: Bash skill — run `pdf2mark <file.pdf>` in your shell (not an MCP tool). Convert PDFs to clean Markdown — local extraction, cloud-OCR fallback for scans. Use when the user wants a PDF as Markdown.
disable-model-invocation: true
---

# Skill: pdf2mark

```bash
pdf2mark document.pdf          # That's it.
```

Converts PDFs to Markdown. The default auto-selects the converter: **pdfplumber** (local, free) first; for scans (no text layer) it **falls back to llamaparse** (cloud OCR — the document is uploaded to LlamaCloud, US). Token comes from `credgoo FETCH_URL_BEARER` (same credential as the fetch-url `api` tool).

**Default output:** `md/<name>.pdf.md` next to the PDF — `pdf2mark abd.pdf` writes `./md/abd.pdf.md` (the `md/` dir is created).

## Keep it simple

| ✗ Don't | ✓ Do |
|---------|------|
| `pdf2mark doc.pdf --out doc.md -v 2>&1` | `pdf2mark doc.pdf` |
| `pdf2mark scan.pdf --method llamaparse --tier fast --language de -v` | `pdf2mark scan.pdf` |

## Usage

```bash
pdf2mark document.pdf            # → ./md/document.pdf.md (default: file next to the PDF)
pdf2mark scan.pdf --method llamaparse    # force cloud OCR (scans, tables, multi-column)
pdf2mark doc.pdf --out doc.md            # explicit output file
pdf2mark doc.pdf --stdout                # markdown to stdout instead of a file
pdf2mark doc.pdf --force                 # bypass cache — re-upload and re-convert
```

## Cache (instant second read)

Big PDFs (100 pages ≈ minutes server-side) are cached by content hash in
`~/.cache/pdf2mark/` — the **second** `pdf2mark doc.pdf` returns in
milliseconds with identical output. Async job ids are kept too: a re-run
**while a job is still running** (or <2h after it finished) re-attaches to it
instead of re-uploading. `--force` bypasses both; `PDF2MD_CACHE` overrides
the directory. Follow-up questions about the same PDF never re-convert.

**Lange OCR-Jobs warten jetzt durch:** sobald der Job seine Seitenzahl meldet,
hebt pdf2mark das Poll-Budget auf pages×10 s + 120 s an (real gemessen:
2.7–9 s/Seite) und zeigt eine grobe ETA — ein 222-Seiten-Scan stirbt nicht
mehr an der statischen 600s-Grenze. Sollte das Budget dennoch reißen:
**einfach denselben Befehl erneut laufen lassen** — er re-attacht an den
laufenden Job.

Full options (llamaparse tiers, OCR language, timeout), size limits, error codes, credentials and the raw endpoint: **[references/api.md](references/api.md)**.

## Install

Ships in the **skale-skills** pi package. For a global `pdf2mark` shell command, run the installer from **this skill's own directory**:

```bash
./install.sh        # → creates ~/.local/bin/pdf2mark (uv auto-installed)
```

**Other agents (zcode, etc.):** symlink this directory into the agent's skills dir — it reads the same `SKILL.md`:

```bash
ln -s "$(pwd)" ~/.zcode/skills/pdf2mark   # agent-neutral: any skills dir works
```

## Update

```bash
pdf2mark --update       # git pull + uv sync
pdf2mark --selfcheck    # version + last update
```

Auto-updates in background every 7 days.
