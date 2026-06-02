---
name: youtube
description: "Search YouTube videos via Invidious API with automatic instance fallback. Use when the user wants to find, search for, or look up videos, or asks for video recommendations on a topic."
metadata:
  author: skale
  version: "1.0.0"
---

# YouTube Search

```bash
youtube "clojure macros"
youtube "rust lang" --rank views
youtube "artificial intelligence" --num 5 --rank date -v
```

## Install

**Linux / macOS (bash):**
```bash
bash install.sh
```

**Windows (cmd):**
```cmd
install.bat
```

## Usage

| Command | Description |
|---------|-------------|
| `youtube "query"` | Search, top 3 results |
| `youtube "query" --num 10` | Return 10 results |
| `youtube "query" --rank views` | Sort by views/date/rating/relevance |
| `youtube "query" -v` | Verbose (show instance used) |
| `youtube --discover` | Find working Invidious instances |

## Options

| Flag | Default | Description |
|------|---------|-------------|
| `--num N` | 3 | Number of results |
| `--rank` | relevance | Sort: relevance, date, views, rating |
| `-v, --verbose` | off | Show which instance is used |
| `--discover` | off | Re-discover instances from api.invidious.io |

## How It Works

1. Checks cached instances (`.instance-cache.json`, 4h TTL)
2. Falls back to `https://api.invidious.io/instances.json` discovery
3. Falls back to hardcoded instances
4. Tries each in order until one returns results

No API key needed. Uses the public Invidious API.

## Output

Each result is a markdown link:

- [**Clojure Tutorial**](https://invidious.materialio.us/watch?v=ciGyHkDuPAE) by Derek Banas - 175K views - 8 years ago - Duration: 1:11:23

## Troubleshooting

| Issue | Fix |
|-------|-----|
| "all instances failed" | `youtube --discover` to refresh |
| No results | Try different keywords |
| Slow first run | Normal — discovers instances, then caches |

## API Reference

- Instances: https://api.invidious.io/instances.json
- Docs: https://docs.invidious.io/api/
- Search: `GET /api/v1/search?q=...&type=video&sort_by=relevance`
