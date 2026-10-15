---
name: ofs
description: "Navigate OFS (Opinionated Filesystem) to discover projects, bidders, and documents. Triggers when the user asks about available projects, bidders, wants to list or read documents (.pdf, .docx, .xlsx, .pptx), explore the tender document structure, audit status, kriterien, bdoks, or search for items by keyword. Also use for projekt-sync, kriterien-audit, index management, and structure ops on bidder/sub trees: clone, diff, archive/restore/delete. Do NOT use for PDF conversion (use pdf2md) or metadata classification (use strukt2meta)."
compatibility: "Requires ofs package (local monorepo: packages/ofs)"
metadata:
  author: skale
  version: "0.6.0"
allowed-tools: Bash(uv run python -m ofs:*)
---

# OFS — Projects, Bidders & Documents

**Source of truth is the CLI.** Always `--help` before assuming flags exist.

```bash
cd ~/code/python-utils/packages/ofs
uv run python -m ofs --help
uv run python -m ofs <command> --help
uv run python -m ofs projekt "X" <subcommand> --help
```

## Data Model

Two layers connected by `projekt-sync`:

| Layer | File | Per | Question |
|-------|------|-----|----------|
| **Project** | `projekt.json` | Project | "What must be checked?" |
| **Audit** | `audit.json` | Bidder | "Did the bidder pass?" |

```
projekt.json ──projekt-sync──→ B/Bidder/audit.json
```

### Identifier Format

| Format | Target |
|--------|--------|
| `Project` | Project A/ only |
| `Project@` | A/ + all bidders |
| `Project@B` | All bidders |
| `Project@Bidder` | Bidder dir (`B/Bidder/`) |
| `Project@Bidder/Sub` | Subcontractor (`B/Bidder/S/Sub/`) |
| `Project@File` | Tender doc (`A/File`) |
| `Project@Bidder@File` | Bidder doc |
| `@all` | All projects |
| `@all@B` | All bidders across all projects |
| `@Bidder` | Bidder across all projects where it exists |

`S/` is implicit — the `/` in the bidder part means "look in S/".

### Status Values

| Context | Field | Values |
|---------|-------|--------|
| Project | `pruefung.status` | `freigegeben` · `draft` |
| Audit criteria | `audit.status` | `audit.ja` · `audit.nein` · `audit.teilweise` · `sync` |
| Audit bdoks | `manueller_status` | `vorhanden` · `fehlend` · `teilweise` · `nicht_anwendbar` |

## Common Patterns

```bash
# Discovery
ofs list-projects
ofs list-bidders "ProjectName" --subs
ofs tree -d

# Search (scopes: none / project / project@bidder)
ofs search "versicherung"
ofs search "OGK" "projekt_b" --type docs

# Layer 1: Project
ofs projekt "X" info         # overview
ofs projekt "X" ids          # criteria
ofs projekt "X" bdoks        # required documents

# Layer 2: Audit (target = "Project@Bidder")
ofs audit "X@Y" summary
ofs audit "X@Y" kriterien --json
ofs audit "X@Y" bdoks --fehlend
ofs audit "X@Y" analyze        # AI vs human feedback comparison

# Connect layers
ofs projekt-sync "X@Y"       # one bidder
ofs projekt-sync "X"         # all bidders

# Documents
ofs list-docs "X@Y" --health  # 4-dim health check
ofs read-doc "X@Y@file.pdf"
ofs read-meta "X@Y@file.pdf"

# Audit events
ofs kriterien-audit show "X" "Y" "K_ID"
ofs kriterien-audit mensch "X" "Y" "K_ID" --akteur cli

# Raw JSON
ofs json read "X" projekt.json meta
ofs json read "X" audit.json --bidder "Y"

# Index — completion status
ofs index stats @all                     # all projects, all dimensions (A/ + B/)
ofs index stats "Fahrzeugeinrichtung@"   # A/ + all bidders
ofs index un @all                         # only undone files
ofs index un "Project@Bidder"            # undone for specific bidder
ofs index un @all --json                  # machine-readable
ofs index un @all --priority high         # only real-work backlog (excludes cosmetic 'assessed')
```

