---
name: fetch-url
description: Fetch and extract readable text content from web pages. Auto-selects best tool with smart fallback. Use when the user wants to read articles, documentation, or scrape text content from web pages. Works on Reddit, StackOverflow, GitHub, docs sites, and more.
metadata:
  author: skale
  version: "2.1"
---

# Fetch URL

Extract text from any webpage.

## Usage

```bash
cd ~/.pi/agent/skills/fetch-url

# Just works
./fetch-url "https://example.com"

# Blocked sites too (Reddit, StackOverflow)
./fetch-url "https://reddit.com/r/python"
```

## Install

```bash
cd ~/.pi/agent/skills/fetch-url
./install.sh
```

## Options

```bash
./fetch-url "URL"                    # Auto (recommended)
./fetch-url "URL" --tool jina        # Force tool
./fetch-url "URL" -v                 # Verbose (show tool used)
./fetch-url "URL" --no-clean         # Keep empty lines
./fetch-url "URL" --md-method browser  # JS-heavy sites
```

| Option | Description |
|--------|-------------|
| `--tool NAME` | jina, markdown, w3m, lynx, chawan |
| `-v, --verbose` | Show which tool selected |
| `--no-clean` | Keep empty lines |
| `--md-method browser` | For JS SPAs |

## Tools

| Rank | Tool | Best For | Platform |
|------|------|----------|----------|
| 🥇 | jina | Docs, blogs, Wikipedia | All |
| 🥈 | w3m | Reddit, Hacker News | macOS/Linux |
| 🥉 | markdown | Fallback, GitHub | All |
| 4 | lynx | Simple reads | macOS/Linux |
| 5 | chawan | Visual debugging | macOS |

## Optional Browsers

Not required - jina/markdown work everywhere.

```bash
brew install w3m lynx chawan  # macOS
```

## Credentials (Optional)

Only for `--tool api` mode:

```bash
credgoo add FETCH_URL_BEARER
```

## Troubleshooting

See [references/troubleshooting.md](references/troubleshooting.md)
