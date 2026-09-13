# Routing — build inline vs. recommend d2 / figure

`visualize` builds its own simple diagrams inline (SVG arrows, optional Mermaid) — good
for a small graph embedded in a page. But some challenges are **better served by `d2`
(auto-laid-out technical diagrams) or `figure` (hand-drawn presentation figures)**. Both
are manual-only (`/skill:d2` / `/skill:figure`), so `visualize` **recommends and stops** —
don't build a weak inline version. Decide **live per request**, re-reading the
`d2`/`figure` descriptions (in the system-prompt catalog) each time.

## Decision

- **→ `d2`** — complex technical graphs: sequence / ER / class diagrams; dependency or
  call graphs with many nodes and edges (elk auto-layout handles the density, inline SVG
  tangles); diagrams that must be self-verifiable (d2 renders ASCII) or are the
  deliverable (committed `.svg`/`.png`/`.pdf`), not just one element in a throwaway page.
- **→ `figure`** — hand-drawn presentation figures: sketchy Excalidraw-style explainers,
  polished figures for a slide / report / deck.
- **→ inline** — the diagram is simple (a few nodes), *one element among many*, and the
  user wants a quick shareable page. Don't bounce trivial graphs to d2/figure.

## Pattern-aware tripwire

See [patterns.md](patterns.md): a pattern that is *at heart a dense technical graph* —
fan-in queue, trust boundary, long write-back loop — belongs in `d2` when the graph is
the point, not one panel among many. A pattern whose value is the *editorial sketch* —
stage framework as a deck figure, provenance trail — belongs in `figure`. If the real
content exceeds the pattern's complexity budget, that's the signal to hand it off.
[promptlib §10](promptlib.md) has the same routing as a per-pattern table.

## How to recommend

End the page with one line, e.g. *"This graph is complex — for a proper auto-laid-out
diagram, run `/skill:d2`; for a hand-drawn figure, `/skill:figure`."* Don't
over-recommend.
