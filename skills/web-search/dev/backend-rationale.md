# Backend-Kette: Rationale (Invidious-Lektion angewandt)

> dev/: warum die Gewichtung eigene-API → eigene-SearXNG → öffentliche
> Instanzen genau richtig ist — und was das Invidious-Debakel lehrt.

## Die Gewichtung (bewusst)

```
EIGENE Duck API (amd.skale.dev) → EIGENE SearXNG (lubu) → public instances
     selbst gehostet                 selbst gehostet          Ökosystem-Risiko
```

Das youtube-Skill hatte dieselbe Frage anders beantwortet: **öffentliche
Invidious-Instanz als Primary** — und wurde 2026-10-24 dafür bestraft
(2/9 alive, 4/5 Registry-APIs disabled; Commit-Historie: Registry-
Metadaten als Prophylaxe). web-search hatte die kritischen Schichten von
Anfang an auf eigenen Maschinen — der Musterschüler.

## Warum öffentliche Instanzen trotzdem bleiben (als Last Resort)

- Sie sind kostenlos und brauchen keine Wartung
- Degraded-Instanz-Erkennung existiert (200-mit-leer bei suspendeten
  Engines = Outage → nächste Instanz), ad-Redirect-Filter, 12h-Query-Cache
- Das Risiko sitzt am ENDE der Kette, nicht am Anfang

## Ausbaufälle (falls jemals nötig)

- Duck API tot → SearXNG übernimmt still (Client-Fallback existiert)
- lubu down → public instances
- Beides tot → ehrlicher Fehler statt Stillstand

Verwandt: youtube/dev/sota-and-backends.md (die Gegen-Geschichte)
