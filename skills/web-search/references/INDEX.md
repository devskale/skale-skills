# Web Search Reference

## Common Search Patterns

### Finding Documentation
```bash
web-search "react hooks" --site react.dev
web-search "python requests" --site docs.python-requests.org
web-search "rust web framework" --site github.com
```

### Finding Code Examples
```bash
web-search "python asyncio example" --exclude youtube,reddit
web-search "TypeError NoneType" --site stackoverflow.com
web-search "docker compose" --site gist.github.com
```

### Research & Papers
```bash
web-search "machine learning transformers" --filetype pdf
web-search "LLM benchmarks 2024" --filetype pdf --timelimit y
```

### News & Current Events
```bash
web-search "AI regulation" --timelimit d --max 20
web-search "tech news" --time-range week --max 20
```

### Troubleshooting Error Messages
```bash
web-search "TypeError: 'NoneType' object is not iterable" --exact
web-search "npm install fails" --exclude quora,reddit
```

## Query Building Rules

The Duck API backend transforms flags into search operators:

| Input | Query Sent to API |
|-------|-------------------|
| `--site github.com rust` | `site:github.com rust` |
| `--filetype pdf report` | `filetype:pdf report` |
| `--exclude youtube python` | `python -youtube` |
| `--exact "to be or not to be"` | `"to be or not to be"` |

**Note:** These operators only work with the Duck API backend (requires `WEB_SEARCH_BEARER`). The SearXNG backend ignores `--site`, `--filetype`, `--exclude`, `--exact`, `--inurl`, and `--timelimit`.

## Options Reference

### General

| Option | Default | Description |
|--------|---------|-------------|
| `--max N` | 10 | Number of results (1-100) |
| `--page N` | 1 | Results page |
| `--json` | off | Output as JSON |
| `-v, --verbose` | off | Show backend name (printed to stderr) |

### Duck API Filters (requires `WEB_SEARCH_BEARER`)

| Option | Default | Description |
|--------|---------|-------------|
| `--site DOMAIN` | - | Limit to domain (e.g., github.com) |
| `--filetype EXT` | - | File extension (pdf, doc, txt, etc.) |
| `--inurl TEXT` | - | URL must contain text |
| `--exclude TERMS` | - | Comma-separated terms to exclude |
| `--exact` | false | Exact phrase match (wrap in quotes) |
| `--timelimit {d,w,m,y}` | - | Time filter: d=day, w=week, m=month, y=year |
| `--region CODE` | wt-wt | Language-region (us-en, de-de, etc.) |

### SearXNG Options (default, no credentials needed)

| Option | Default | Description |
|--------|---------|-------------|
| `--categories CAT` | general | Category: images, news, videos |
| `--engines LIST` | all | Comma-separated engines (e.g., google,bing) |
| `--time-range {day,week,month,year}` | - | Time filter (works on both backends, auto-mapped for Duck) |
| `--language LANG` | en | Search language (e.g., en, de, ja). SearXNG backend only. |
| `--region CODE` | wt-wt | Language-region (us-en, de-de, etc.) |

### Backend Selection

| Option | Description |
|--------|-------------|
| `--api` | Force Duck API backend |
| `--searxng` | Force SearXNG backend |

Default backend selection: Duck API if `WEB_SEARCH_BEARER` is set (except for `--categories`), otherwise SearXNG.

## Backends

| Backend | Credentials | Filters | Best For |
|---------|-------------|---------|----------|
| **Duck API** | `WEB_SEARCH_BEARER` required | `--site`, `--filetype`, `--exclude`, `--exact`, `--inurl`, `--timelimit` | General search, domain filtering, file types |
| **SearXNG** | None (public instances) | `--categories`, `--engines`, `--time-range` | Images, news, videos, no-credential search |

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

2. **Credgoo:**
   ```bash
   credgoo add WEB_SEARCH_BEARER
   ```

3. **.env file** in skill root directory (same level as `SKILL.md`):
   ```
   WEB_SEARCH_BEARER=your_token
   ```

For private SearXNG:
```bash
credgoo add searx
# Format: URL@username@password
```

## Tips & Tricks

### Reduce Noise
```bash
web-search "tutorial" --exclude pinterest,quora,facebook
```

### Pagination
```bash
web-search "rust gui" --max 10 --page 1
web-search "rust gui" --max 10 --page 2
```

### Backend Differences
```bash
# Duck API: supports --site filter
web-search "react hooks" --site react.dev

# SearXNG: supports --categories and --engines
web-search "cute cats" --categories images
web-search "test" --searxng --engines google,bing
```

## Troubleshooting

| Error | Solution |
|-------|----------|
| "Bearer token is required" | Set `WEB_SEARCH_BEARER` env var or use `--searxng` for public search |
| "All SearXNG instances failed" | Check network; configure a private SearXNG instance via `credgoo add searx` |
| "No results found" | Simplify query, try different backend |
| Filters ignored | Duck API filters (`--site`, `--filetype`, etc.) only work with Duck backend |
| 404 on empty query | Provide a non-empty search query |
| Exit code 1 | Search error — backend failure, auth error, or all instances down |
