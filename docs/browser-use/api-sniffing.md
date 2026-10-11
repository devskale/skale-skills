---
name: api-sniffing
description: "API sniffing without a browser — three headless patterns distilled from real reverse-engineering sessions (2026-10): server-side GET query filters (FALTER), Livewire/HTMX component-state replay (FALTER POST), and node vm-Sandbox JS-challenge solving (FirmenABC). When plain curl beats every browser tool. Triggers on: sniffing an API, reverse-engineer endpoint, site has no API, livewire replay, anti-bot JS challenge headless, curl_cffi impersonate."
version: 0.1.0
date: 2026-10-12
---

# API Sniffing Without a Browser

> Distilled from two real sniffing sessions (2026-10-11/12, apisniffer repo):
> FALTER.at events and FirmenABC.at. Patterns we reproduced end-to-end, not
> theory. The core insight: **most "no API" sites have one — you just have to
> find the server-rendered surface or replay the component protocol.**

Companion to the tool ladder: these patterns sit *below* the browser rung —
when they work, you never open Chrome at all.

```
plain HTTP / fetch-url  →  GET-query discovery  →  component replay (Livewire)  →  JS-challenge solve (node vm)  →  w3m -dump  →  rodney / surf
```

---

## Pattern 1: Server-side GET query filters ("the hidden API")

Many server-rendered sites (Laravel, TYPO3, classic CMS) filter **directly in
the query string** — the search form is just a GET form. No JSON endpoint
exists, but the HTML response *is* the API.

**Found on FALTER.at** (`/events/suche`): the whole filter UI (region,
category, date, free/tickets flags) submits as GET params, and the server
renders the filtered list. A single curl gets you a filterable dataset:

```
GET https://www.falter.at/events/suche?region=Wien&is_free=true&katid[0]=22&span=2026-10-12:2026-10-12
```

**How to find it:**
1. Submit the site's search form in your head: `<form method="GET">`? → the
   action URL + field names *are* the API.
2. Look at `wire:effects` / Alpine `x-model` bindings for the field names
   (e.g. `x-model="filter.span"` → query param `span`).
3. Copy a URL from the site's own UI (pagination links, category links) —
   whatever the site links to itself is a stable, server-supported surface.

**Gotchas we hit:**
- **Format quirks are per-site and undocumented.** FALTER's date range is
  `span=START:ENDE` with a **colon** (not comma, not two params). Category
  arrays are `katid[0]=13&katid[1]=35`. Booleans are `true` (not `1`).
- **Pagination can 404** past the last page instead of returning empty —
  treat 404 on `page=N` as "end of results".
- **Some filters do nothing.** FALTER's `termintypid` is accepted, echoed in
  state, and has zero effect. Validate each filter with a diff-control
  (same query with and without; identical results = dead parameter).

**Validation discipline:** for every claimed filter, run one A/B — same
request with and without the parameter, diff the result sets. One green diff
per parameter, no more.

---

## Pattern 2: Component-state replay (Livewire v3, generalizes to HTMX)

When a site is a Laravel + **Livewire** (or Alpine.js) app, the "API" is a
component-state protocol. The page ships its full component state as JSON in
a `wire:snapshot` attribute; interactions POST `{snapshot, updates, calls}`
back and receive re-rendered HTML + new state.

**Found on FALTER.at:**

```
1. GET the page → collect:
   - window.livewireScriptConfig = {csrf, uri}     ← endpoint + CSRF
   - wire:snapshot attributes (one per component)
2. POST {uri} with JSON:
   {components: [{snapshot, updates: {"filter.term": "konzert"}, calls: []}]}
3. Response: components[0].effects.html (rendered list)
             components[0].snapshot   (new state — chain for pagination)
```

**The three traps that cost us the most time:**

1. **The endpoint is obfuscated.** Not `/livewire/update` but
   `/livewire-7d56c2c5/update`. It lives in `window.livewireScriptConfig.uri`
   — always read it from the page, never guess. (Anti-scraper measure.)
