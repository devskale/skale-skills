# Web Search Reference

## Common Search Patterns

### Finding Documentation
```bash
# Official docs for a library
uv run scripts/search.py "react hooks" --site react.dev

# API reference with specific filetype
uv run scripts/search.py "python requests" --site docs.python-requests.org --filetype html

# GitHub repositories
uv run scripts/search.py "rust web framework" --site github.com
```

### Finding Code Examples
```bash
# Code snippets (exclude videos/tutorials)
uv run scripts/search.py "python asyncio example" --exclude youtube,video

# Stack Overflow answers
uv run scripts/search.py "TypeError NoneType" --site stackoverflow.com

# Gists and snippets
uv run scripts/search.py "docker compose" --site gist.github.com
```

### Research & Papers
```bash
# Academic papers
uv run scripts/search.py "machine learning transformers" --filetype pdf

# Research with time filter
uv run scripts/search.py "LLM benchmarks 2024" --filetype pdf --timelimit y
```

### News & Current Events
```bash
# Latest news
uv run scripts/search.py "AI regulation" --timelimit d --max 20

# News from specific region
uv run scripts/search.py "tech news" --backend google --region us-en --timelimit w
```

### Troubleshooting Error Messages
```bash
# Exact error message search
uv run scripts/search.py "TypeError: 'NoneType' object is not iterable" --exact

# Exclude forums you don't want
uv run scripts/search.py "npm install fails" --exclude quora,reddit
```

## Query Building Rules

The script transforms flags into search operators:

| Input | Query Sent to API |
|-------|-------------------|
| `--site github.com rust` | `site:github.com rust` |
| `--filetype pdf report` | `filetype:pdf report` |
| `--exclude youtube python` | `python -youtube` |
| `--exact "to be or not to be"` | `"to be or not to be"` |

**Combine flags freely:**
```bash
# Multiple filters together
uv run scripts/search.py "api tutorial" --site docs.python.org --exclude video --timelimit m --max 15
```

**Use operators directly in query:**
```bash
# Same as --site flag
uv run scripts/search.py "site:github.com rust async"
```

## Options Reference

| Option | Default | Description |
|--------|---------|-------------|
| `--max N` | 10 | Number of results (1-100) |
| `--page N` | 1 | Page number for pagination |
| `--site DOMAIN` | - | Limit to domain (e.g., github.com) |
| `--filetype EXT` | - | File extension (pdf, doc, txt, etc.) |
| `--inurl TEXT` | - | URL must contain text |
| `--exclude TERMS` | - | Comma-separated terms to exclude |
| `--timelimit TIME` | - | `d`=day, `w`=week, `m`=month, `y`=year |
| `--region CODE` | wt-wt | Language-region (us-en, de-de, etc.) |
| `--backend NAME` | duckduckgo | Search provider |
| `--exact` | false | Exact phrase match (wrap in quotes) |
| `--proxy URL` | - | Proxy: `socks5h://127.0.0.1:9150` |
| `--timeout SEC` | 30 | Request timeout |

## Backends

| Backend | Best For |
|---------|----------|
| `duckduckgo` | General search (default) |
| `google` | Broader results, news |
| `bing` | Alternative to Google |
| `brave` | Privacy-focused, tech content |
| `wikipedia` | Encyclopedia articles only |
| `mojeek` | Independent index |

**Tip:** If one backend returns poor results, try another.

## Region Codes

| Code | Region |
|------|--------|
| `wt-wt` | Worldwide (default) |
| `us-en` | US English |
| `uk-en` | UK English |
| `de-de` | Germany |
| `fr-fr` | France |
| `es-es` | Spain |
| `ja-jp` | Japan |
| `zh-cn` | China |

## Authentication

Set `WEB_SEARCH_BEARER` token via (in priority order):

1. **Environment variable:**
   ```bash
   export WEB_SEARCH_BEARER="your_token"
   ```

2. **Credgoo** (recommended for shared environments):
   ```bash
   credgoo  # service name: web-search
   ```

3. **.env file** in skill directory:
   ```
   WEB_SEARCH_BEARER=your_token
   ```

## Tips & Tricks

### Reduce Noise
```bash
# Exclude common low-value sites
uv run scripts/search.py "tutorial" --exclude pinterest,quora,facebook

# Focus on documentation only
uv run scripts/search.py "api" --site docs.* --filetype html
```

### Pagination
```bash
# Get more results across pages
uv run scripts/search.py "rust gui" --max 10 --page 1
uv run scripts/search.py "rust gui" --max 10 --page 2
```

### Regional Content
```bash
# German results for German topic
uv run scripts/search.py "versicherung" --region de-de --backend google
```

### Debugging Queries
Add `--bearer` to test with a different token:
```bash
uv run scripts/search.py "test" --bearer "other_token"
```

## Troubleshooting

| Error | Solution |
|-------|----------|
| "Bearer token is required" | Set `WEB_SEARCH_BEARER` via env, credgoo, or .env |
| "Error performing search" | Check network, verify API is accessible |
| "No results found" | Simplify query, try different backend |
| Timeout errors | Increase `--timeout 60` |
| SSL errors | Check `--verify true/false` setting |
