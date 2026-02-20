---
name: searxng-search
description: Programmatic search queries to a SearXNG instance. Use when searching the web, images, or other content via this private SearXNG instance.
compatibility: opencode
---

# SearXNG Search

## Quick Start

Search using the Python script (defaults to Markdown output):

**Windows CMD (using search.bat):**
```cmd
search.bat "your search query"
```

**Windows Git Bash / Linux / Mac:**
```bash
./search.sh "your search query"
```

**Any platform (using uv):**
```bash
uv run scripts/search.py "your search query"
```

## Installation

Run the install script to set up the environment and dependencies:

**Windows:**
```cmd
install.bat
```

**Linux/Mac:**
```bash
./install.sh
```

## Configuration

This skill uses `credgoo` to securely manage credentials.

1. Ensure your credentials for `searx` are stored in `credgoo`. The expected format for the credential value is:
   `URL@USERNAME@PASSWORD`

   Example:
   `https://neusiedl.duckdns.org:8002@searxng@searxng23`

## Usage

**Note:** On Windows CMD, use `search.bat`. On Git Bash/Linux/Mac, use `./search.sh`. Or use `uv run` directly.

**Windows CMD:**
```cmd
search.bat "your search query"
```

**Git Bash / Linux / Mac:**
```bash
./search.sh "your search query"
```

**Any platform (using uv):**
```bash
uv run scripts/search.py "your search query"
```

### Basic Search (Markdown)

```bash
uv run scripts/search.py "python web scraping"
```

### JSON Output

To get raw JSON output for programmatic processing:

```bash
uv run scripts/search.py "python web scraping" --json
```

### Filter by Category

Search images, videos, or other categories:

```bash
uv run scripts/search.py "cats" --categories images
uv run scripts/search.py "news" --categories news
```

### Filter by Time Range

```bash
uv run scripts/search.py "ai news" --time day
uv run scripts/search.py "machine learning" --time week
```

### Filter by Search Engines

```bash
uv run scripts/search.py "search engines" --engines google,bing
```

### Custom Language

```bash
uv run scripts/search.py "actualités" --language fr
```

### Limit Results

Control the number of results in Markdown output (default: 5):

```bash
uv run scripts/search.py "query" --num 10
```

### Advanced Options

```bash
uv run scripts/search.py "query" --engines google --categories general --language en --time week
```


---

## Troubleshooting

### Windows: Unicode encoding errors

The script handles UTF-8 encoding automatically. If you still encounter issues, ensure you're using the `search.bat` wrapper or set:

```cmd
set PYTHONIOENCODING=utf-8
python scripts\search.py "your query"
```

### "credgoo library not found" error

This means the virtual environment is not active or credgoo is not installed:

**Windows:**
```cmd
.venv\Scripts\activate.bat
uv pip install --python .venv\Scripts\python.exe -r https://skale.dev/credgoo
```

**Linux/Mac:**
```bash
source .venv/bin/activate
uv pip install --python .venv/bin/python -r https://skale.dev/credgoo
```

### "No credentials found for 'searx' in credgoo" error

Your SearXNG credentials need to be added to credgoo's backend (Google Sheets):

1. Ensure you have access to the credgoo Google Sheets
2. Add a row for service `searx` with value in format: `URL@USERNAME@PASSWORD`
3. Example: `https://neusiedl.duckdns.org:8002@searxng@searxng23`

### "Request failed" error

This indicates a network or authentication issue:

1. Verify your SearXNG instance URL is accessible
2. Check your username and password are correct
3. Ensure the URL format is: `https://your-instance:port@username@password`

### uv command not found

Install uv using the official installer:

**Windows:**
```powershell
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
```

**Linux/Mac:**
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```
