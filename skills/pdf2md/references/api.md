# pdf2md API Reference

Loaded on demand — SKILL.md keeps only the 90% path.

## Options

| Option | Description |
|--------|-------------|
| `--method` | `auto` (default), `pdfplumber` (local, text-layer PDFs), `llamaparse` (cloud OCR — **the document is uploaded to LlamaCloud, US**) |
| `--tier` | llamaparse tier: `fast` (default), `cost_effective`, `agentic`, `agentic_plus` — higher tiers cost more credits |
| `--language` | OCR language hint, default `de` |
| `--out FILE` | write markdown to FILE instead of stdout |
| `--timeout SEC` | request timeout (default: 180 s for pdfplumber, 600 s for llamaparse — OCR scales with page count) |
| `-v, --verbose` | stats + converter fallback to stderr |
| `--update` | update the skill now |
| `--selfcheck` | Show version + last update |

## Limits

PDF ≤ 10MB and ≤ 500 pages. Scans need `llamaparse` — `pdfplumber` returns nothing for them (auto mode handles this).

## Long documents

Expected durations: text-layer PDFs convert in seconds; scans via llamaparse scale with page count — **expect minutes**, more on higher tiers. Large jobs are an agent-workflow concern, not a CLI one:

- Always write to a file: `pdf2md big.pdf --out result.md -v` — megabyte stdout blobs help no one.
- **Run it in the background** from the agent shell, then poll `result.md` / the process — don't block a tool call that harnesses kill after a few minutes.
- Raise the budget explicitly if needed: `--timeout 900`.
- Above the API cap (10 MB / 500 pages): split the PDF, convert per part, concatenate the Markdown in order (no client-side chunking in this skill by design).
- 429/504: no automatic retries by design — 429 means quota, 504 means the server gave up; drop the tier (`--tier fast`), wait, or split.
- With `-v` a heartbeat prints elapsed seconds to stderr every 30 s so a long wait is distinguishable from a hang.

## Async jobs (the API forces them for long documents)

Beyond ~40 pages the API answers the POST with **202** instead of markdown: `{job_id, status: queued, poll, auto_async}`. pdf2md follows automatically — it polls `GET /pdf/jobs/{job_id}` every 3 s until `status: done` and extracts `markdown`. Same output file, same exit codes, no flags needed.

- `--timeout` doubles as the **total poll budget** (default 600 s for llamaparse). 500-page scans run at ~2 s/page — raise it explicitly, e.g. `--timeout 1800`.
- On budget exhaustion the error prints the job id and the manual poll command — **results stay retrievable for ~2 h** (`expires_in` in the job status).
- With `-v` a `polling job …` heartbeat prints every 30 s so a long wait is distinguishable from a hang.
- `status: failed` exits with the job's `error` field.

## Transfer (throway)

`transfer=throway` (server param, not exposed as a CLI flag): the result is uploaded to skale.dev/throway with a **4 h TTL** and only `markdown_url` is returned. pdf2md downloads it transparently and — at `-v` — tells you the shared link. The status line then shows `converter=done` (job answers carry no `converter` field).

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
