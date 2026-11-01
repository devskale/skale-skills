# Inspirations

Projects, tools, and techniques worth studying for the `fetch-url` skill — extraction
engines, readability approaches, and page-content strategies we want to borrow from,
compare against, or one-up. Add to this list as we find them.

## [Defuddle](https://github.com/kepano/defuddle)

**"Get the main content of any page as Markdown."** MIT, ~9.7k★, by Steph Ango (Obsidian CEO).
The extraction engine behind the Obsidian Web Clipper; runs in browser, Node (JSDOM/linkedom/happy-dom),
and CLI (`npx defuddle parse <url|file|stdin> [--markdown|--json]`). Positions itself as a
more-forgiving [Mozilla Readability](https://github.com/mozilla/readability) replacement.

**Why it's here:** fetch-url's local-first chain (w3m → lynx) renders the *whole* page and then
strips noise with regexes — Defuddle instead *finds the main content* in the DOM and discards
the rest. That is a structurally different (and often better) approach, fully local and free,
no third-party API call like jina/markdown. Verified live (2026-10): on a GitHub repo page,
`curl | npx defuddle parse --markdown` returns the clean README while w3m returns 8 KB of nav
chrome; on a simple blog it returns just the article prose.

**Steal / compare:**
- **Local extraction quality:** benchmark `curl -L <url> | npx defuddle parse --markdown`
  against w3m/lynx/jina on our reference sites (`references/sites.md`) — where does each win?
  Defuddle's GitHub handling (README-only) alone would beat our current w3m GitHub output.
- **Mobile-styles heuristic:** it uses a page's mobile styles to guess non-essential elements —
  a trick our noise-stripping could borrow conceptually.
- **Metadata:** extracts title/author/schema.org alongside content — could feed fetch-url's
  verbose output or a future `--json` mode.
- **Integration path:** a `defuddle` tool option in `scripts/fetch.py` (curl + npx, local,
  free) as a strong fallback between local browsers and cloud APIs — needs Node/npx present,
  so platform-gate it like w3m/lynx. No JS rendering, so it stays behind `chrome` for
  Cloudflare/JS-walled sites.

---

## apisniffer (local: `~/code/clones/apisniffer/`)

**Anti-bot SOTA survey + API-sniffing playbook** (local clone, not on GitHub). Decision tree:
TLS/JA4 (curl_cffi) → JS-challenge solver (node vm-Sandbox) → real browser (surf /
nodriver / Camoufox). Live-tested 2026-10 against our benchmark failure sites.

**Why it's here:** the fetch layer of fetch-url (curl / requests) is exactly where
apisniffer's #1 lesson bites — TLS-fingerprint blocking. Their docs rate TLS/JA4 the
most common block cause of 2026.

**Live-test verdict (2026-10, our IP):** our actual benchmark failures (Medium,
StackOverflow, Reddit) are all **JS-shell cases, not TLS cases** — curl_cffi gets 200
but empty shells. TLS impersonation alone doesn't fix them; only a browser does.
Still: our IP is currently clean on classic Cloudflare test sites, so TLS blocks are
a robustness concern, not an active pain.

**Steal / compare:**
- **curl_cffi as fetch layer** for the defuddle path (`curl_cffi.impersonate='chrome' |
  npx defuddle parse --markdown`) — local, installed (0.16.3), free, makes the whole
  chain immune to future TLS/JA4 gates. Cheap swap, no downside.
- **nodriver as stronger `chrome` tool** — system Chrome via raw CDP, no Playwright
  automation fingerprint; 2026 benchmark winner (28/31 targets, 0 blocks). Installed
  (pip 0.50.3). Upgrade path when `chrome --headless=new --dump-dom` starts getting
  detected. AGPL — fine for a local skill, not for a service.
- **CLASSIFY-first discipline** — fetch.py's error patterns already detect *that* a
  fetch is blocked; apisniffer's pattern is to classify *which layer* (TLS vs
  JS-challenge vs cookie-wall) and pick the tool accordingly. Worth folding into
  the fallback chain's error handling.
- **Confirmed live:** jina anonymous access gets abuse-blocked per-domain (403,
  github.com blocked for days) — another argument for defuddle-first on GitHub.

---

> More inspirations to be added later.
