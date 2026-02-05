---
name: web-search
description: Perform DuckDuckGo web searches with rich filters including domain, filetype, and URL fragment operators, exclusion lists, region settings, and pagination. Use when the user wants to search the web for information, find documentation, or look up facts.
---

# Web Search (DuckDuckGo)

## Quick Reference

```bash
cd ~/.pi/agent/skills/web-search

# Basic search
uv run search.py "query"

# Filter by site
uv run search.py "query" --site github.com

# Time filtered (d=day, w=week, m=month, y=year)
uv run search.py "query" --timelimit w

# More results
uv run search.py "query" --max 25

# Combine filters
uv run search.py "query" --site docs.python.org --filetype pdf --max 20
```

See **Options** and **Examples** below for advanced usage.

## Setup

### 1. Install Dependencies

```bash
cd ~/.pi/agent/skills/web-search
uv venv
uv pip install -r requirements.txt
```

### 2. Set API Bearer Token

**Option A: Environment Variable** (Priority: 1)
```bash
export WEB_SEARCH_BEARER="your_token_here"
```

**Option B: Credgoo** (Priority: 2 - Recommended for secure credentials)
```bash
uv pip install -r https://skale.dev/credgoo
credgoo web-search --token YOUR_CREDGOO_TOKEN --key YOUR_ENCRYPTION_KEY
```

**Option C: .env file** (Priority: 3)
```bash
echo "WEB_SEARCH_BEARER=your_token_here" > ~/.pi/agent/skills/web-search/.env
```

## How to Search

```bash
cd ~/.pi/agent/skills/web-search
uv run search.py "<query>" [options]
```

Or install as a command:
```bash
uv pip install -e .
web-search "<query>" [options]
```

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `--max` | 10 | Maximum number of results |
| `--page` | 1 | Page number for pagination |
| `--site` | - | Filter to specific domain (e.g., github.com) |
| `--filetype` | - | Filter by file extension (e.g., pdf, txt) |
| `--inurl` | - | Filter by URL fragment |
| `--exclude` | - | Comma-separated terms/domains to exclude |
| `--timelimit` | - | Time range: d, w, m, y |
| `--region` | wt-wt | Region code (e.g., us-en, de-de, fr-fr) |
| `--backend` | duckduckgo | Provider: auto, all, bing, brave, duckduckgo, google, mojeek, yandex, yahoo, wikipedia |
| `--safesearch` | moderate | Safe search level: off, moderate, strict |
| `--exact` | false | Exact phrase matching (wraps in quotes) |
| `--proxy` | - | Proxy URL (e.g., socks5h://127.0.0.1:9150) |
| `--verify` | true | Verify SSL certificates |
| `--api-url` | - | Custom API endpoint URL |
| `--timeout` | 30 | Request timeout in seconds |

### Query Operators

Use DuckDuckGo operators directly in the query string:
- `site:example.com` - Search within a specific domain
- `filetype:pdf` - Search for PDF files only
- `inurl:docs` - Search URLs containing "docs"
- `-term` - Exclude results with this term

## Examples

**Basic usage:**
```bash
uv run search.py "rust programming language"
```

**Site-specific search (GitHub, docs, etc.):**
```bash
uv run search.py "openclaw stars" --site github.com
uv run search.py "async await" --site developer.mozilla.org
```

**File type filtering:**
```bash
uv run search.py "research papers" --filetype pdf
uv run search.py "documentation" --site docs.python.org --filetype html
```

**Time-based filtering:**
```bash
uv run search.py "latest news" --timelimit d    # past day
uv run search.py "recent commits" --timelimit w  # past week
```

**Combine multiple filters:**
```bash
uv run search.py "python tutorial" --exclude "youtube,video" --max 20
uv run search.py "API docs" --site docs.python.org --filetype html --max 15
```

**Alternative backends:**
```bash
uv run search.py "ai developments" --backend google --region us-en
uv run search.py "wikipedia article" --backend wikipedia
```

**Exact phrase matching:**
```bash
uv run search.py "to be or not to be" --exact
```

## Output

Results are returned in markdown format:
- Title as a clickable link
- URL
- Snippet/description

Example:
```markdown
- [**Rust Programming Language**](https://www.rust-lang.org/)
  A systems programming language that runs blazingly fast, prevents segfaults, and guarantees thread safety.
```

## Notes

- **Bearer token priority**: environment variable → credgoo → .env file
- **Region format**: `<language>-<country>` (e.g., us-en, de-de, wt-wt for worldwide)
- **SSL verification** enabled by default for security
- **Proxy support**: HTTP, HTTPS, and SOCKS5 protocols
- For secure credentials, use [credgoo](https://github.com/devskale/python-openutils/tree/main/packages/credgoo)
