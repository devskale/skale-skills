# OCR-Timings & Poll-Budget-Rationale

> dev/: Messdaten, die das pages-aware Budget begründen. Agent liest
> references/api.md; diese Zahlen sind Maintainer-Wissen.

## Gemessen (embeddings-Suite, 2026-10-22)

| PDF | Seiten | Pfad | Dauer |
|-----|--------|------|-------|
| T-Embed schematic | 4 | pdfplumber (lokal) | Sekunden |
| bq27220 | 24 | pdfplumber | Sekunden |
| cc1101 | 112 | llamaparse | ~5 min (**2.7 s/Seite**) |
| bq25896 | 65 | llamaparse | ~10 min |
| **PN532** | **222** | llamaparse | **~29 min (≤8 s/Seite)** — poll budget erschöpft, Job war trotzdem fertig |
| **st7789v** | **316** | llamaparse | >19 min, lief noch bei Abbruch |

**Die alte Dokumentation sagte 0.5–0.8 s/Seite — das gilt NUR für den
lokalen pdfplumber-Pfad.** llamaparse-OCR (Cloud) real: **2.7–9 s/Seite**.

## Daraus folgt das Budget

`SECONDS_PER_PAGE_POLL = 10` (oberer Rand der Messreihe) + 120 s Puffer,
mindestens das statische Default (600 s). 222 Seiten → 2340 s.

**Design-Prinzip:** zu lange warten schadet nicht (der Job läuft
serverseitig weiter, Re-Run re-attacht) — ein zu frühes Exiten bricht
`&&`-Batch-Calls (Vorfall: esp32-s3 lief nie).

## Incident-Lore

- 2026-10-22: statisches 600s-Budget killte 222/316-Seiten-Scans mitten im
  Batch → pages-aware Budget gebaut (Commit f8bb909)
- 2026-10-23: `Any`-Import-Fehler + `pull.rebase`-Verwirrung im Launcher —
  Suite fing beides (26 FAILs → 66/66 nach Fix)
