---
name: agentos-discover
description: "Read-only audit discovery: assessment results, pruefer feedback, KI vs human discrepancies, missing docs. Entry point before running flows. For project/bidder/document listing use ofs skill instead."
compatibility: "Requires agentos + ofs (packages/agentos, packages/ofs)"
metadata:
  author: skale
  version: "1.1.0"
---

# Agentos Discover — Audit Status & Analysis

**Look before you run.** Read-only audit insights, no side-effects.

> **Architecture:** `discover.py` is a **thin presentation wrapper over the `ofs`
> CLI** (it shells out via `subprocess`, not `ofs.api`). For the raw structures,
> prüfer-extraction, or analyze engine, use the canonical accessors in the
> **ofs skill → Canonical Accessors** (`ofs.audit_analyze.analyze_kriterien` is
> the engine both `ofs audit analyze` and the discrepancies below run). Unique
> value here: pre-formatted tables, fuzzy `resolve`, cross-bidder `compare`.

```bash
cd ~/code/python-utils/packages/agentos
uv run python discover.py --help
```

## Scope

| In scope | Out of scope → use |
|----------|-------------------|
| Assessment results & history | ofs (project/bidder/document listing) |
| Pruefer feedback & discrepancies | agentos-flows (execute flows) |
| Missing docs, bidder comparisons | pdf2md (convert docs) |
| Criterion detail with evidence | strukt2meta (metadata) |

## Commands

```bash
# Audit status & analysis
uv run python discover.py overview <project> "<bidder>"     # Assessment overview
uv run python discover.py detail <project> "<bidder>" <id>  # Single criterion detail
uv run python discover.py fehlend <project> "<bidder>"      # Missing documents
uv run python discover.py comments <project> "<bidder>"     # Pruefer feedback
uv run python discover.py discrepancies <project> "<bidder>" # KI vs Prüfer
uv run python discover.py compare <project>                 # Compare all bidders

# Resolve names
uv run python discover.py resolve <project> <bidder_fuzzy>
```

## Decision Matrix

| User asks | Use | Command |
|-----------|-----|---------|
| "Übersicht Bieter X" | ✅ | `discover.py overview` |
| "Detail zu Kriterium Y" | ✅ | `discover.py detail` |
| "Fehlende Dokumente?" | ✅ | `discover.py fehlend` |
| "Prüfer-Kommentare?" | ✅ | `discover.py comments` |
| "KI vs Prüfer?" | ✅ | `discover.py discrepancies` |
| "Bieter vergleichen" | ✅ | `discover.py compare` |
| "Welche Projekte/Bieter?" | → ofs | `ofs list-projects` / `list-bidders` |
| "Zeige Dokumente" | → ofs | `ofs list-docs` / `read-doc` |
| "Auditiere Kriterium" | → agentos-flows | `auditFlow.py --id --force` |

## Checkpoints lesen (read-only)

Phase-Snapshots eines gelaufenen Flows liegen unter
`logs/checkpoints/<proj>@<bieter>/<kriterium>/` (nur wenn der Run mit
`AUDITFLOW_CHECKPOINTS=1` lief):

| Datei | Inhalt |
|---|---|
| `post_gather.json` | gather-state (deterministic points, `kriterium_anforderung`, AAB, entitäten) |
| `post_assess.json` | FAP: Arme + Judge-Ergebnisse pro Doc · PA: finales Step-2-Result (assessment, dok-tiers, nachweise) |
| `post_befund.json` | kumulativ `{gather, audit, befund}` — Tiers + entities |

```bash
# gather-state ansehen (was der Flow wusste, bevor Docs geöffnet wurden):
python3 -c "import json; d=json.load(open('logs/checkpoints/P@B/E_BERUFL_006/post_gather.json')); print(json.dumps(d['state']['gather'], ensure_ascii=False, indent=1)[:3000])"
# welche docs hat der retriever gewählt + judge-ergebnisse:
python3 -c "import json; d=json.load(open('.../post_assess.json')); [print(a['key'], [x.get('dateiname') or x.get('name') for x in a.get('docs', [])]) for a in d['state']['audit']['arms']]"
```

## Dev-loop helpers (scripts/)

Repeatable operations as tools, not inline Python. All CWD-independent
(`uv run --project packages/agentos`).

| Tool | What |
|---|---|
| `scripts/audit-check.py "X@Y" [ids]` | **Run + compare.** Shows KI vs Prüfer per criterion; default = the wrong set (`disagreements`). `--run` re-runs auditFlow then diffs. Exit code = mismatch count. |
| `scripts/ap-docs.py "X@Y"` | **Read/edit AP-doc classification.** Lists the Angebotsprüfung docs (Angebot/Preisblatt/LV/Angebotsdetail/Abgabeprotokoll) with their `kategorie`/`name`. `"X@Y@file" --kategorie <v>` edits the sidecar (NFC-safe, merge). |

Both reuse the canonical ofs accessors (see ofs skill → Canonical Accessors).

## Status Icons

| Icon | Status | Meaning |
|------|--------|---------|
| ✅ | `pre.ki.ja` / `audit.ja` | erfüllt |
| ❌ | `pre.ki.nein` / `audit.nein` | nicht erfüllt |
| ⚠️ | `pre.ki.teilweise` | teilweise erfüllt |
| ⊘ | `pre.ki.na` | nicht anwendbar |
| 🔧 | `benötigt Eingriff` | needs human review |
| ❓ | `nicht beurteilbar` | cannot assess |
| — | `sync` / `zurückgestellt` | not yet / deferred |

## Direct API

```python
from ofs.api import get_kriterien_audit_json

audit = get_kriterien_audit_json("Project", "Bidder")
for k in audit["kriterien"]:
    print(f'{k["id"]:15s} {k.get("audit",{}).get("status","?"):25s} {k.get("assessment",{}).get("erfüllt","?")}')
```
