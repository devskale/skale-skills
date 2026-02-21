---
name: fetch-url
description: Fetch and extract readable text content from web pages using text-based browsers (w3m/lynx) or via API. Auto-selects best tool for platform with automatic fallback. Supports Jina.ai Reader (free unlimited), markdown.new, and custom API. Extracts plain text without rendering images, styles, or JavaScript. Use when the user wants to read articles, documentation, or scrape text content from web pages.
---

# Fetch URL

## Quick Reference

```bash
cd ~/.pi/agent/skills/fetch-url

# Auto-select best tool (default) - tries jina → api → markdown → w3m → lynx
uv run scripts/fetch.py "https://example.com"

# Use specific tool
uv run scripts/fetch.py "https://example.com" --tool jina
uv run scripts/fetch.py "https://example.com" --tool api --bearer TOKEN
uv run scripts/fetch.py "https://example.com" --tool markdown

# Show fallback attempts
uv run scripts/fetch.py "https://example.com" --verbose

# JS-heavy sites with browser rendering
uv run scripts/fetch.py "https://spa-site.com" --tool markdown --md-method browser

# Clean output (remove empty lines)
uv run scripts/fetch.py "https://example.com" --clean

# Show link numbers for reference (w3m only)
uv run scripts/fetch.py "https://github.com" --tool w3m --links
```

See **Setup**, **Options**, and **Examples** below for advanced usage.

## Description

Extract readable text from web pages using text-based browsers (w3m/lynx) or a remote API. Returns plain text without images, styles, or JavaScript. Ideal for articles, documentation, and text-heavy pages.

## Setup

```bash
cd ~/.pi/agent/skills/fetch-url

# Install dependencies (run once)
uv sync

# Then use the skill
uv run scripts/fetch.py "https://example.com"
```

### Alternative: No setup required

```bash
# uv will install dependencies automatically
uv run --with requests scripts/fetch.py "https://example.com"
```

### Local browsers (optional, for w3m/lynx/chawan):

| OS | Command |
|----|---------|
| macOS | `brew install w3m lynx chawan` |
| Ubuntu/Debian | `sudo apt-get install w3m lynx` |
| Linux (chawan) | See https://github.com/devskale/chawan |
| Windows | Not needed - use `--tool jina` (default) |

### Bearer token (for API tool only):

```bash
export FETCH_URL_BEARER="your_token"
# or create .env file in skill directory
```

## How to Use

```bash
cd ~/.pi/agent/skills/fetch-url
uv run scripts/fetch.py "<url>" [options]
```

Or install as a command:
```bash
uv pip install -e .
fetch-url "<url>" [options]
```

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `--tool` | auto | Tool to use: auto, jina, api, markdown, w3m, lynx |
| `--links` | false | Display link numbers (w3m only) |
| `--clean` | false | Remove consecutive empty lines |
| `--verbose` | false | Show fallback attempts |
| `--api` | false | Use custom API (same as --tool api) |
| `--api-url` | - | Custom API endpoint URL |
| `--bearer` | - | Bearer token for API mode |
| `--md-method` | auto | markdown.new method: auto, ai, or browser |
| `--md-images` | false | Retain images in markdown output |

### markdown.new Options

When using `--tool markdown`, additional options are available:

| Option | Values | Description |
|--------|--------|-------------|
| `--md-method` | `auto`, `ai`, `browser` | Conversion method. Use `browser` for JS-heavy sites. |
| `--md-images` | flag | Retain images in output (default: strip images) |

**Methods explained:**
- `auto` (default): Tries Cloudflare's native markdown first, falls back to AI
- `ai`: Forces Workers AI `toMarkdown()` conversion
- `browser`: Renders page in headless browser (best for JS-heavy sites, slower)

## Examples

**Basic fetching:**
```bash
uv run scripts/fetch.py "https://example.com"
uv run scripts/fetch.py "example.com"  # https:// added automatically
```

**Windows (no browser needed):**
```powershell
uv run scripts/fetch.py "https://example.com" --tool markdown
```

**Choose tool:**
```bash
uv run scripts/fetch.py "https://docs.python.org" --tool w3m      # better formatting
uv run scripts/fetch.py "https://docs.python.org" --tool lynx     # faster
uv run scripts/fetch.py "https://docs.python.org" --tool markdown # markdown output
uv run scripts/fetch.py "https://docs.python.org" --tool jina     # free unlimited, markdown
```

**Clean and reference output:**
```bash
uv run scripts/fetch.py "https://github.com" --links    # show link numbers
uv run scripts/fetch.py "https://example.com" --clean   # remove empty lines
```

**markdown.new options (Windows-friendly):**
```bash
# JS-heavy sites - use browser rendering
uv run scripts/fetch.py "https://spa-site.com" --tool markdown --md-method browser

# Keep images in output
uv run scripts/fetch.py "https://blog.example.com" --tool markdown --md-images

# Combine options
uv run scripts/fetch.py "https://example.com" --tool markdown --md-method browser --md-images --clean
```

**API mode:**
```bash
uv run scripts/fetch.py "https://example.com" --api
uv run scripts/fetch.py "https://example.com" --api --tool lynx
uv run scripts/fetch.py "https://example.com" --api --bearer YOUR_TOKEN
```

**Piping output:**
```bash
uv run scripts/fetch.py "https://example.com" | grep -i "search term"
uv run scripts/fetch.py "https://example.com" > output.txt
```

## Modes

