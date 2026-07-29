# Skill Diagrams

High-level flow diagrams for three core skills. Each ships a **D2 source** (version-controllable) and a rendered **SVG** (self-contained, GitHub-safe). Re-render after editing:

```bash
d2 docs/diagrams/web-search.d2 docs/diagrams/web-search.svg
d2 docs/diagrams/fetch-url.d2  docs/diagrams/fetch-url.svg
d2 docs/diagrams/surf-flow.d2  docs/diagrams/surf-flow.svg
```

> See the repo-wide [`architecture.d2`](architecture.d2) for how these skills fit into the whole package.

---

## web-search

![web-search flow](images/web-search.png)

`web-search` **routes to one of two backends**: **SearXNG** by default (public, zero-config,
or private via `credgoo searx`) — the happy path for text, images, news, and videos; or the
**Duck API** upgrade when a token is present (carries the advanced filters:
`--site`/`--filetype`/`--inurl`/`--exclude`/`--exact`). Media queries always route to
SearXNG even with a token; `--api`/`--searxng` force a backend.

**Flow:** `call` → `select backend` (by flags · token · type) → {SearXNG (default), Duck
API (if token)} → results.

> Hand-drawn figure built with the [`figure`](../skills/figure) skill compositor — source
> [`skills/figure/diagrams/examples/web-search/web-search.fig.mjs`](../skills/figure/diagrams/examples/web-search/web-search.fig.mjs),
> rendered PNG + SVG in [`images/`](images/). Rebuild:
> `cd skills/figure && node build/build_figures.mjs diagrams/examples/web-search/web-search.fig.mjs`
>
> Legacy D2 view: [`diagrams/web-search.svg`](diagrams/web-search.svg) (source
> [`diagrams/web-search.d2`](diagrams/web-search.d2)).

Skill: [`skills/web-search`](../skills/web-search)

---

## fetch-url

![fetch-url flow](images/fetch-url.png)

`fetch-url` **auto-selects the best tool** and falls back gracefully through a **priority
chain**: free local **terminal browsers** (`w3m` / `lynx`) → free **reader APIs** (`jina` /
`markdown`) → **chrome** (headless, for JS-protected sites). On failure it drops to the next
tool (`NO`); on success (`ok`) it extracts and returns clean text.

**Flow:** `call` → auto-select → try tool (1 priority order) → {`ok` → fetch, `NO` → next
tool} → return text.

> Hand-drawn figure built with the [`figure`](../skills/figure) skill compositor — source
> [`skills/figure/diagrams/examples/fetch-url/fetch-url.fig.mjs`](../skills/figure/diagrams/examples/fetch-url/fetch-url.fig.mjs),
> rendered PNG + SVG in [`images/`](images/). Rebuild:
> `cd skills/figure && node build/build_figures.mjs diagrams/examples/fetch-url/fetch-url.fig.mjs`
>
> Legacy D2 view: [`diagrams/fetch-url.svg`](diagrams/fetch-url.svg) (source
> [`diagrams/fetch-url.d2`](diagrams/fetch-url.d2)).

Skill: [`skills/fetch-url`](../skills/fetch-url)

---

## surf

![surf flow](diagrams/surf-flow.svg)

`surf` drives your **real, logged-in Chrome** through macOS AppleScript — **no debug port, no extension, no per-connection "Allow remote debugging?" dialog**, zero dependencies. Commands map to AppleScript `execute javascript` / tab control.

**Flow:** agent → `surf` (bash CLI) → `osascript` → Google Chrome (real session) → result (text / JSON / screenshot).

Source: [`diagrams/surf-flow.d2`](diagrams/surf-flow.d2) · Skill: [`skills/surf`](../skills/surf) · Guide: [`browser-use/surf.md`](browser-use/surf.md)
