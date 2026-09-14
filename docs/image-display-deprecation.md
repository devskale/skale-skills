# viewimg Deprecation — Image Display in pi

**Status:** Deprecated (0.1.0 → deprecated)
**Date:** 2026-09-14
**Reason:** `read img.jpg` (native pi image display) and `read_image`/`/readimg` (VLM analysis) provide the same functionality with better quality, fewer dependencies, and no separate CLI.

---

## The Image Display Axes

There are three axes for handling images in pi:

```
DISPLAY (zeigen, keine Tokens)         VLM (verstehen, kostet Tokens)         CLI-Skill
────────────────────────────────────────────────────────────────────────────────────────
read img.jpg → inline für User        read_image / /readimg → VLM-Analyse    viewimg img.jpg
generate_image → inline für User      read + understand:true → VLM-Subcall   --open → Preview
MCP screenshots → je nach Mode         (delegate / switch / human / off)      (deprecated)
```

### Display-Axis (Pixel für den User, nie für's Model)

| Quelle | Tool/Command | VLM? | Tokens? | Render-Format |
|--------|--------------|------|---------|---------------|
| `read img.jpg` | pi `read` tool | ❌ display-only | 0 | Pixel-perfekt (TUI Image component, bis zu 80x24 cells); chafa-Fallback für ASCII-Terminals |
| `read img.jpg` | pi `read` tool, mode=`view` | ❌ shared display | 0 | throway URL + Browser (klickbar für User) |
| `viewimg img.jpg` | CLI `~/.local/bin/viewimg` | ❌ display-only | 0 | chafa ASCII-Block-Art (max 60x30 Blöcke) |
| `generate_image` | pi `generate_image` tool | ❌ display-only | 0 | Pixel-perfekt (TUI Image component); ASCII-Preview in chafa-Terminals |
| MCP screenshots | pi tool_result handler | je nach mode | je nach mode | Pixel-perfekt (TUI) oder throway URL (view mode) |

**Kernregel:** `read img.jpg` ist die kanonische Methode, um Bilder anzuzeigen. Sie ist:
- **Pixel-perfekt:** Nutzt das TUI `Image` component (Kitty, iTerm2, Ghostty, WezTerm, Warp)
- **Automatisch:** chafa-Fallback für ASCII-Terminals (kein `chafa`-Install nötig)
- **Nahtlos:** Bei `understand:true` oder explizitem VLM-Request sofort weitergeleitet
- **Null-Abhängigkeit:** Funktioniert mit jedem pi-Install

### VLM-Axis (Verstehen, kostet Tokens)

| Tool/Command | Was es tut | wann nutzen |
|--------------|------------|-------------|
| `read_image` (tool) | Lädt VLM-Analyse, User sieht Bild inline | Wenn User "analysiere", "beschreibe", "extrahiere Text" |
| `/readimg` (command) | Slash-Command für VLM-Analyse | Wenn User explizit ein Bild verstehen will |
| `read img.jpg` mit `understand:true` | Pi-leitgedanke: `read` zeigt → `read understand:` versteht | Wenn Agent selbst "verstehen" entscheidet |
| `read img.jpg` mit `understand:"..."` | Fokus-Query direkt ans VLM (kein Compressor) | Schnellschuss für gezielte Fragen |

**Kernregel:** Verstehen ist immer **explizit**. `read img.jpg` feuert nie autonom VLM-Subcalls.

---

## Überlappungsanalyse

### `viewimg` vs `read img.jpg` — die volle Überlappung

| Feature | `viewimg` (deprecated) | `read img.jpg` (canonical) | Überlappung |
|---------|------------------------|---------------------------|-------------|
| Einzelbild anzeigen | ✅ chafa ASCII-Art | ✅ Pixel-perfekt (TUI) + chafa-Fallback | **Voll** — beide zeigen Bild an |
| Batch (multiple files) | ✅ `viewimg a.jpg b.jpg c.jpg` | ❌ (nicht als CLI-Befehl) | **viewimg-unique** |
| `--open` Preview | ✅ Alle in EINEM Fenster | ❌ (macOS: `open -a Preview *.jpg`) | **viewimg-unique, aber 1-Liner** |
| `--size WxH` | ✅ chafa-Auflösung konfigurierbar | ❌ (TUI auto-sized) | **viewimg-unique, aber TUI ist smarter** |
| `--no-color` | ✅ ASCII ohne ANSI | ✅ (chafa-Fallback hat auch Modus) | **Voll** |
| Terminal-Rendering | chafa direkt, 60x30 Blöcke | TUI Image component, 80x24 cells; chafa fallback | **read überlegen** |
| Abhängigkeit | chafa + open | Keine (TUI-Mechanismus integriert) | **read überlegen** |
| VLM-Weiterleitung | ❌ separater Befehl nötig | ✅ `read understand:true` nahtlos | **read überlegen** |

