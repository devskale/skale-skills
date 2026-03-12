---
name: web-search
description: Search the web with automatic backend selection. Uses privacy-respecting SearXNG when available, otherwise DuckDuckGo. Supports rich filters including domain, filetype, time filters, and exclusions.
compatibility: Requires WEB_SEARCH_BEARER for DuckDuckGo; credgoo (searx key) for SearXNG
---

# Web Search

Simple, opinionated web search that automatically picks the best backend.

## How to Run

### Option 1: From Within the Skill Directory (Easiest)
Navigate to the skill directory first:
```bash
cd <path-to-skill>
./search "your query"
```
Example:
```bash
cd ~/.pi/agent/skills/web-search
./search "react hooks"
```

### Option 2: From Any Directory (Full Path)
Use the full path to the `search` script:
```bash
<path-to-skill>/search "your query"
```
Example:
```bash
~/.pi/agent/skills/web-search/search "react hooks"
```

### Finding Your Skill Path
If you're unsure where the skill is installed:
```bash
find ~ -name "search" -path "*/web-search/*" 2>/dev/null
# Or
locate web-search/search
```

### Option 3: Using uv run
```bash
cd <path-to-skill>
uv run scripts/search.py "your query"
```

### Option 4: After Installing as Package
```bash
cd <path-to-skill>
uv pip install -e .
web-search "your query"
```

---

## ⚠️ Important Note About Paths

The `search` script automatically switches to the skill directory when executed. However, **you must call the script using its correct path**:

- ❌ `./search "query"` → **Fails** if you're not in the skill directory
- ✅ `cd <skill-path> && ./search "query"` → **Works**
- ✅ `<skill-path>/search "query"` → **Works from anywhere**

**Replace `<skill-path>` with your actual installation path**, typically:
- `~/.pi/agent/skills/web-search`
- `/path/to/skills/web-search`

## Configuration

### SearXNG (Recommended - Privacy)
Configure in credgoo with key `searx`:
```
URL@USERNAME@PASSWORD
```
Example: `https://searx.example.com:8080@myuser@mypassword`

### DuckDuckGo (Fallback)
Create `.env` file with:
```
WEB_SEARCH_BEARER=your_token
```
Or set `WEB_SEARCH_BEARER` environment variable.

## Usage Examples

Replace `<skill-path>` with your actual installation path (e.g., `~/.pi/agent/skills/web-search`).

```bash
# Basic search
<skill-path>/search "react hooks"

# Documentation search
<skill-path>/search "python tutorial" --site github.com

# Filter by file type
<skill-path>/search "ML transformers" --filetype pdf

# Recent news (last day)
<skill-path>/search "AI news" --timelimit d

# Exclude sites
<skill-path>/search "python tutorial" --exclude youtube,reddit

# Exact phrase
<skill-path>/search "TypeError NoneType" --exact

# Images
<skill-path>/search "cats" --categories images

# Time range (last week)
<skill-path>/search "climate" --time-range week
```

## Options

| Option | Description |
|--------|-------------|
| `--max N` | Number of results (default: 10) |
| `--site DOMAIN` | Filter by domain |
| `--filetype TYPE` | Filter by file type (pdf, txt, etc.) |
| `--exclude TERMS` | Exclude comma-separated terms |
| `--exact` | Exact phrase matching |
| `--timelimit d\|w\|m\|y` | Time filter (day/week/month/year) |
| `--categories` | Category filter (images, news, videos) |
| `--time-range` | Time range (day, week, month, year) |
| `--json` | Output raw JSON |
| `--verbose` | Show which backend is being used |

## Backend Selection

The skill automatically selects the best backend:
1. **SearXNG** - Used if credentials configured (privacy, more engines)
2. **DuckDuckGo** - Default fallback

User doesn't need to think about backends - just search.

## Tip: Create an Alias

To avoid typing the full path every time, add this to your `~/.zshrc` or `~/.bashrc`:

```bash
alias web-search='<skill-path>/search'
```

Example:
```bash
alias web-search='~/.pi/agent/skills/web-search/search'
```

Then reload your shell (`source ~/.zshrc` or `source ~/.bashrc`) and use:
```bash
web-search "your query" --site github.com
```

## More Examples

```bash
# Find documentation
cd <skill-path> && ./search "react useEffect" --site react.dev

# Find papers
cd <skill-path> && ./search "attention is all you need" --filetype pdf

# Troubleshooting
cd <skill-path> && ./search "TypeError NoneType" --exact --site stackoverflow.com

# Current events
cd <skill-path> && ./search "bitcoin" --timelimit d

# Images
cd <skill-path> && ./search "landscape photography" --categories images

# Multiple exclusions
cd <skill-path> && ./search "python async" --exclude youtube,twitter,reddit
```
