---
name: strukt2meta
description: "Classify documents and extract metadata using AI. Triggers when the user asks to generate metadata (.meta.json sidecar), run kriterien extraction (meta/bdoks/ids steps, writes projekt.json), refine or reassess extracted criteria, check processing status, or re-process files with --overwrite. Do NOT use for browsing projects/bidders/reading docs/audit (use ofs skill) or PDF conversion (use pdf2md skill)."
metadata:
  author: skale
  version: "0.0.31"
---

# strukt2meta — AI Metadata & Criteria Extraction

Classify documents and extract structured criteria from German tender documents (AAB). Uses LLM inference via uniinfer.

## Commands

All commands run from `packages/strukt2meta`. Always use `uv run` — never call `python` directly.

```bash
# Metadata generation (sidecar .meta.json)
uv run strukt2meta ofs PROJECT@BIDDER@FILE -v              # single file
uv run strukt2meta ofs PROJECT@BIDDER -v                   # all pending files
uv run strukt2meta ofs PROJECT --overwrite                  # re-process all

# Sharpen: fill missing fields (light, no doc reading)
uv run strukt2meta ofs PROJECT@BIDDER --sharpen -v

# Kriterien extraction (writes projekt.json)
uv run strukt2meta ofs PROJECT --mode kriterien --step meta   # tender metadata + lots
uv run strukt2meta ofs PROJECT --mode kriterien --step bdoks  # required bidder documents
uv run strukt2meta ofs PROJECT --mode kriterien --step ids    # all criteria (F/E/Z)

# Refine (after ids step)
uv run strukt2meta ofs PROJECT --mode kriterien --step ids \
  --refine "F_ANGE_002" --to                                 # remove (no LLM call)
uv run strukt2meta ofs PROJECT --mode kriterien --step ids \
  --refine "E_FINANZ_001" --steer "Schwellenwert EUR 1M" --to  # modify without AAB
uv run strukt2meta ofs PROJECT --mode kriterien --step ids \
  --refine "Z_QUAL_001" --reassess --to                       # re-extract from AAB

# Test output
uv run strukt2meta ofs PROJECT --mode kriterien --step ids \
  --model "tu@qwen-3.5-397b" --to --force -v                 # to tests/<Project>/
```

Key flags: `--overwrite` (re-process), `--force` (bypass source-hash), `-v` (verbose), `--to` (test output), `--model "provider@model"`, `--sharpen` (fill missing fields), `--refine "ID"`, `--steer "msg"`, `--reassess`

## Refine Modes

| Mode | CLI | AAB | Use case |
|------|-----|-----|----------|
| remove | `--refine "ID" --to` | No | Delete selected items instantly |
| steer | `--refine "ID" --steer "msg" --to` | No | Quick fix: modify, merge, add |
| reassess | `--refine "ID" --reassess --to` | Yes | Re-extract selected items from AAB |

`--refine` accepts exact IDs or prefixes, comma-separated. Empty LLM response = all selected items removed.

### Which refine mode when?

- **Items are *wrong* (mis-extracted, missing, wrong schwellenwert)** → `--reassess`
  (re-reads AAB, re-extracts with current logic). The fix lives in the AAB.
- **Items are *suboptimal* (right content, wrong wording/schwellenwert text,
  merge/split decision, rename)** → `--steer "<instruction>"` (no AAB re-read;
  you hand the transformation). Faster, deterministic.
- **Items should not exist** → bare `--refine "ID" --to` (remove, no LLM).
- **Add new items** → `--steer` with a "Füge hinzu" instruction (steer can add).

### Composite-criteria decomposition (UND-Logic → split)

A criterion bundling **independently-checkable** proofs (UND-Logic) should be
**split** — one criterion = one verdict. The canonical example: `E_BERUFL_002`
"Berufliche Zuverlässigkeit" often bundles Strafregister + Insolvenz + SV +
Steuern, which an auditor checks separately. Other projects correctly split
these into `E_BERUFL_001..007`. See `docs/kriterien-improvement.md` for the
rule ("geplant": UND → split, ODER → keep together).

Steer-split a composite (fastest, you control the decomposition):
```bash
uv run strukt2meta ofs PROJECT --mode kriterien --step ids \
  --refine "E_BERUFL_002" \
  --steer "Bündelt Strafregister, Insolvenz, SV, Steuern (UND-Logik). Zerlegen in E_BERUFL_002 (Strafregister, 6 Monate), E_BERUFL_003 (Insolvenz, 3 Monate), E_BERUFL_004 (SV, 3 Monate), E_BERUFL_005 (Steuern §229a, 3 Monate) — je eine unabhängige Prüfung." \
  --to
```

⚠️ **audit.json migration caveat (load-bearing):** refine writes `projekt.json`
only. A subsequent `ofs projekt-sync` re-syncs `audit.json` from the new IDs —
which **orphans existing prüfer history / comments** tied to the old ID
(e.g. a 4-section prüfer comment on E_BERUFL_002 must be re-mapped onto the
new E_BERUFL_002..005 or it is lost). Before syncing a decomposed criterion,
back up `audit.json` per bidder and migrate the history. The auto-migration
is **not** implemented — it is a manual step. See `.handoff/issues/` (search for strukt2meta-* slugs).

## Kriterien ID System

`TYP_KATEGORIE_NUM` — e.g. `F_ANGE_001`, `E_BERUFL_002`, `Z_QUAL_001`

- F = Formal (Ausschluss), E = Eignung (Ausschluss), Z = Zuschlag (Punktabzug)
- Category suffixes: BIEGE, TECH, WIRT, BERUFL, PREIS, QUAL, TERM, DOK, FORM, NACH, FRIST

## Output

- `projekt.json` per project, accumulative keys: `meta`, `bdoks`, `ids`
- Sidecar: `<file>.meta.json` (full metadata + provenance)
- Test output: `tests/<Project>/<provider>_<model>/projekt.json`

## Gotchas

- **Always `uv run`** — each package has its own `.venv` managed by uv
- **Never modify productive `.dir/` data** — use `--to` for test output
- `batch` subcommand deprecated — use `dirmeta`
- `kriterien` standalone subcommand deprecated — use `ofs --mode kriterien`
- OFS_BASE_DIR env var overrides default OFS root
- `--refine "ID"` without `--steer` removes instantly, no LLM call
- `--refine --reassess` re-reads AAB — use when items are wrong, not just suboptimal
- Model config in `config.json`: default `tu@qwen-3.6-35b`, kriterien `gemini@gemini-3-flash-preview`
- Prompt templates: `prompts/kriterien.{meta,bdoks,ids,refine}.md`
