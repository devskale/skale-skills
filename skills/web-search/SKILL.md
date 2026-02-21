---
name: web-search
description: Perform web searches with rich filters including domain, filetype, and URL fragment operators, exclusion lists, region settings, and pagination. Use when the user wants to search the web for information, find documentation, or look up facts.
compatibility: Requires requests library and WEB_SEARCH_BEARER token
---

# Web Search (DuckDuckGo)

## Quick Start

```bash
cd <skill-dir>
uv run scripts/search.py "query" [options]
```

**Setup:** Set `WEB_SEARCH_BEARER` env var, or use [credgoo](https://github.com/devskale/python-openutils/tree/main/packages/credgoo) with service `web-search`, or create `.env` file with `WEB_SEARCH_BEARER=your_token`.

## Options

| Option        | Default    | Description                                    |
| ------------- | ---------- | ---------------------------------------------- |
| `--max`       | 10         | Maximum results                                |
| `--page`      | 1          | Page number                                    |
| `--site`      | -          | Filter by domain (e.g., github.com)            |
| `--filetype`  | -          | Filter by extension (e.g., pdf)                |
| `--inurl`     | -          | Filter by URL fragment                         |
| `--exclude`   | -          | Comma-separated terms to exclude               |
| `--timelimit` | -          | Time range: d, w, m, y                         |
| `--region`    | wt-wt      | Region code (e.g., us-en, de-de)               |
| `--backend`   | duckduckgo | Provider: bing, brave, google, wikipedia, etc. |
| `--exact`     | false      | Exact phrase matching                          |
| `--proxy`     | -          | Proxy URL (e.g., socks5h://127.0.0.1:9150)     |

## Examples

```bash
# Basic
uv run scripts/search.py "rust programming"

# Site-specific
uv run scripts/search.py "async await" --site developer.mozilla.org

# File type + site
uv run scripts/search.py "API docs" --site docs.python.org --filetype pdf

# Time-filtered
uv run scripts/search.py "latest news" --timelimit d

# Exclude terms
uv run scripts/search.py "python tutorial" --exclude youtube,video --max 20

# Alternative backend
uv run scripts/search.py "ai news" --backend google --region us-en

# Exact phrase
uv run scripts/search.py "to be or not to be" --exact
```

## Query Operators

Use directly in query string: `site:`, `filetype:`, `inurl:`, `-term`

## Output

Markdown format with clickable links:

```markdown
- [**Title**](https://url.com)
  Description snippet...
```
