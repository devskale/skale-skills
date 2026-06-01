# Troubleshooting

Common issues and solutions for fetch-url.

## Browser Issues

### Browser not found

```bash
# Install w3m or lynx
brew install w3m lynx    # macOS
# sudo apt install w3m lynx  # Linux

# Or use API tools instead
fetch-url "https://example.com" --tool markdown
```

### w3m "gunzip" error

```bash
fetch-url "https://example.com" --tool lynx
```

### Request timed out

Switch tools or try a simpler page.

## Dependency Issues

### Venv corruption

```bash
fetch-url --update
```

## Content Issues

### Incomplete content

- Site may require JavaScript: `--tool markdown --md-method browser`
- Site blocks text browsers: `--tool jina`

### JS-heavy sites (SPA, React, Vue)

```bash
fetch-url "https://spa-site.com" --tool markdown --md-method browser
```

## Blocked Sites

### CAPTCHA/403 blocked sites

```bash
fetch-url "https://stackoverflow.com/questions/12345" --tool markdown
fetch-url "https://platform.openai.com/docs/..." --tool jina
```

### Reddit

```bash
# Reddit auto-redirects to old.reddit.com — just use it normally
fetch-url "https://www.reddit.com/r/..."
```

## Sites That Don't Work

| Site | Issue | Alternative |
|------|-------|-------------|
| Twitter/X | Requires JS/auth | Use peep skill |
| YouTube | Title only | Use video-transcript skill |
