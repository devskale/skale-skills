---
name: fetch-url
description: Fetch and extract readable text content from web pages. Auto-selects best tool with smart fallback. Use when the user wants to read articles, documentation, or scrape text content from web pages. Works on Reddit, StackOverflow, GitHub, docs sites, and more.
metadata:
  author: skale
  version: "2.2"
---

# Fetch URL

Extract text from any webpage. Works globally.

## Usage

```bash
fetch-url "https://example.com"           # Auto-selects best tool
fetch-url "https://reddit.com/r/python"   # Works on blocked sites
fetch-url "URL" -v                        # Verbose (show tool used)
```

## Options

| Option | Description |
|--------|-------------|
| `--tool NAME` | jina, markdown, w3m, lynx, chawan |
| `-v, --verbose` | Show which tool selected |
| `--no-clean` | Keep empty lines |

## Tools (Auto-Selected)

| Tool | Best For |
|------|----------|
| jina | Docs, blogs, Wikipedia (default) |
| w3m | Reddit, Hacker News |
| markdown | Fallback, GitHub |

## Credentials (Optional)

Only needed for `--tool api` mode. Most users don't need this.

```bash
credgoo add FETCH_URL_BEARER
```

## Install

```bash
cd ~/.pi/agent/skills/fetch-url
./install.sh
ln -sf $(pwd)/fetch-url ~/.local/bin/fetch-url  # Make global
```
