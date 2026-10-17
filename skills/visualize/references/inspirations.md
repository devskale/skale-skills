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

> More inspirations to be added later.
