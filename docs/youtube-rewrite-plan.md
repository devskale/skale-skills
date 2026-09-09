# Rewrite plan: youtube skill → yt-dlp backend

**Status:** proposed, not started. The current Invidious backend works but is
running on a dying ecosystem; this plan is the agreed escape route when it
becomes untenable.

## Why rewrite

Measured 2026-09: only **2 of 15** known public Invidious instances answered a
search request; the official registry (api.invidious.io) served **0 of 7**
(403/blocked). The self-heal (evict/promote/merge, see SKILL.md) mitigates this
but cannot create healthy instances that don't exist.

yt-dlp, by contrast, is actively maintained (it powers the `vtd` skill
reliably) and scrapes YouTube directly — no third-party instance roulette.

## Measured timings (2026-09, yt-dlp 2026.07)

| Operation | Time | Notes |
|---|---|---|
| `ytsearch30` flat (`--flat-playlist --dump-json`) | **~2.4s** | 30 entries, full metadata except dates |
| Full extraction per video (`--dump-json`, no flat) | ~5.6s/video | has exact `upload_date`/`timestamp` |

## Field mapping (Invidious → yt-dlp)

| Invidious | yt-dlp | Used by |
|---|---|---|
| `videoId` | `id` | entry_line, list parsing |
| `title` | `title` | everywhere |
| `author` | `channel` / `uploader` | entry_line, exclude |
| `authorId` | `channel_id` | fav/block, `ucid:` token |
| `viewCount` | `view_count` | filters, scoring |
| `lengthSeconds` | `duration` | filters, scoring |
| `published` (unix) | `timestamp` / `upload_date` | age filter, recency score |
| `isAgeLimited` | `age_limit > 0` | 🔒 age-restricted label |

## Two-stage architecture (the core idea)

Dates are the only field missing from fast flat search — and they're needed
for the `--fresh` filter and recency scoring. Solution: extract them only for
survivors.

1. **Stage 1 — pool (~3s):** `ytsearch{pool}` flat → hard filters that don't
   need dates (min_views, min/max duration, blocked/excluded channels)
2. **Stage 2 — dates (gezielt):** full extraction **only of survivors**
   (usually ≤10 after the strict defaults) → age filter + recency scoring →
   final rank → picks/candidates

Optional pre-filter: YouTube's own upload-date buckets via search URL `sp`
parameter (`EgIIAg==` today, `EgIIAw==` week, `EgIIBA==` month, `EgIIBQ==`
year) — coarser than `--fresh 3m` but free; Stage 2 then verifies exactly.

## Porting checklist

- [ ] `search_instance()` → subprocess `yt-dlp --flat-playlist --dump-json "ytsearch{pool}:…"`
- [ ] `search_channel()` → `yt-dlp --flat-playlist https://www.youtube.com/@handle/videos`
- [ ] `resolve_channel()` → flat search match on `channel_id`, or `@handle` extraction
- [ ] `get_related()` / `expand --like` → channel from stored `ucid:` → `@handle/videos` (Invidious `/videos/{id}` already deprecated in docs)
- [ ] `do_search()` → two-stage flow above
- [ ] `_is_age_restricted()` → `age_limit > 0`
- [ ] Concurrency: Stage 2 survivors can be extracted with a small thread pool (stdlib)
- [ ] Dependency note: requires `yt-dlp` on PATH (vtd's install.sh already ships it); drop the "zero dependencies" claim from SKILL.md
- [ ] Tests: keep unit tests (field mapping shim), rewire live smoke tests; timing tolerance up
- [ ] Keep `--discover` as a deprecated no-op or remove (announce in SKILL.md)

## Fallback considered and rejected

- **Piped API**: same dying-ecosystem profile as Invidious.
- **YouTube Data API**: reliable but needs an API key (credgoo) and costs 100
  units/search (100/day free tier) — fine as a credgoo-optional fallback, not
  the default.