## Canonical Accessors (Python — use these, don't guess)

The CLI covers most cases. For agentos/scripts that need raw structure, **import
from `ofs.api` / `ofs.json_manager` / `ofs.audit_analyze`** — these are the
canonical, NFC-safe, filter-respecting accessors. Direct `open()` of `.dir/`
bypasses OFS filters (zurückgestellt) and breaks on NFD filenames.

### The two layers (read paths)

| Want | Layer | Canonical accessor |
|---|---|---|
| **Requirements** (anforderung, dokumente, schwellenwert per criterion) | Project (`projekt.json`) | `ofs.json_manager.read_json_file(project, "projekt.json")` |
| **Results + prüfer feedback** (KI status, history, kommentar) | Bidder (`audit.json`) | `ofs.api.get_kriterien_audit_json(project, bidder, must_exist=True)` |

### `projekt.json` structure (the source of truth for criteria)

```python
from ofs.json_manager import read_json_file
proj = read_json_file("Aufsitzrasenmäher", "projekt.json")
# top keys:  meta · bdoks · ids
kr   = proj["ids"]["kriterien"]        # list[dict] — id/typ/name/anforderung/dokumente/schwellenwert/geltung_lose/pruefung
bdoks = proj["bdoks"]["bieterdokumente"] # list[dict] — required bidder documents
ids_map = {k["id"]: k for k in kr}      # the dict analyze_kriterien wants
```

### `audit.json` read + KI-vs-Prüfer analyze (the same engine `ofs audit analyze` uses)

```python
from ofs.api import get_kriterien_audit_json
from ofs.audit_analyze import analyze_kriterien
from ofs.json_manager import read_json_file

audit = get_kriterien_audit_json(project, bidder, must_exist=True)
proj_ids = {k["id"]: k for k in read_json_file(project, "projekt.json").get("ids", {}).get("kriterien", [])}
result = analyze_kriterien(audit, proj_ids)
# result = {total, disagreements:[...], confirmed:[...], ai_only:[...], stale:[...]}  ← DO NOT re-derive
#   disagreements = KI ≠ Prüfer (the 'wrong' set); each entry: id/name/last_ai/last_human/erfuellt/kommentar/docs
```

### `ofs.api` reference (exact public functions)

| Function | Returns | Layer |
|---|---|---|
| `list_projects()` | projects | — |
| `list_bidders_for_project(project)` | bidder names | project |
| `find_bidder(project, bidder)` | resolved bidder path or None | project |
| `docs_list(identifier, meta=False, include_withheld=False, parsers=False)` | documents (filtered). **identifier is ONE arg** `'project@bidder'` — NOT `(project, bidder)` (passing bidder positionally sets `meta=True` and scans A/!). Use `include_withheld=True` to see zurückgestellt docs. | both |
| `read_document(identifier, parser=None, as_json=False)` | doc text/structured | both |
| `read_project_json(project, filename)` / `write_project_json(...)` | any project JSON (raw) | project |
| `read_json_file(project, filename, key_path=None, bidder=None)` | JSON at path | both |
| `get_kriterien_audit_json(project, bidder, must_exist=False)` | full audit.json | bidder |
| `list_kriterien_audit_ids(project, bidder)` | `{count, ids:[...], status_counts}` | bidder |
| `get_kriterium_description(project, kid)` | `{id, name, raw}` from projekt.json | project |
| `get_bieterdokumente_list(project)` | bdoks.bieterdokumente list | project |
| `kriterien_audit_event(project, bidder, kid, ereignis, ...)` | **write** an audit event | bidder |
| `kriterien_sync(project, bidder=None)` / `kriterien_sync_all()` | **write** sync audit.json from projekt.json | both |
| `kriterien_pop(project, limit, bidder)` | next unproven kriterien | both |
| `search(query, scope=None, ...)` | matches | both |

