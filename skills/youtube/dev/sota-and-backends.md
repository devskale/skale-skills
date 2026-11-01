# SOTA & Backend-Entscheidungen (2026-10/11 Review)

> dev/: Maintainer-Wissen — warum die Backends so gewichtet sind wie sie sind.
> Messdaten und Web-Recherche aus der Review-Session 2026-10-23/24.

## Warum Invidious Default bleibt (und trotzdem stirbt)

- **Live-Messung 2026-10-23/24:** 2/9 Instanzen alive (Probe);
  4/5 Registry-Instanzen haben die API abgeschaltet (`api: false` bei
  90–99% Uptime — das Flag ist das Kill-Kriterium, nicht die Uptime).
- **Struktureller Trend:** seit Invidious 2026-07 können Betreiber
  abuse-prone API-Endpoints deaktivieren — genau das passiert flächig.
  Public instances = "rate-limit roulette" (sumguy.com, 2026-07).
- **Warum trotzdem Default:** der einzige echte Anonymitäts-Hebel —
  die Instance-IP trifft YouTube, nicht deine (references/privacy.md).
  1 lebende Instance reicht für den Default-Pfad.

## Warum yt-dlp die zweite Spalte ist (nicht der Ersatz)

- Live validiert: `ytsearch30` flat = **2,1 s / 30 Videos / 44 Felder**,
  Vollextraktion ~5 s/Video (parallel für Survivors).
- SOTA (Scrapfly-Roundup Aug 2026): yt-dlp = "owns bulk metadata",
  183k★, aktiv; scrapetube-Channel-Listing tot, pytube/youtube-dl tot.
- **Zwei-Stufen-Design:** flat → harte Filter ohne Datum → Enrichment nur
  der Überlebenden (spart 5 s/Video × Pool-Größe).
- Known bug class (Vorfall 2026-11-01): Enrichment darf NIE Voll-Update
  machen — hat viewCount/duration genullt, 30 Videos → 0 Pick-Überlebende.

## Offen (aus dem Rewrite-Issue)

- `expand --like` via yt-dlp (Invidious-Umweg über Channel funktioniert)
- Concurrency-Tuning beim Enrichment (aktuell 6 Worker, cap 25)

## Verwandte Dokumente

- Agent-Sicht: ../SKILL.md (Backends), ../references/privacy.md (Matrix)
- Messdaten-Quelle: Board-Issue `youtube-ytdlp-rewrite` (skaleshare)