### `viewimg` vs `read_image` — komplementär, nicht überlappend

| | `viewimg` | `read_image` |
|--|-----------|--------------|
| **Zweck** | Zeigen (display-only) | Verstehen (VLM-Analyse) |
| **VLM?** | ❌ Nein | ✅ Ja |
| **Tokens** | 0 | Kosten (Compressor + VLM) |
| **Output** | Terminal/Bild | Text-Analyse (VLM-Output) |
| **Status** | Deprecated | Canonical |

**Diese beiden feuern NIE gleichzeitig.** Wenn der User "zeige mir das Bild" → `viewimg`/`read`. Wenn der User "beschreibe/diagnostiziere/analysiere das Bild" → `read_image`/`/readimg`.

### `viewimg` im Agent-Workflow

Die xmodel Extension sagt es explizit (xmodel.ts):

```
NEVER call read_image autonomously right after a plain `read`/`viewimg` — those are display-only and fast, and running the VLM is slow and costs tokens.
If the user just asks to read/view/show an image, use read/viewimg and do nothing more.
Use thinking:'high' only when the user asks for deep/thorough image analysis.
```

Der Agent-Protokoll-Notiz im System-Prompt:

```
[xmodel image protocol] `read` on an image file is DISPLAY-ONLY: the user sees it inline, you do NOT receive the pixels. When — and only when — understanding the image's contents is required for the task (the user asks about it, or you must extract text / diagnose a chart), call `read` again with the extra parameter `understand: true`...
```

`viewimg` wird hier parallel genannt, ist aber **technisch unabhängig** — es hat keine Integration in die read-Pipeline.

---

## Warum deprecatsen?

### 1. Redundanz

`read img.jpg` macht alles, was `viewimg` kann — und mehr.

### 2. Technische Überlegenheit von `read`

- **Pixel-perfekt** vs. ASCII-Block-Art (TUI Image component > chafa Blöcke)
- **Keine Abhängigkeit** (chafa muss installiert werden; TUI ist built-in)
- **Nahtlose VLM-Brücke** (`read understand:true` vs. separater `read_image` Befehl)
- **Automatisches Rendering** (TUI passt Größe; `viewimg` braucht `--size`)

### 3. Kontext-Reduktion

Jeder extra Skill = mehr System-Prompt-Token, mehr Routing-Wettbewerb, mehr Verwirrung.

### 4. Konsistenz

`read img.jpg` ist die kanonische pi-Methode. Extra CLIs für dasselbe erzeugen Inkonsistenz (wann nutzt man welchen Befehl?).

---

## Migration Guide

### Single Image

```bash
# Old (deprecated)
viewimg screenshot.png

# New (canonical)
read screenshot.png
```

### Multiple Images (Batch)

```bash
# Old (deprecated)
viewimg a.png b.png c.png --open

# New (macOS)
open -a Preview a.png b.png c.png

# New (Linux)
eog a.png b.png c.png  # oder xdg-open *.png
```

### Custom Size/Rendering

```bash
# Old (deprecated)
viewimg img.jpg --size 40x20 --no-color

# New (canonical)
read img.jpg  # TUI auto-sized; chafa-Fallback für ASCII-Terminals automatisch
```

### VLM-Verständnis

```bash
# Viewimg-Workflow (deprecated)
viewimg img.jpg           # Zeigen
read_image img.jpg        # Dann separat analysieren

# Read-Workflow (canonical)
read img.jpg              # Zeigen
read img.jpg              # Dann:
  understand: "Diagnose UI-Fehler im Header-Bereich"
# (oder agent ruft read_image img.jpg auf — gleicher Effekt)
```

---

## Legacy-CLI: `~/.local/bin/viewimg`

Die Shell-Kommando-Installation bleibt optional. Falls du `viewimg` als CLI-Befehl weiterhin nutzen willst:

```bash
cd skills/viewimg && bash install.sh
```

Die Skript-Logik ändert sich nicht — aber der Skill wird nicht weiterentwickelt.

**Empfehlung:** Kein `install.sh` laufen lassen. `read img.jpg` ist der Kanon.

---

## Timeline

| Phase | Wann | Status |
|-------|------|--------|
| Deprecated | 2026-09-14 | Jetzt — `viewimg` im SKILL.md markiert, Doku aktualisiert |
| Entfernt | künftiger Release | `skills/viewimg/` wird gelöscht, `~/.local/bin/viewimg` entfernt |
| Breaking Change | — | Alle Referenzen bereinigt, Tests gelöscht |

---

## References

- [SKILL.md](../skills/viewimg/SKILL.md) — deprecated skill definition
- [xmodel.md](../extensions/xmodel.md) → Vision Pipeline & read-protocol
- [xmodel.ts](../extensions/xmodel.ts) — read handover, view modes, VLM delegation
- [AGENTS.md](../AGENTS.md) → Agent Protokoll-Notiz im System-Prompt
