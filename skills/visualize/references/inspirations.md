# Inspirations

Visual references worth studying for the `visualize` skill — projects, pages, and tools
whose design or technique we want to borrow or one-up. Add to this list as you find them.

## [Archify](https://github.com/tt-a1i/archify)

**Agent skill for beautiful, verifiable architecture, workflow, sequence, data-flow, and
lifecycle diagrams — self-contained HTML with motion and crisp export.**
Homepage: <https://tt-a1i.github.io/archify/>

**Why it's here:** overlapping goals with `visualize` — self-contained HTML output, no
external runtime deps, and a strong visual bar. Worth studying for its approach to
diagram motion, crisp export, and how it keeps the output portable.

**Steal / compare:**
- Diagram motion + export quality vs. our inline SVG / Mermaid approach.
- How it structures self-contained HTML for complex diagrams.
- Where it's *better* than us (adopt) and where we're *better* (keep).

---

## [Diagram Design](https://github.com/cathrynlavery/diagram-design)

**29 editorial diagram types for Claude Code. Self-contained HTML + SVG. No shadows, no
Mermaid-slop.**

**Why it's here:** a direct design sibling to `visualize` — self-contained HTML + SVG with
an editorial (not AI-slop) aesthetic. Its "no shadows, no Mermaid-slop" stance lines up
with our own NO-AI-generated-accents principle.

**Steal / compare:**
- The 29 editorial diagram types — which overlap with our module catalog, which are new.
- Its SVG technique and editorial styling vs. our inline SVG / Mermaid.
- How it keeps pages clean and portable without runtime deps.

---

## [Pele](https://pele.run/)

**Mermaid-syntax diagrams as themeable SVG — zero dependencies, 6× smaller, up to 500×
faster than Mermaid.js.** Open source ([obsidianmd/pele](https://github.com/obsidianmd/pele)),
built for Obsidian to render diagrams quickly and match the vault theme. Theming via CSS
variables (`--pele-bg`, `--pele-fg`, `--pele-surface`, …) that recolor without re-render;
supports every diagram type in Mermaid 12.1.0 ([compatibility](https://pele.run/compatibility)).

**Why it's here:** a direct competitor to the Mermaid-by-CDN path our HTML output takes —
and its homepage is itself a strong single-page demo (live editor, honest benchmark table,
editorial warm-paper palette). Both are worth studying.

**Steal / compare:**
- **Theming model:** CSS variables that restyle without re-render vs. our skin tokens —
  naming, granularity, and what they let users override per-diagram.
- **Renderer swap candidate:** 230 kB / 0.05–0.3 ms vs. Mermaid.js 1.6 MB / 6–82 ms —
  where does `pele` from a CDN (or inlined) beat `mermaid` for our self-contained pages?
  Check the [compatibility matrix](https://pele.run/compatibility) for diagram-type gaps first.
- **Homepage craft:** the benchmark table (Pele vs. Mermaid.js) as an honest-comparison
  pattern; live-edit playground as the hero element.

---

## [emilkowalski/skills](https://github.com/emilkowalski/skills)

**„Skills for Designers and Engineers" (~47k ★) — 15 Skills, die Design-Expertise
(Ex-Vercel/Linear) als Agent-Regeln kodieren.** Kernthese: *„Agents don't have great
taste"* — die Skills listen die kleinen Fehler, die Agenten machen (ease-in für Entrances,
solid borders statt semi-transparenter Schatten), und korrigieren sie mit konkreten
Werten. Haupt-Skill: `emil-design-eng` (Animation + Design); dazu `break-ui`, `prototype`,
`mobile-native`, `animate` u.a. — jedes macht ONE thing, mit expliziten Non-Goals und
Sidecar-Dateien (RECIPES · CATALOG · STANDARDS · PICKER).

**Why it's here:** gleiche Grundthese wie unser Slop-Gate — Geschmack als kodierbare
Regeln statt Vibes — aber von der Motion-Seite her gedacht. Ihre Tabellen (Frequenz →
Animieren ja/nein, Element → Dauer, Easing nach Zweck) sind genau unsere Token-Denkweise,
angewandt auf Bewegung; `break-ui` ist das adversariales Gegenstück zu unseren Gates.

**Steal / compare:**
- **Motion-Tokens für interaktive Seiten:** `--ease-out: cubic-bezier(0.23,1,0.32,1)`,
  160ms `:active` scale(0.97), Entrances nie `ease-in`, UI-Motion < 300ms — als
  Rezept-Katalog (deren RECIPES.md) für visualize-Seiten mit Hover/Press-States.
- **break-ui als Content-Gate:** Worst-Case-Daten vor dem Share — plausible Extremwerte
  („Aleksandra Wiśniewska-Kowalczyk", 1.284 Members, „1 members", leere Liste) statt
  Nonsense-Strings; ergänzt chartcheck um die Inhalts-Kante (lange Labels im Diagramm,
  8-Slice-Pie, Extreme-Werte-Skala).
- **prototype's Divergenz-Picker:** bei ambigen Requests 2–3 *echt verschiedene*
  Strukturen bauen (benannte Achsen — „Quiet"/„Editorial"/„Dense", nie drei Tints)
  und durchschalten lassen — Alternative zu unserer „eine präzise Frage"-Regel.
- **Pflicht-Output-Format:** deren Before|After|Why-Tabelle für Reviews → als Format
  für Gate-Fundings (finding · fix · why), maschinenlesbar und lehrreich zugleich.

---

> More inspirations to be added later.
