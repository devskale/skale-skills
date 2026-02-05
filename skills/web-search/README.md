# Web Search Skill for Pi

A DuckDuckGo web search skill for the pi coding agent. Provides rich filtering capabilities including domain filtering, file type filtering, URL fragment matching, and exclusion lists.

## Installation

The skill should be placed at:
```
~/.pi/agent/skills/web_search/
```

## Requirements

- uv
- Python 3
- requests library

## Quick Start

```bash
export WEB_SEARCH_BEARER="your-token-here"
cd ~/.pi/agent/skills/web-search

# Install dependencies
uv pip install requests

# Run search
uv run search.py "your search query"
```

## Features

- **Domain filtering**: Search within specific websites using `--site`
- **File type filtering**: Find specific file types using `--filetype`
- **URL filtering**: Search for URLs containing specific fragments using `--inurl`
- **Exclusion lists**: Exclude certain terms or domains using `--exclude`
- **Exact phrase matching**: Match exact phrases using `--exact`
- **Regional search**: Customize region using `--region`
- **Safe search**: Control content filtering with `--safesearch`
- **Pagination**: Navigate through results using `--page`

## API

The skill uses the DuckDuckGo search API at `https://amd1.mooo.com/api/duck/search`.

### Authentication

Uses Bearer token authentication. Set the token via:
- Environment variable: `WEB_SEARCH_BEARER`
- `.env` file in the skill directory
- Command line argument: `--bearer`

## License

This skill is provided as-is for use with the pi coding agent.
