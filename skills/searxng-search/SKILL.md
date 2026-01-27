---
name: searxng-search
description: Programmatic search queries to a SearXNG instance at https://neusiedl.duckdns.org:8002 with basic authentication. Use when searching the web, images, or other content via this private SearXNG instance.
compatibility: opencode
---

# SearXNG Search

## Quick Start

Search using the Python script:

```bash
scripts/search.py "your search query"
```

## Configuration

Before first use, run the setup script to configure your credentials:

```bash
scripts/setup.py
```

This will create a `config.json` file with your credentials.

## Usage

### Basic Search

```bash
scripts/search.py "python web scraping"
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

### Advanced Options

```bash
scripts/search.py "query" --config /path/to/config.json --engines google --categories general --language en --time week
```