### Local Mode
Uses w3m/lynx installed locally. No API dependency but requires browser installation.

**Pros:** No rate limits, offline capability, no API calls
**Cons:** Requires browser installation, some sites block text browsers

### API Mode
Fetches via remote API endpoint. Requires `requests` library and bearer token.

**Pros:** No local browser needed, may bypass restrictions
**Cons:** Requires network, rate limits possible, needs token

## Tool Comparison

| Tool | Speed | Auth | Rate Limit | Output | Best For |
|------|-------|------|------------|--------|----------|
| auto | - | - | - | - | Auto-selects best tool, uses fallbacks |
| jina | Fast | None | Unlimited | Markdown | Default, free unlimited, no auth |
| api | Fast | Bearer | - | Plain text | Custom API, requires token |
| markdown | Fast | None | 50/day | Markdown | **CAPTCHA/403 bypass**, clean output |
| chawan | Medium | None | None | Plain text | **StackOverflow** (full code), Reddit |
| w3m | Medium | None | None | Plain text | Complex layouts, Reddit |
| lynx | Fast | None | None | Plain text | Quick reads, Reddit, Medium |

**Bypassing blocks:**
- StackOverflow → use `--tool chawan` (best) or `--tool markdown`
- Reddit → use `--tool chawan` or `--tool markdown`
- Sites blocking w3m → try `--tool lynx` or `--tool markdown`

**API Services:**
- **jina** - Jina.ai Reader, free unlimited, no auth required
- **api** - Custom endpoint (https://amd1.mooo.com/api/fetch_url), requires bearer token
- **markdown** - markdown.new, Cloudflare API with fallbacks (native → AI → browser)

## Output

Returns plain text including:
- Headings and paragraphs
- Lists
- Link text (URLs in parentheses or numbered)
- Form labels

Stripped: JavaScript, CSS, images, media.

## Notes

- URLs without `http://` or `https://` get `https://` added automatically
- 30-second timeout on fetch operations
- w3m and lynx use custom configs with cookie support, UTF-8, and user agent strings
- **Windows**: Use `--tool markdown` for best results (uses markdown.new API)
- Some sites block text browsers or require JavaScript - try `--tool markdown` for these
- **CAPTCHA/403 errors**: Try `--tool markdown` which can bypass some bot detection
- **Sites that don't work well**: Twitter/X (requires JS/auth), YouTube (title only - use video-transcript-downloader skill instead)
- **For Reddit**: Use `--tool markdown` or `--tool w3m` - jina/api are blocked

## Troubleshooting

**Browser not found:**
```bash
# Install w3m or lynx per OS instructions in Setup section
# On Windows, use --tool markdown instead
uv run scripts/fetch.py "https://example.com" --tool markdown
```

**'requests' library required (API mode or markdown tool):**
```bash
uv pip install requests
```

**Bearer token required (API mode):**
```bash
export FETCH_URL_BEARER="your_token"
# or reuse web-search token
export WEB_SEARCH_BEARER="your_token"
```

**Venv corruption (dyld/SIGABRT error):**
```bash
cd ~/.pi/agent/skills/fetch-url
rm -rf .venv
uv venv
uv pip install requests  # if using API mode
```

**w3m "gunzip: unknown compression format" error:**
```bash
# Try lynx instead
uv run scripts/fetch.py "https://example.com" --tool lynx
```

**Request timed out:**
- Try simpler page
- Switch browsers (w3m ↔ lynx)
- Try API mode

**Incomplete content:**
- Site may require JavaScript - use `--tool markdown --md-method browser`
- Site blocks text browsers - try API mode or `--tool markdown`

**JS-heavy sites (SPA, React, Vue):**
```bash
# Use browser rendering method
uv run scripts/fetch.py "https://spa-site.com" --tool markdown --md-method browser
```

**CAPTCHA/403 blocked sites:**
```bash
# Try markdown tool to bypass blocks
uv run scripts/fetch.py "https://stackoverflow.com/questions/12345" --tool markdown
uv run scripts/fetch.py "https://www.reddit.com/r/LocalLLaMA/..." --tool markdown
uv run scripts/fetch.py "https://platform.openai.com/docs/..." --tool markdown
```

**Reddit:**
```bash
# Reddit blocks jina/api, use markdown or w3m/lynx
uv run scripts/fetch.py "https://www.reddit.com/r/..." --tool markdown
uv run scripts/fetch.py "https://www.reddit.com/r/..." --tool w3m
```

## Site Compatibility

Quick reference for popular sites:

| Site Type | Best Tool |
|-----------|-----------|
| StackOverflow | `chawan` (full code) or `markdown` |
| Reddit | `chawan` or `markdown` |
| Hacker News | `jina` or `chawan` |
| Medium | `jina` |
| Austrian sites (geizhals, willhaben, ORF) | `jina` |
| Twitter/X | ❌ Use bird/peep skill |
| YouTube | ❌ Use video-transcript skill |

**Full compatibility matrix:** See [references/sites.md](references/sites.md) for detailed testing results.

---

## Reference Documentation

Detailed guides for specific use cases:

- **[Site Compatibility](references/sites.md)** — Full testing matrix for popular sites (Reddit, StackOverflow, Austrian sites, etc.)
- **[GitHub Pages](references/github.md)** — Strategies for fetching GitHub content, URL conversion patterns, curl workflows, and common troubleshooting.

See [references/](references/) directory for all reference documentation.