2. **CSRF + session cookie are mandatory.** No cookie/CSRF → HTTP 500 with an
   error page (misleading; looks like a broken payload). Grab cookies from the
   initial GET, CSRF from the page source.
3. **Update paths use the logical, not the serialized shape.** Snapshot data
   stores `filter` as a tuple `[value, meta]`, but updates address it as
   `filter.term` — Livewire unwraps the tuple itself. Wrong path (`filter.0.term`)
   is *silently ignored*: HTTP 200, no error, filter just doesn't apply.
   Always verify the filter value landed in the returned snapshot.

**Pagination:** chain the returned `snapshot` into the next request with
`calls: [{"method": "nextPage", "params": []}]`.

**When to prefer this over Pattern 1:** only when the GET surface doesn't
exist or doesn't expose the filter you need. Livewire replay is strictly more
fragile (endpoint hash changes on deploys, checksums, state chaining).

---

## Pattern 3: JS-challenge solving in a node vm-Sandbox

Anti-bot interstitials ("Einen Moment…", 429 + obfuscated script) are usually a
JS challenge that computes a cookie value. You don't need a browser to solve
them — a **node `vm` sandbox** runs the challenge script and prints the cookie.

**Found on FirmenABC.at** (Kasada-style challenge):

```
curl_cffi (impersonate="chrome")  →  429 + challenge HTML
   ↓
node vm-Sandbox: run the challenge <script>, extract computed cookie
   ↓
curl_cffi with Cookie header  →  200, full site access — no browser ever opened
```

**Recipe:**
1. **curl_cffi with `impersonate="chrome"`** — fixes the TLS/JA3 fingerprint
   layer. Plain `curl` fails even with a browser User-Agent; curl_cffi passes.
2. Fetch the challenge page, extract the `<script>` body.
3. Run it in `node vm.runInNewContext(script, {document: stub, location: stub, ...})`
   — the script sets `document.cookie` or computes a token; capture it.
4. Retry the original request with the cookie. **Challenges are often
   time-limited** — on 429 re-solve and retry (×2), don't cache the cookie
   indefinitely.

**Working implementation:** `experiments/spisniff/scripts/firmenabc_solver.js`
(25 lines) + `firmenabc_client.py` — 7/7 fixture tests green, fully headless.

**Limits:** this solves *cookie/token challenges*. Heavier anti-bot
(Kasada PoW with per-request tokens, PerimeterX behavioral scoring, Turnstile)
needs a real browser context — fall back to `surf eval` / `evaluate_script`
(fetch inside the logged-in page, `credentials: "include"`).

---

## The meta-pattern: read the page source before opening a browser

Every session above started the same way — and the browser was the *last*
resort, not the first:

1. **`curl` the page, read the HTML.** Look for:
   - `<form method="GET">` → Pattern 1 (query-string API)
   - `wire:snapshot` / `x-data` / `data-*` bindings → Pattern 2 (component replay)
   - `window.livewireScriptConfig`, `window.__NUXT__`, `__NEXT_DATA__` → embedded state + endpoint config
   - obfuscated `<script>` on a 429/403 → Pattern 3 (challenge)
2. **Baseline first**: does the obvious URL already give you what you need?
   (FALTER's `/events/suche?katid[0]=35` was one curl away the whole time — we
   built the whole Livewire replay before noticing the GET form.)
3. **Only then** reach for a browser — and prefer `evaluate_script`-style
   fetches in page context over full-page snapshots (cheap, JSON, cookies
   included automatically).

## Related docs

- [terminal-browsing.md](terminal-browsing.md) — the agent ladder (where these patterns sit)
- [which-browser-tool.md](which-browser-tool.md) — when you *do* need a browser
- [browser-tools-comparison.md](browser-tools-comparison.md) — full tool matrix
- apisniffer repo: `experiments/spisniff/2026-10-12-falter-events/`, `experiments/spisniff/2026-10-11-firmenabc/` (working code, tests, captures)
