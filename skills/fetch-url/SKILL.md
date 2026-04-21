---
name: fetch-url
description: Fetch and extract readable text content from web pages. Auto-selects best tool with smart fallback. Use when the user wants to read articles, documentation, or scrape text content from web pages. Works on Reddit, StackOverflow, GitHub, docs sites, and more.
metadata:
  author: skale
  version: "2.6"
---

# Fetch URL

Extract text from any webpage. Works globally.

## Setup

### 1. Install the skill

```bash
cd ~/.pi/agent/skills/fetch-url
./install.sh   # Installs deps + credgoo + creates ~/.local/bin/fetch-url wrapper
```

> `./install.sh` runs `uv sync` which installs credgoo automatically. No separate install needed.

### 2. Optional browsers (for better fallback tools)

```bash
# Debian/Ubuntu
sudo apt-get install w3m lynx

# macOS
brew install w3m lynx chawan
```

### 3. Verify

```bash
fetch-url "https://example.com" -v   # Should show which tool was used
```

## Usage

```bash
fetch-url "https://example.com"           # Auto-selects best tool
fetch-url "https://reddit.com/r/python"   # Works on blocked sites
fetch-url "URL" --tool jina              # Force specific tool
fetch-url "URL" -v                        # Verbose (show tool used)
```

## Options

| Option | Description |
|--------|-------------|
| `--tool NAME` | jina, chrome, markdown, w3m, lynx, chawan |
| `-v, --verbose` | Show which tool selected |
| `--no-clean` | Keep empty lines |

## Tools (Auto-Selected)

| Tool | Best For |
|------|----------|
| jina | Docs, blogs, arXiv, Medium (default) |
| chrome | Cloudflare/JS-protected sites (firmenabc.at, etc.) |
| w3m | Reddit, Hacker News |
| markdown | Fallback, GitHub |

## Edge Cases

- **Cloudflare-protected sites** (firmenabc.at, etc.): Auto-detected, uses `chrome` headless to solve JS challenges
- **Reddit**: `w3m` may only return navigation elements; try `--tool jina` for post content
- **StackOverflow**: May redirect to different questions; verify URL is canonical
- **Wikipedia**: Can return empty results; try `--tool w3m` as fallback