### ⚠️ Gaps — these do NOT exist (don't reach for them)

| Missing | Use instead |
|---|---|
| `ofs.api.get_kriterien_ids(...)` (the full list) | `read_json_file(project, "projekt.json")["ids"]["kriterien"]` |
| A typed `Kriterium` object / dataclass | raw dict from the accessors above |
| A set/clear helper for a single criterion's assessment | `kriterien_audit_event(...)` (append event) + re-run the flow |
| Prüfer-status re-derivation (history walk) | `ofs.audit_analyze.analyze_kriterien(audit, proj_ids)` → `disagreements` |

## Health Check

`list-docs --health` runs 4 checks per document:

| Check | ✅ OK | ❌ Problem |
|-------|-------|-----------|
| **Parse** | score ≥ 3 | unscored / < 3 |
| **Meta** | name + kategorie | incomplete |
| **Signature** | checked (B/), — (A/) | not checked |
| **Freshness** | content hash matches | stale |

A/ (tender) documents skip signature checks.

## Audit Analyze

`audit analyze` compares AI assessment vs human reviewer feedback:

- **KI ≠ Mensch** — where AI and human disagreed
- **KI = Mensch** — where human confirmed AI
- **Nur KI** — criteria not yet reviewed by a human
- **Status ≠ erfüllt** — stale assessment (audit status updated but erfüllt not)

```bash
ofs audit "X@Y" analyze
```

## Index Commands

`ofs index stats` and `ofs index un` check file completion across **eight dimensions**
(defined in `COMPLETION_CHECKS`; the daemon dispatches them per `aufbereitung.yml`
— see `docs/datenmodell-metadaten.md` §7 for the canonical table + flags):

| Dimension | Check |
|-----------|-------|
| **parsed** | has parser output (docling, pdfplumber, etc.) |
| **quality** | best md variant score ≥ 3 |
| **assessed** | every parsed md variant carries a score (`idle_only` cosmetic) |
| **kategorie** | has `meta.kategorie` |
| **schutzklasse** | has `meta.schutzklasse` |
| **classified** | docling picture-classification ran (`bidder_only` — B/+S/ PDFs only) |
| **signature** | signature check ran (`bidder_only` — B/+S/ docs only) |

Dimensions are defined in `COMPLETION_CHECKS` dict — extensible. The daemon's
priority model (what runs first, `requires`/`idle_only` flags) lives in
`ofs/aufbereitung.yml`.

- **`stats`** shows all files, all dimensions
- **`un`** shows only files with missing checks, tagged `-parsed -kat -schutz -q -assessed -classified -signature`
- **`un --priority high`** only docs needing real work (excludes `idle_only` finishers like `assessed`)
- **`un --priority low`** only cosmetic idle_only finishers

```bash
ofs index stats @all                     # all projects, all dimensions (A/ + B/)
ofs index stats "Fahrzeugeinrichtung@"   # A/ + all bidders
ofs index un @all                         # only undone files
ofs index un "Project@Bidder"            # undone for specific bidder
ofs index un @all --json                  # machine-readable (gains high_priority/low_priority)
ofs index un @all --priority high         # only real-work backlog
```

Both accept OFS notation (`@all`, `Project@B`, `@Bidder`, etc.).

## Structure Ops (clone / diff / archive)

Three commands operate on **whole bidder or subunternehmer subtrees** via OFS
notation (never split `@` by hand). `clone`/`archive` run as `task_ofs` worker
jobs; `diff` is read-only. Mutating commands default to **dry-run**; pass `--run`
to execute. Full flag list: `ofs <cmd> --help`.

### clone — copy or move a bidder/sub subtree

```bash
ofs clone "X1@Y" "X2@Y"              # dry-run plan (default); add --run to execute
ofs clone "X1@Y" "X2@Y" --move --run  # copy-then-delete source
ofs clone "X@Y" "X@Z/Sub"            # dest can rename / cross-project / nest as sub
```

