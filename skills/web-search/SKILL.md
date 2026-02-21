---
name: web-search
description: Perform DuckDuckGo web searches with rich filters including domain, filetype, and URL fragment operators, exclusion lists, region settings, and pagination. Use when the user wants to search the web for information, find documentation, or look up facts.
compatibility: Requires requests library and WEB_SEARCH_BEARER token
---

# Web Search (DuckDuckGo)

## Quick Start

```bash
cd <skill-dir>
uv run scripts/search.py "query" [options]
```

**Setup:** Set `WEB_SEARCH_BEARER` env var, or use credgoo with service `web-search`, or create `.env` file with `WEB_SEARCH_BEARER=your_token`.

## Common Patterns

```bash
# Documentation
uv run scripts/search.py "react hooks" --site react.dev

# PDFs/papers
uv run scripts/search.py "ML transformers" --filetype pdf

# Recent news
uv run scripts/search.py "AI news" --timelimit d

# Exclude noise
uv run scripts/search.py "python tutorial" --exclude youtube,video

# Error messages
uv run scripts/search.py "TypeError NoneType" --exact --site stackoverflow.com
```

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `--max` | 10 | Maximum results |
| `--page` | 1 | Page number |
| `--site` | - | Filter by domain |
| `--filetype` | - | Filter by extension (pdf, doc, etc.) |
| `--inurl` | - | URL must contain text |
| `--exclude` | - | Comma-separated terms to exclude |
| `--timelimit` | - | d (day), w (week), m (month), y (year) |
| `--region` | wt-wt | Region code (us-en, de-de, etc.) |
| `--backend` | duckduckgo | Provider: google, bing, brave, wikipedia |
| `--exact` | false | Exact phrase matching |

## Output

Markdown with clickable links:
```markdown
- [**Title**](https://url.com)
  Description snippet...
```

## Reference

For detailed patterns, backends, and troubleshooting, see [references/INDEX.md](references/INDEX.md).
