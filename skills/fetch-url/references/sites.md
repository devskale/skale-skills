# Site Compatibility Guide

Quick reference for which tools work best on popular websites.

## Tool Legend

| Symbol | Meaning |
|--------|---------|
| ✅ | Works perfectly |
| ⚠️ | Partial/messy output |
| ❌ | Blocked or fails |

## Major Sites

| Site | jina | markdown | w3m | lynx | chawan | Best Tool | Notes |
|------|:----:|:--------:|:---:|:----:|:------:|-----------|-------|
| **Reddit** | ❌ | ✅ | ✅ | ✅ | ✅ | `markdown` or `chawan` | jina/api blocked |
| **StackOverflow** | ❌ | ✅ | ❌ | ⚠️ | ✅ | `chawan` or `markdown` | chawan gets full code! |
| **Hacker News** | ✅ | ⚠️ | ✅ | ✅ | ✅ | `jina` or `chawan` | cleanest output |
| **Medium** | ✅ | ✅ | ❌ | ✅ | ❌ | `jina` | chawan blocked by Cloudflare |
| **Wikipedia** | ✅ | ✅ | ✅ | ✅ | ✅ | `jina` | Works with all tools |
| **arXiv** | ✅ | ✅ | ✅ | ✅ | ✅ | `jina` | Abstracts, metadata |
| **GitHub** | ✅ | ✅ | ✅ | ✅ | ✅ | `jina` | Repo pages, READMEs |
| **Twitter/X** | ❌ | ❌ | ❌ | ❌ | ❌ | - | Requires auth - use bird/peep skill |
| **YouTube** | ⚠️ | ⚠️ | ❌ | ❌ | ❌ | - | Title only - use video-transcript skill |
| **OpenAI Docs** | ✅ | ✅ | ❌ | ⚠️ | ✅ | `markdown` | Full documentation |
| **Anthropic Docs** | ✅ | ✅ | ✅ | ✅ | ✅ | `jina` | Full documentation |

## Austrian/European Sites

| Site | jina | markdown | w3m | lynx | chawan | Best Tool | Notes |
|------|:----:|:--------:|:---:|:----:|:------:|-----------|-------|
| **geizhals.at** | ✅ | ✅ | ✅ | ✅ | ✅ | `jina` | Price comparison |
| **willhaben.at** | ✅ | ✅ | ❌ | ✅ | ⚠️ | `jina` | w3m fails (gunzip), chawan limited |
| **orf.at** | ✅ | ✅ | ✅ | ✅ | ✅ | `jina` | Excellent article extraction |
| **derstandard.at** | ✅ | ✅ | ✅ | ✅ | ✅ | `jina` | News articles |
| **heise.de** | ✅ | ✅ | ✅ | ✅ | ✅ | `jina` | Tech news |

## Technical Sites

| Site | jina | markdown | w3m | lynx | chawan | Best Tool | Notes |
|------|:----:|:--------:|:---:|:----:|:------:|-----------|-------|
| **react.dev** | ✅ | ✅ | ✅ | ✅ | ✅ | `jina` | SPA with SSR |
| **docs.python.org** | ✅ | ✅ | ✅ | ✅ | ✅ | `jina` | Documentation |
| **realpython.com** | ✅ | ✅ | ✅ | ✅ | ✅ | `jina` | Tutorials |
| **rust-lang.org** | ✅ | ✅ | ✅ | ✅ | ✅ | `jina` | Documentation |

## Troubleshooting by Site

### Reddit
```bash
# jina/api return 403 - use markdown, chawan, or browsers
uv run scripts/fetch.py "https://www.reddit.com/r/..." --tool chawan
uv run scripts/fetch.py "https://www.reddit.com/r/..." --tool markdown
uv run scripts/fetch.py "https://www.reddit.com/r/..." --tool w3m
```

### StackOverflow
```bash
# CAPTCHA blocks jina - chawan is best (gets full code blocks!)
uv run scripts/fetch.py "https://stackoverflow.com/questions/12345" --tool chawan
uv run scripts/fetch.py "https://stackoverflow.com/questions/12345" --tool markdown
```

### Hacker News
```bash
# All tools work - chawan or jina give cleanest output
uv run scripts/fetch.py "https://news.ycombinator.com" --tool chawan
uv run scripts/fetch.py "https://news.ycombinator.com" --tool jina
```

### Willhaben (Austria)
```bash
# w3m fails with gunzip error, chawan limited
uv run scripts/fetch.py "https://www.willhaben.at/iad" --tool jina
uv run scripts/fetch.py "https://www.willhaben.at/iad" --tool lynx  # alternative
```

### Medium
```bash
# chawan blocked by Cloudflare, w3m needs JS
uv run scripts/fetch.py "https://medium.com/@user/article" --tool jina
uv run scripts/fetch.py "https://medium.com/@user/article" --tool lynx
```

## General Recommendations

| Scenario | Recommended Tool |
|----------|------------------|
| Default/unknown site | `jina` (auto-selected) |
| CAPTCHA/403 errors | `markdown` |
| StackOverflow (with code) | `chawan` |
| Reddit | `chawan` or `markdown` |
| Clean text lists | `w3m` or `chawan` |
| Quick/simple pages | `lynx` |
| Austrian sites | `jina` |
| Documentation | `jina` |

## Installing Chawan

Chawan is a modern text browser with CSS and JavaScript support:

```bash
# macOS
brew install chawan

# Linux - see https://github.com/devskale/chawan
```

**Why Chawan?**
- Better CSS rendering than w3m/lynx
- JavaScript support (useful for some sites)
- Excellent for StackOverflow (gets full code blocks)
- Works well for Reddit
