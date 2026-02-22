---
name: searxng-search
description: DEPRECATED - Use web-search skill instead (auto-selects best backend)
redirect: web-search
---

# SearXNG Search - DEPRECATED

**This skill is deprecated.** Functionality has been merged into the `web-search` skill which automatically selects the best backend.

## Migration

Use `web-search` instead - it automatically uses SearXNG when credentials are available:

```bash
# Old command
searxng-search "query" --categories images

# New command
web-search "query" --categories images
```

All SearXNG features work through web-search with automatic backend selection.
