---
name: fetch-url
description: Fetch and extract readable text content from web pages using text-based browsers (w3m/lynx) or via API. Extracts plain text without rendering images, styles, or JavaScript. Use when the user wants to read articles, documentation, or scrape text content from web pages.
---

# Fetch URL

## Description

Extract readable text content from web pages using text-based browsers (w3m or lynx) or via a remote API. This skill fetches web pages and returns the plain text content without rendering images, styles, or JavaScript. It's perfect for reading articles, documentation, and other text-heavy web pages.

## Setup

1. From the skill directory, create a virtual environment:

```bash
cd ~/.pi/agent/skills/fetch-url
uv venv
```

2. Install Python dependencies (only required for API mode):

```bash
uv pip install requests
```

3. Install the required text browsers (for local mode only):

**macOS:**
```bash
brew install w3m lynx
```

**Ubuntu/Debian:**
```bash
sudo apt-get install w3m lynx
```

**Arch Linux:**
```bash
sudo pacman -S w3m lynx
```

4. Set your API bearer token (for API mode, optional):

```bash
export FETCH_URL_BEARER="your_token"
```

Or create a `.env` file in the skill directory:

```bash
echo "FETCH_URL_BEARER=your_token" > ~/.pi/agent/skills/fetch-url/.env
```

2. Install the required text browsers:

**macOS:**
```bash
brew install w3m lynx
```

**Ubuntu/Debian:**
```bash
sudo apt-get install w3m lynx
```

**Arch Linux:**
```bash
sudo pacman -S w3m lynx
```

## How to Use

**Option 1: Run with uv (recommended)**

```bash
cd ~/.pi/agent/skills/fetch-url
uv run fetch.py "<url>" [options]
```

**Option 2: Install as a command**

```bash
cd ~/.pi/agent/skills/fetch-url
uv pip install -e .
uv run fetch-url "<url>" [options]
```

### Options

| Option | Default | Description |
|--------|---------|-------------|
| `--tool` | w3m | Browser to use: w3m or lynx |
| `--links` | false | Display link numbers in output (w3m only) |
| `--clean` | false | Remove consecutive empty lines from output |
| `--api` | false | Use API instead of local tools |
| `--api-url` | https://amd1.mooo.com/api/fetch_url | Custom API endpoint URL |
| `--bearer` | - | Bearer token for API authentication (overrides env var) |

## Examples

### Local Mode

Fetch a URL with default settings (w3m):

```bash
uv run fetch.py "https://example.com"
```

Fetch a URL without protocol (https:// will be added):

```bash
uv run fetch.py "example.com"
```

Use lynx instead of w3m:

```bash
uv run fetch.py "https://docs.python.org" --tool lynx
```

Fetch with link numbers displayed (for reference):

```bash
uv run fetch.py "https://github.com" --links
```

Fetch and clean up empty lines:

```bash
uv run fetch.py "https://example.com/article" --clean
```

### API Mode

Fetch a URL via API:

```bash
uv run fetch.py "https://orf.at" --api
```

Fetch via API with custom bearer token:

```bash
uv run fetch.py "https://orf.at" --api --bearer YOUR_TOKEN
```

Use lynx via API:

```bash
uv run fetch.py "https://orf.at" --api --tool lynx
```

Use custom API endpoint:

```bash
uv run fetch.py "https://example.com" --api --api-url "https://your-api.com/fetch"
```

### Other Operations

Pipe output to grep for specific content:

```bash
uv run fetch.py "https://example.com" | grep -i "search term"
```

Fetch and save to file:

```bash
uv run fetch.py "https://example.com" > output.txt
```

## Modes

### Local Mode
Uses w3m or lynx installed on your local system. Requires the text browsers to be installed but doesn't require network calls to an external API. Use this when you have the tools installed and want to avoid API rate limits.

**Pros:**
- No API dependencies
- No rate limits
- Works offline (for cached pages)

**Cons:**
- Requires w3m/lynx to be installed
- May be blocked by some websites

### API Mode
Fetches URLs via a remote API endpoint. The API handles the browser execution and returns the text content. Requires `requests` library and a bearer token.

**Pros:**
- No local browser installation required
- May bypass certain local restrictions
- Centralized access

**Cons:**
- Requires network connectivity to API
- API may have rate limits
- Requires bearer token

## Browser Differences

### w3m
- **Pros**: Better formatting, supports link numbers, handles complex layouts well
- **Cons**: Slightly slower than lynx
- **Use when**: You need well-formatted text or reference to link numbers

### lynx
- **Pros**: Faster, lighter weight
- **Cons**: Simpler formatting, no link number support
- **Use when**: Speed is more important than formatting

## Output

The skill outputs the plain text content of the webpage, including:
- Headings and subheadings
- Paragraph text
- Lists
- Link text (URLs shown in parentheses or with numbers if `--links` is used)
- Basic form elements labels

JavaScript, CSS, images, and other media are stripped.

## Notes

- URLs without `http://` or `https://` prefix will have `https://` automatically added
- The fetch operation has a 30-second timeout
- Both w3m and lynx use custom configuration files with:
  - Cookie support enabled
  - UTF-8 character set
  - User agent strings to avoid being blocked
- Some websites may block text browsers or require JavaScript - these sites may return incomplete content
- For dynamic sites that require JavaScript, consider using the web-browser skill instead

## Troubleshooting

### Local Mode Issues

**Error: w3m not found**
```bash
# macOS
brew install w3m

# Linux (Debian/Ubuntu)
sudo apt-get install w3m

# Linux (Arch)
sudo pacman -S w3m
```

**Error: Lynx not found**
```bash
# macOS
brew install lynx

# Linux (Debian/Ubuntu)
sudo apt-get install lynx

# Linux (Arch)
sudo pacman -S lynx
```

### API Mode Issues

**Error: 'requests' library is required for API mode**
```bash
uv pip install requests
```

**Error: Bearer token is required for API mode**
Set the environment variable or create a .env file:
```bash
export FETCH_URL_BEARER="your_token"
# or use the same token as web-search
export WEB_SEARCH_BEARER="your_token"
```

**API request failed**
- Check your bearer token is correct
- Ensure you have network connectivity to the API endpoint
- Verify the API endpoint is accessible
- Try using local mode instead with `--tool w3m` (without `--api`)

### General Issues

**Request timed out**
- Try fetching a simpler page
- Some sites may be slow or blocking text browsers
- Try the other browser (switch between w3m and lynx)
- Try API mode instead of local mode

**Incomplete content**
- Some sites rely heavily on JavaScript
- Try using the web-browser skill for JavaScript-heavy sites
- The site may be blocking text-based browsers
- Try API mode which may handle some sites better
