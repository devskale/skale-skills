# YouTube-Transcript-Landschaft 2026: warum der Zwei-Takt-Pfad

> dev/: Hintergründe zum Fast-Path/Fallback-Design und den Cookie-Regeln.
> Agent-Sicht: SKILL.md; hier die Landschafts- und Incident-Lore.

## Der 2026-Markt (Scrapfly + getxapi, Mai 2026)

- **youtube-transcript-api** (Python, 8k★) = SOTA für Transcript-Text —
  Instanz-API seit 1.x, Cloud-IPs werden geblockt (Residential ok).
  peep's Fast-Path (youtube-transcript-plus, Node) ist das Pendant,
  aktiv gepflegt (2.0.3, Sep 2026).
- **yt-dlp-Untertitel** als Fallback: trägt Cookies (fast path kann es
  nicht) — deshalb fallen 🔒-Videos automatisch auf yt-dlp.
- SABR-Blocks 2026 betreffen Format-Downloads, NICHT Untertitel —
  Transcript-Pfad unberührt.

## Physik des Age-Gates (dokumentiert, aber hier der Grund)

Cookies = Account-Identität am Request. YouTube prüft die
Altersverifikation am ACCOUNT, nicht am Browser — deshalb besteht nur
1 von 9 Chrome-Profilen den Gate (verifiziert 2026-09): nur dieses eine
Konto ist altersverifiziert. Kein Skill-Problem, Account-Problem.

## Die Cookie-Regeln (Nutzer-Regeln 2026-10-23/24)

1. **Agent fragt IMMER** which profile/account vor `--cookies` (SKILL.md
   Hard Rule) — nie stillschweigend das persistierte Config-Profil.
2. **Tool anunciert laut** jede aufgelöste Spec auf stderr:
   `🔒 cookies: chrome:Profile 2 — this download runs under that browser
   identity` (nicht nur Debug) — Defense in Depth gegen Regel-Vergessen.

## 429 bei übersetzten Captions

YouTube-seitiges Rate-Limiting, nicht fixbar (PO-Token ändern nichts).
Originalsprache lädt zuverlässig — deshalb ist sie der dokumentierte
Workaround, nicht ein Bug-Report-Wert.
