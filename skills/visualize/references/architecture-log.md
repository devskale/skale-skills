# Architecture review log — visualize

Dauerhafte Spur der Architektur-Reviews (Kandidaten, Entscheidungen, Verworfenenes).
Der HTML-Report (before/after-Diagramme) lebt auf throway (~4h); diese Datei ist
die Wahrheit, die überlebt. Neue Reviews oben anfügen.

## Review 2026-10-06 (improve-codebase-architecture skill)

**Ausgangslage:** visualize 1.11.0 — drei share-Modi mit drei Upload-Pfaden, zwei
lint-Engines (inline ~100 Zeilen im Launcher, divergierend von der API), Gates als
verstreute Einzelbefehle.

### Kandidaten und Endstand

| # | Kandidat | Empfehlung | Status |
|---|----------|-----------|--------|
| 1 | Zwei lint-Engines → eine (API-first, offline Hardban-Subset) | Top, mit #2 als ein Zug | ✅ gebaut (1.12.0, `b244e9a`) |
| 2 | `slop_client.py` als Seam (API-Vertrag, Auth, Exit-Codes 0/1/3 an einem Ort) | Top, mit #1 | ✅ gebaut (1.12.0) |
| 3 | Pin-Ledger: realpath → URL, Re-share = PUT in place | Worth exploring | ✅ gebaut (1.12.1, `004105d`) |
| 4 | `visualize gate` — alle Gates parallel hinter einem Command | Speculative | ✅ gebaut (1.13.0, `ebe815b`) |

### Entscheidungen (die Begründungen, die mit dem throway-Report verbrannt wären)

- **Reihenfolge 1+2 vor 3+4:** erst die eine Wahrheit über slop (zwei Engines sind
  ein Divergenz-Risiko bei jedem Detektor-Fix), dann die Interfaces. Der Nutzer
  grillte 9 Fragen und wählte 1+2 als einen Zug.
- **Kandidat 3 fast verworfen:** ursprünglich als „slug per default" entworfen —
  verworfen wegen Kollisionen (zwei Projekte, gleicher Dateiname → gleiche /d/-URL
  überschreibt sich). Nutzer-Entscheidung: random per default, pin macht die URL
  stabil, `--update` bleibt die explizite slug-Wahl. Fakt, das es ermöglichte:
  throway single uploads sind PUT-editable (verifiziert).
- **Kandidat 4 als Speculative eingestuft, dann doch gebaut:** der Wert ist nicht
  die Parallelität (300ms slop-API dominiert), sondern dass der Agent sich EINEN
  Command merkt statt vier. Vergessene Gates waren das beobachtete Versagen.
- **Deletion test:** Launcher fiel 644 → ~585 Zeilen trotz zwei neuen Features.

### Verworfen

- **Nested-cards-Detektor** (DOM-Heuristik ohne Browser): braucht DOM-Bau, std-lib
  html.parser reicht nicht für verschachtelte Karten-Semantik. Offen im slop-Repo.
- **`gate` in share integrieren statt eigenem Command:** share bleibt URL-first
  (slop nach Upload als letztes Netz), gate ist der Agent-Einstieg — zwei Caller,
  zwei Contracte.

## Review <datum> — <skill>

(Vorlage: Ausgangslage, Kandidaten-Tabelle mit Empfehlung+Status, Entscheidungen
mit Begründung, Verworfenenes mit Grund.)
