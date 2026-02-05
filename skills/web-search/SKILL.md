---
name: web-search
description: Perform DuckDuckGo web searches with rich filters including domain, filetype, and URL fragment operators, exclusion lists, region settings, and pagination. Use when the user wants to search the web for information, find documentation, or look up facts.
---

# Web Search (DuckDuckGo)

## Setup

1. From the skill directory, create a virtual environment and install dependencies:

```bash
cd ~/.pi/agent/skills/web-search
uv venv
uv pip install -r requirements.txt
```

2. Set your API bearer token. Choose one of the following methods:

**Option A: Environment Variable**

```bash
export WEB_SEARCH_BEARER="your_token_here"
```

**Option B: .env file**

```bash
echo "WEB_SEARCH_BEARER=your_token_here" > ~/.pi/agent/skills/web-search/.env
```

**Option C: Credgoo (Recommended for secure credentials management)**

```bash
uv pip install -r https://skale.dev/credgoo
```

Then store your token in credgoo and it will be automatically retrieved:

```bash
credgoo web-search --token YOUR_CREDGOO_TOKEN --key YOUR_ENCRYPTION_KEY
```

**Priority order:** The skill will try to get the token in this order:
1. Environment variable `WEB_SEARCH_BEARER`
2. Credgoo (if configured)
3. .env file in the skill directory

## How to Search

**Option 1: Run with uv (recommended)**

```bash
cd ~/.pi/agent/skills/web-search
uv run search.py "<query>" [options]
```

**Option 2: Install as a command**

```bash
cd ~/.pi/agent/skills/web-search
uv pip install -e .
uv run web-search "<query>" [options]
```

### Options

| Option | Default | Description |
|--------|---------|-------------|
| `--max` | 10 | Maximum number of results |
| `--region` | wt-wt | Region code (e.g., us-en, de-de, fr-fr) |
| `--safesearch` | moderate | Safe search level: off, moderate, strict |
| `--exact` | false | True for exact phrase matching (wraps query in quotes) |
| `--page` | 1 | Page number for pagination |
| `--site` | - | Filter to specific domain (e.g., github.com) |
| `--filetype` | - | Filter by file extension (e.g., pdf, txt) |
| `--inurl` | - | Filter by URL fragment |
| `--exclude` | - | Comma-separated list of terms/domains to exclude |
| `--timelimit` | - | Time range filter: d (day), w (week), m (month), y (year) |
| `--backend` | - | Search backend: auto, all, bing, brave, duckduckgo, google, mojeek, yandex, yahoo, wikipedia |
| `--proxy` | - | Proxy URL (e.g., socks5h://127.0.0.1:9150) |
| `--verify` | true | Verify SSL certificates |
| `--api-url` | - | Custom API endpoint URL |
| `--timeout` | 30 | Request timeout in seconds |

### Query Operators

You can also use DuckDuckGo operators directly in the query string:

- `site:example.com` - Search within a specific domain
- `filetype:pdf` - Search for PDF files only
- `inurl:docs` - Search URLs containing "docs"
- `-term` - Exclude results with this term

### Time Limit Values

The `--timelimit` option filters results by recency:

- `d` - Past day
- `w` - Past week
- `m` - Past month
- `y` - Past year

### Backend Options

The `--backend` option lets you choose which search provider to use:

- `auto` - Automatic selection
- `all` - Aggregate multiple sources
- `bing` - Microsoft Bing
- `brave` - Brave Search
- `duckduckgo` - DuckDuckGo (default)
- `google` - Google Search
- `mojeek` - Mojeek
- `yandex` - Yandex
- `yahoo` - Yahoo Search
- `wikipedia` - Wikipedia search only

## Examples

Basic search:

```bash
uv run search.py "rust programming language"
```

Search with max results:

```bash
uv run search.py "machine learning" --max 25
```

Search within a specific site:

```bash
uv run search.py "async await" --site developer.mozilla.org
```

Search for PDF files:

```bash
uv run search.py "research papers" --filetype pdf
```

Exact phrase matching:

```bash
uv run search.py "to be or not to be" --exact
```

Combine filters:

```bash
uv run search.py "API documentation" --site docs.python.org --filetype html --max 15
```

Exclude certain terms:

```bash
uv run search.py "python tutorial" --exclude "youtube,video,course"
```

Search with time filter (last day):

```bash
uv run search.py "latest news" --timelimit d --max 20
```

Search with specific backend:

```bash
uv run search.py "ai developments" --backend google --region us-en
```

Search through proxy:

```bash
uv run search.py "search results" --proxy socks5h://127.0.0.1:9150
```

Disable SSL verification:

```bash
uv run search.py "test query" --verify false
```

Search by region (Germany, German language):

```bash
uv run search.py "rezepte" --region de-de
```

Search with URL fragment:

```bash
uv run search.py "installation guide" --inurl docs
```

Search with custom API endpoint:

```bash
uv run search.py "test query" --api-url "https://your-api.com/search"
```

Search with custom timeout:

```bash
uv run search.py "slow site" --timeout 60
```

## Output

The script returns formatted results in markdown with:

- Title as a clickable link
- URL
- Snippet/description

Example output:

```markdown
- [**Rust Programming Language**](https://www.rust-lang.org/)
  A systems programming language that runs blazingly fast, prevents segfaults, and guarantees thread safety.
```

## Notes

- The API uses DuckDuckGo as the search backend by default, but can use other providers via `--backend`
- Results include web pages, and can be filtered by various parameters including time range and backend selection
- SSL verification is enabled by default (`--verify true`) for secure requests
- Bearer token retrieval priority: environment variable → credgoo → .env file
- For secure credentials management, consider using [credgoo](https://github.com/devskale/python-openutils/tree/main/packages/credgoo) to store your tokens
- Region codes follow the format `<language>-<country>` (e.g., us-en, de-de, wt-wt for worldwide)
- The `--proxy` option supports various proxy protocols including HTTP, HTTPS, and SOCKS5
