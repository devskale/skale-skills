---
name: fetch-url
description: Fetch and extract readable text content from web pages using text-based browsers (w3m/lynx) or via API. Extracts plain text without rendering images, styles, or JavaScript. Use when the user wants to read articles, documentation, or scrape text content from web pages.
---

# Fetch URL

## Quick Reference

```bash
cd ~/.pi/agent/skills/fetch-url

# Fetch a URL (local mode, w3m)
uv run fetch.py "https://example.com"

# Use lynx instead
uv run fetch.py "https://example.com" --tool lynx

# Use markdown.new (ideal for Windows)
uv run fetch.py "https://example.com" --tool markdown

# JS-heavy sites with browser rendering
uv run fetch.py "https://spa-site.com" --tool markdown --md-method browser

# Use API mode
uv run fetch.py "https://example.com" --api

# Clean output (remove empty lines)
uv run fetch.py "https://example.com" --clean

# Show link numbers for reference
uv run fetch.py "https://github.com" --links
```

See **Setup**, **Options**, and **Examples** below for advanced usage.

## Description

Extract readable text from web pages using text-based browsers (w3m/lynx) or a remote API. Returns plain text without images, styles, or JavaScript. Ideal for articles, documentation, and text-heavy pages.

## Setup

### 1. Create Virtual Environment

```bash
cd ~/.pi/agent/skills/fetch-url
uv venv
```

### 2. Install Dependencies

**For API mode (optional):**
```bash
uv pip install requests
```

**For local mode (w3m/lynx):**

| OS | Command |
|----|---------|
| macOS | `brew install w3m lynx` |
| Ubuntu/Debian | `sudo apt-get install w3m lynx` |
| Arch Linux | `sudo pacman -S w3m lynx` |
| Windows | Use `--tool markdown` (no browser needed) |

**For Windows (recommended):**
```powershell
# Windows doesn't have w3m/lynx easily available
# Use markdown.new instead (only requires 'requests' library)
cd ~/.pi/agent/skills/fetch-url
uv pip install requests
uv run fetch.py "https://example.com" --tool markdown
```

### 3. Set API Bearer Token (API mode only)

```bash
export FETCH_URL_BEARER="your_token"
# or use .env file
echo "FETCH_URL_BEARER=your_token" > ~/.pi/agent/skills/fetch-url/.env
```

## How to Use

```bash
cd ~/.pi/agent/skills/fetch-url
uv run fetch.py "<url>" [options]
```

Or install as a command:
```bash
uv pip install -e .
fetch-url "<url>" [options]
```

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `--tool` | w3m | Browser to use: w3m, lynx, or markdown |
| `--links` | false | Display link numbers (w3m only) |
| `--clean` | false | Remove consecutive empty lines |
| `--api` | false | Use API instead of local tools |
| `--api-url` | https://amd1.mooo.com/api/fetch_url | Custom API endpoint |
| `--bearer` | - | Bearer token (overrides env var) |
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
uv run fetch.py "https://example.com"
uv run fetch.py "example.com"  # https:// added automatically
```

**Windows (no browser needed):**
```powershell
uv run fetch.py "https://example.com" --tool markdown
```

**Choose browser:**
```bash
uv run fetch.py "https://docs.python.org" --tool w3m      # better formatting
uv run fetch.py "https://docs.python.org" --tool lynx      # faster
uv run fetch.py "https://docs.python.org" --tool markdown  # Windows-friendly, markdown output
```

**Clean and reference output:**
```bash
uv run fetch.py "https://github.com" --links    # show link numbers
uv run fetch.py "https://example.com" --clean   # remove empty lines
```

**markdown.new options (Windows-friendly):**
```bash
# JS-heavy sites - use browser rendering
uv run fetch.py "https://spa-site.com" --tool markdown --md-method browser

# Keep images in output
uv run fetch.py "https://blog.example.com" --tool markdown --md-images

# Combine options
uv run fetch.py "https://example.com" --tool markdown --md-method browser --md-images --clean
```

**API mode:**
```bash
uv run fetch.py "https://example.com" --api
uv run fetch.py "https://example.com" --api --tool lynx
uv run fetch.py "https://example.com" --api --bearer YOUR_TOKEN
```

**Piping output:**
```bash
uv run fetch.py "https://example.com" | grep -i "search term"
uv run fetch.py "https://example.com" > output.txt
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

## Browser Comparison

| Browser | Speed | Formatting | Link Numbers | Best For |
|---------|-------|------------|---------------|----------|
| w3m | Medium | Excellent | Yes | Complex layouts, formatted text |
| lynx | Fast | Good | No | Quick reads, simple pages |
| markdown | Fast | Markdown | No | Windows, clean markdown output, 80% fewer tokens |

**markdown.new** uses Cloudflare's Markdown for Agents API with automatic fallbacks:
1. Native `text/markdown` content negotiation
2. Workers AI `toMarkdown()` 
3. Browser Rendering for JS-heavy pages

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
- Some sites block text browsers or require JavaScript - try API mode or web-browser skill for these

## Troubleshooting

**Browser not found:**
```bash
# Install w3m or lynx per OS instructions in Setup section
# On Windows, use --tool markdown instead
uv run fetch.py "https://example.com" --tool markdown
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
uv run fetch.py "https://example.com" --tool lynx
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
uv run fetch.py "https://spa-site.com" --tool markdown --md-method browser
```

---

## Reference Documentation

Detailed guides for specific use cases:

- **[GitHub Pages](references/github.md)** — Strategies for fetching GitHub content, URL conversion patterns, curl workflows, and common troubleshooting.

See [references/](references/) directory for all reference documentation.
