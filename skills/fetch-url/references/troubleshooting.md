# Troubleshooting

Common issues and solutions for the fetch-url skill.

## Browser Issues

### Browser not found

```bash
# Install w3m or lynx per OS instructions in Setup section
# On Windows, use --tool markdown instead
uv run scripts/fetch.py "https://example.com" --tool markdown
```

### w3m "gunzip: unknown compression format" error

```bash
# Try lynx instead
uv run scripts/fetch.py "https://example.com" --tool lynx
```

### Request timed out

- Try simpler page
- Switch browsers (w3m ↔ lynx)
- Try API mode

## Dependency Issues

### 'requests' library required (API mode or markdown tool)

```bash
uv pip install requests
```

### Venv corruption (dyld/SIGABRT error)

```bash
cd ~/.pi/agent/skills/fetch-url
rm -rf .venv
uv venv
uv pip install requests  # if using API mode
```

## Authentication Issues

### Bearer token required (API mode)

```bash
export FETCH_URL_BEARER="your_token"
# or reuse web-search token
export WEB_SEARCH_BEARER="your_token"
```

## Content Issues

### Incomplete content

- Site may require JavaScript - use `--tool markdown --md-method browser`
- Site blocks text browsers - try API mode or `--tool markdown`

### JS-heavy sites (SPA, React, Vue)

```bash
# Use browser rendering method
uv run scripts/fetch.py "https://spa-site.com" --tool markdown --md-method browser
```

## Blocked Sites

### CAPTCHA/403 blocked sites

```bash
# Try markdown tool to bypass blocks
uv run scripts/fetch.py "https://stackoverflow.com/questions/12345" --tool markdown
uv run scripts/fetch.py "https://www.reddit.com/r/LocalLLaMA/..." --tool markdown
uv run scripts/fetch.py "https://platform.openai.com/docs/..." --tool markdown
```

### Reddit

```bash
# Reddit blocks jina/api, use markdown or w3m/lynx
uv run scripts/fetch.py "https://www.reddit.com/r/..." --tool markdown
uv run scripts/fetch.py "https://www.reddit.com/r/..." --tool w3m
```

## Sites That Don't Work

| Site | Issue | Alternative |
|------|-------|-------------|
| Twitter/X | Requires JS/auth | Use bird/peep skill |
| YouTube | Title only | Use video-transcript skill |
