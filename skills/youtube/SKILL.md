---
name: youtube
version: "1.1.0"
description: "Search YouTube for fresh, long, deep content — podcasts, lectures, and deep dives — ranked by a combined recency+views+duration+relevance score (defaults to longform 20min+, last 18 months, 1K+ views). Use when the user wants to find videos, get recommendations, or look up a topic on YouTube. Triggers on: YouTube search, find a video, video recommendations, find a podcast or lecture, deep dive on."
---

# YouTube Search

Defaults to finding the kind of video you actually want to watch: **fresh, long, on-topic, with traction**. Not 3-minute explainers.

```bash
youtube "rust async programming"          # fresh longform, deep-ranked
youtube "AI agents deep dive podcast"     # finds podcasts/lectures
youtube "rust async" --rank views         # raw: pure view sort (legacy)
youtube "AI agents" --fresh 3m            # last 3 months only
youtube "rust async" --any-length         # include shorts
```

## Install

```bash
bash install.sh        # Linux/macOS
install.bat            # Windows
```

No API key. Uses the public Invidious API with automatic instance fallback.

## Deep Mode (default)

Fetches a large candidate pool, filters by freshness + views + duration, then re-ranks with a combined score:

| Factor | Weight | How |
|--------|--------|-----|
| Recency | 0.35 | Exponential decay, 6-month half-life |
| Views | 0.25 | Log-scale: 1K→0.50, 1M→1.0 |
| Duration | 0.15 | 30min→0.5, 60min+→1.0 (rewards longform) |
| Relevance | 0.25 | API rank position |

**Default filters:** longform (≥20min), last 18 months, ≥1K views.

| Flag | Default | Description |
|------|---------|-------------|
| `--num N` | 5 | Results to return |
| `--fresh SPEC` | 18m | Max age: `3m`, `6m`, `1y`, `2w`, `14d`, `all` |
| `--min-views N` | 1000 | View count floor |
| `--any-length` | off | Include shorts (disable longform filter) |
| `-v` | off | Show mode, instance, scores |

## Raw Mode

`--rank` disables deep mode and returns results in single-dimension API order:

```bash
youtube "query" --rank relevance    # YouTube's default
youtube "query" --rank views        # most viewed
youtube "query" --rank date         # newest
youtube "query" --rank rating       # highest rated
```

## Gotchas

- **Invidious `duration` API filter is leaky** — shorts slip into `duration=2` (long). Deep mode re-checks duration client-side; raw mode does not.
- **Invidious `date` param is unreliable** across instances (returns stale results regardless of value). Deep mode filters freshness client-side instead.
- **Fewer results than `--num`?** Deep mode filters aggressively. If only 4 of 20 candidates pass, you get 4. Use `--fresh all`, `--any-length`, or lower `--min-views` to widen.
- **"all instances failed"** → run `youtube --discover` to refresh the instance cache (4h TTL).
- **Watch links point to the Invidious instance, not youtube.com.** Swap the host if you need native YouTube links.

## How It Works

1. Instance resolution: cache (`.instance-cache.json`, 4h TTL) → discover via `api.invidious.io` → hardcoded fallbacks
2. Search: `GET /api/v1/search?q=...&type=video&sort_by=relevance&duration=2`
3. Deep mode: filter (views/duration/age) → score → sort → return top N
4. Each instance is tried in order until one returns valid results
