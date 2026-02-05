---
name: searxng-search
description: Programmatic search queries to a SearXNG instance. Use when searching the web, images, or other content via this private SearXNG instance.
compatibility: opencode
---

# SearXNG Search

## Quick Start

Search using the Python script (defaults to Markdown output):

```bash
scripts/search.py "your search query"
```

## Installation

Run the install script to set up the environment and dependencies:

```bash
./install.sh
```

## Configuration

This skill uses `credgoo` to securely manage credentials.

1. Ensure your credentials for `searx` are stored in `credgoo`. The expected format for the credential value is:
   `URL@USERNAME@PASSWORD`

   Example:
   `https://neusiedl.duckdns.org:8002@searxng@sear####`

## Usage

**Note:** Always activate the virtual environment before running the scripts, or run them using the python executable in the virtual environment.

```bash
source .venv/bin/activate
scripts/search.py "your search query"
```

### Basic Search (Markdown)

```bash
scripts/search.py "python web scraping"
```

### JSON Output

To get raw JSON output for programmatic processing:

```bash
scripts/search.py "python web scraping" --json
```

### Filter by Category

Search images, videos, or other categories:

```bash
scripts/search.py "cats" --categories images
scripts/search.py "news" --categories news
```

### Filter by Time Range

```bash
scripts/search.py "ai news" --time day
scripts/search.py "machine learning" --time week
```

### Filter by Search Engines

```bash
scripts/search.py "search engines" --engines google,bing
```

### Custom Language

```bash
scripts/search.py "actualités" --language fr
```

### Limit Results

Control the number of results in Markdown output (default: 5):

```bash
scripts/search.py "query" --num 10
```

### Advanced Options

```bash
scripts/search.py "query" --engines google --categories general --language en --time week
```
