# Watchlist — Skills & Extensions Worth Reviewing or Installing

> Personal capture list for external skills and pi extensions. Two phases:
> **jot it down** (one line, fast) → **review later** (verdict + status change).
> This file is NOT part of the pi package manifest — it stays personal.

## How to add

Append **one line** at the end of the list:

```
- [👀] skill: <name> — <org/repo or install cmd> — <why, one line> — <added YYYY-MM-DD>
```

- Ask the agent in chat: `watchlist add <org/repo> — <why>` (it knows this file
  from AGENTS.md and appends the line for you)
- Or append it yourself in the editor — it's a flat list, no alignment pain

## Status lifecycle

| Status | Meaning |
|--------|---------|
| 👀 | watch — captured, not reviewed yet |
| 🔍 | in review — being evaluated |
| ✅ | adopted — installed / ideas merged (verdict note below the line) |
| ❌ | rejected — not for us (verdict note says why, so we don't rediscover it) |

Review flow: ask a session to "review the watchlist" — it fetches each entry's
repo/SKILL.md, writes a 2-3 line verdict under the entry, and flips the status.
✅ entries with an install command double as the recommendation list.

---

## Entries

- [🔍] skill: mattpocock improve-codebase-architecture — `~/code/agents/skills/mattpocock-skills` (local clone) — ideas already harvested into visualize (diagram vocabulary, report rules) — 2026-10-04
  > Verdict pending: check the rest of the repo for more adoptable patterns beyond HTML-REPORT.md.

- [👀] skill: emilkowalski/skills — github.com/emilkowalski/skills — ~42k★ animation/UI/mobile craft — styling reference for visualize/improve-ux, worth a curated pick — 2026-10-04

- [👀] skill: pi-web-access package (librarian) — see [docs/pi-web-access.md](docs/pi-web-access.md) — third-party pi package providing web research skills; overlap with our web-search/fetch-url needs a check before considering — 2026-10-04