Copy order: **docs → sidecars → md/ → audit.json → index** (each gated by
`--no-*` flags). `--audit` is a tri-state — the **non-obvious** one:
- `keep` (default) — source `audit.json` copied 1:1. Correct for same-project clone.
- `skip` — no `audit.json` at dest.
- `clean` — fresh `audit.json` via `projekt-sync --clean` **against the DEST
  project** (kriterien-IDs re-synced, reset to `sync`). Correct for cross-project clone.

Never copies `projekt.json` (project layer); no project-level clone. Integral
index refresh after `--run` (do not call `ofs index` yourself).

### diff — compare two bidder/sub subtrees (read-only)

```bash
ofs diff "X@Y" "X2@Y" [--json]        # identical / changed / only-left / only-right
```

Compares by NFC-normalized relative path + size/SHA-256. Verify a clone is 1:1,
compare `Bieter` vs `Bieter_Runde 2`, see what aufbereitung touched. Rejects
project-level identifiers.

### archive — move to B/Archiv/, restore, delete

`Archiv/` is reserved (`paths.py`): an archived bidder disappears from
`list-bidders` automatically. Subs archived **flat** (`Bidder_Sub`).

```bash
ofs archive "X@Y" --run                                # move to B/Archiv/Y
ofs archive "X@Archiv/Name" --restore [--as NAME] --run  # back to B/
ofs archive "X@Archiv/Name" --delete --run               # delete ONLY from archive
ofs archive "X" --list                                 # archive contents (or @all)
```

**Safety**: `--restore`/`--delete` require an `X@Archiv/Name` identifier —
deleting an active bidder is hard-rejected. Restore always goes to a top-level
bidder (no nested restore).

## PAS (Prüfanweisungen) — progressive-disclosure guidance

PAS are the audit-guidance files (`.dir/.kontext.one/pas/*.md`) consumed by
auditFlow's standard-path resolver. They live in a hidden subtree that OFS
excludes from project/bidder enumeration; `ofs.pas` is the single access point.

```bash
ofs pas list                     # Level-1 catalog (all PAS, with kind tags)
ofs pas show <name>              # full record (frontmatter + body)
ofs pas lint                     # validate frontmatter contract
```

`kind` classification: `routable` (resolver picks from these) · `querschnitt`
(cross-cutting, lazy-referenced) · `meta` (Guide/template/overview — never
routed). `ofs.pas.list_routable_pas()` is the safe catalog for an LLM resolver.

## Gotchas

- **NFC/NFD**: macOS stores filenames in NFD; OFS normalizes to NFC internally. Use `nfc()` from `ofs.unicode` for comparisons. `clone`/`archive` write dest in NFC; `diff` compares by NFC-normalized relative path.
- **Structure ops reuse machinery**: `clone`/`archive` reuse `_resolve_source`, `nfc_resolve`, the integral index refresh, and ROBOTNI progress (`ofs_clone` / `ofs_archive` phases). They never copy/move `projekt.json` (project layer) or reserved dirs as entities.
- **clone `--no-sidecars`**: the integral index refresh may stamp a bare `uploaded_at` sidecar via `_ensure_sidecar_uploaded_at` (normal ofs index maintenance) — the rich source metadata is NOT copied, but a minimal sidecar may appear. Use `ofs diff` to inspect.

- **NFC/NFD**: macOS stores filenames in NFD; OFS normalizes to NFC internally. Use `nfc()` from `ofs.unicode` for comparisons.
- **Parser selection**: `read_doc()` picks highest `parse_quality.score` (0–5) from YAML frontmatter. Falls back to static hierarchy if no scores.
- **Always `uv run`**: Never call `python` directly — each package has its own `.venv`.
- **projekt-sync order**: sync must happen before audit commands (audit.json is created by sync).
- **Content hash freshness**: `_content_hash` in `.pdf.meta.json` is SHA-256 of MD text after frontmatter stripping and image noise cleanup. Different hash = document re-parsed since metadata was generated.
