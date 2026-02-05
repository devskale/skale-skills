# Fetch URL Skill

Extract readable text content from web pages using text-based browsers (w3m or lynx) or via a remote API.

## Features

- Fetch web pages using w3m or lynx text browsers (local mode)
- Fetch web pages via remote API (API mode)
- Extract plain text without rendering images, styles, or JavaScript
- Support for link numbering (w3m)
- Configurable output cleaning
- Automatic URL protocol handling

## Installation

```bash
cd ~/.pi/agent/skills/fetch-url
uv venv
```

### For Local Mode

Install the required text browsers:

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

### For API Mode

Install Python dependencies:
```bash
uv pip install requests
```

Set your bearer token:
```bash
export FETCH_URL_BEARER="your_token"
```

## Installation

```bash
cd ~/.pi/agent/skills/fetch-url
uv venv
```

Install the required text browsers:

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

## Usage

```bash
uv run fetch.py "<url>" [options]
```

### Options

- `--tool {w3m,lynx}` - Browser to use (default: w3m)
- `--links` - Display link numbers in output (w3m only)
- `--clean` - Remove consecutive empty lines from output
- `--api` - Use API instead of local tools
- `--api-url URL` - Custom API endpoint URL
- `--bearer TOKEN` - Bearer token for API authentication

## Examples

### Local Mode

```bash
# Fetch a URL
uv run fetch.py "https://example.com"

# Use lynx
uv run fetch.py "https://docs.python.org" --tool lynx

# Fetch with link numbers
uv run fetch.py "https://github.com" --links

# Clean output
uv run fetch.py "https://example.com/article" --clean
```

### API Mode

```bash
# Fetch via API
uv run fetch.py "https://orf.at" --api

# Use lynx via API
uv run fetch.py "https://orf.at" --api --tool lynx

# Custom API endpoint
uv run fetch.py "https://example.com" --api --api-url "https://your-api.com/fetch"
```

### Other

```bash
# Pipe to grep
uv run fetch.py "https://example.com" | grep -i "search term"
```

## Configuration

### Local Mode

The skill uses custom configuration files for both browsers:

- `w3m_config` - w3m configuration (UTF-8, cookies, user agent)
- `lynx_config` - lynx configuration (UTF-8, cookies)

### API Mode

Set the bearer token via environment variable or `.env` file:

```bash
# Environment variable
export FETCH_URL_BEARER="your_token"

# Or create .env file
echo "FETCH_URL_BEARER=your_token" > .env
```

Note: If `FETCH_URL_BEARER` is not set, the skill will also check for `WEB_SEARCH_BEARER`.
