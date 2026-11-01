# X/Twitter-Landschaft 2026 & Lifecycle-Inzidente

> dev/: warum Launcher + Dev-Guard + Drift-WARN existieren. Agent-Sicht:
> SKILL.md (Troubleshooting); hier die Hintergründe.

## Die Landschaft (recherchiert 2026-10-23)

- **Nitter ist tot** (X-Corp Cease-and-Desist Aug 2026, Repo archiviert,
  Instanzen gekippt) — Gast-Token-Scraping als Kategorie beendet.
- **peeps Architektur = "Option 2" im 2026-Markt:** Cookie-Extraktion +
  internes GraphQL (wie twikit, mcp-twikit, x-scraper). Persönlicher
  Client mit eigener Session → Risiko **Account-Level** (Suspension),
  nicht Klage-Level — read-only ist die richtige Posture, Writes off
  by default war der Lage voraus.
- **QueryId-Rotation alle 2–6 Wochen** (SOTA: "plan a 2–6 week update
  cadence into your roadmap") — peep refreshed IDs selbst, aber
  strukturelle Brüche brauchen ein neues Release. Letzter Release:
  2026-04-27 — Releases im Blick behalten.

## Incident-Lore (Launcher-Bau, 2026-11-01)

1. **Downgrade-Vorfall:** installiertes Binary war ein Dev-Build (`main`,
   mit `research`) — der erste `--update` zog es auf Release 0.9.0
   (ohne `research`) runter. → **Dev-Build-Guard**: nicht-numerische
   Versionen werden nie auto-gedowngradet; nur `--update --force-realign`.
2. **Phantom-Skill:** `research` war in SKILL.md + Tests dokumentiert,
   existiert aber in KEINEM verfügbaren Build (weder Release noch clone
   main — upstream WIP, nie gelandet). Tests jetzt konditional + WARN.
3. **BSD-sed-Falle:** `\?` in basic regex existiert auf macOS nicht —
   Versions-Parsing ging leer aus. Fix: `sed -E`.

## Verwandt

- improve-ux/dev: –
- issues/dev/inspirations.md: hex (Dev-Channel-Self-Updater als
  grown-up Version unserer Launcher-Checks)
