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

![web-search flow](diagrams/web-search.svg)

`web-search` **auto-selects a backend**: **SearXNG** by default (a public instance out-of-the-box, or a private one via `credgoo searx`), with the **Duck API** as an optional path for advanced filters (`credgoo WEB_SEARCH_BEARER`). Returns titles + URLs.

**Flow:** agent → `web-search` → {SearXNG (auto-select), Duck API (optional)} → results.

Source: [`diagrams/web-search.d2`](diagrams/web-search.d2) · Skill: [`skills/web-search`](../skills/web-search)

---

## fetch-url

![fetch-url flow](diagrams/fetch-url.svg)

`fetch-url` **auto-selects the best tool** and falls back gracefully: local **terminal browsers** (`w3m` / `lynx` / `chawan`) for the common case, an optional **reader API** (`credgoo FETCH_URL_BEARER`) for hard pages. Returns readable text.

**Flow:** agent → `fetch-url` → {terminal browsers (auto-select), reader API (fallback)} → page → readable text.

Source: [`diagrams/fetch-url.d2`](diagrams/fetch-url.d2) · Skill: [`skills/fetch-url`](../skills/fetch-url)

---

## surf

![surf flow](diagrams/surf-flow.svg)

`surf` drives your **real, logged-in Chrome** through macOS AppleScript — **no debug port, no extension, no per-connection "Allow remote debugging?" dialog**, zero dependencies. Commands map to AppleScript `execute javascript` / tab control.

**Flow:** agent → `surf` (bash CLI) → `osascript` → Google Chrome (real session) → result (text / JSON / screenshot).

Source: [`diagrams/surf-flow.d2`](diagrams/surf-flow.d2) · Skill: [`skills/surf`](../skills/surf) · Guide: [`browser-use/surf.md`](browser-use/surf.md)
