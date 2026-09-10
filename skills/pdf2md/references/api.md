# pdf2md API Reference

Loaded on demand — SKILL.md keeps only the 90% path.

## Options

| Option | Description |
|--------|-------------|
| `--method` | `auto` (default), `pdfplumber` (local, text-layer PDFs), `llamaparse` (cloud OCR — **the document is uploaded to LlamaCloud, US**) |
| `--tier` | llamaparse tier: `fast` (default), `cost_effective`, `agentic`, `agentic_plus` — higher tiers cost more credits |
| `--language` | OCR language hint, default `de` |
| `--out FILE` | write markdown to FILE instead of stdout |
| `--timeout SEC` | request timeout (default 180) |
| `-v, --verbose` | stats + converter fallback to stderr |
| `--update` | update the skill now |
| `--selfcheck` | Show version + last update |

## Limits

PDF ≤ 10MB and ≤ 500 pages. Scans need `llamaparse` — `pdfplumber` returns nothing for them (auto mode handles this).

## Errors

| Status | Meaning |
|--------|---------|
| 400 | not a valid PDF |
| 401 | token rejected — `credgoo FETCH_URL_BEARER` |
| 413 | too large (10MB / 500 pages) |
| 422 | no text extracted |
| 429 | llamaparse quota / rate limit |
| 504 | conversion timed out |

## Credentials

```bash
# Bearer token for the pdf API — retrieved via credgoo (shared team token):
credgoo FETCH_URL_BEARER

# No 'credgoo' command? Install it once:
uv tool install "credgoo @ git+https://github.com/devskale/python-openutils.git#subdirectory=packages/credgoo"

# Or set it directly:
export PDF2MD_BEARER="..."
```

## Endpoint

`POST https://amd.skale.dev/api/pdf/to_md` — see `https://amd.skale.dev/api/help` and `https://amd.skale.dev/api/openapi.json`.

Backend source: **[devskale/web_apis](https://github.com/devskale/web_apis)**
