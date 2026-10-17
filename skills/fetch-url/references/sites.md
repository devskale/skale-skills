# Site Compatibility

Tested tool rankings for popular sites.

## Summary

| Site | Best Tool | Fallback | Notes |
|------|-----------|----------|-------|
| Reddit | w3m | lynx, markdown | jina blocked |
| StackOverflow | markdown | - | jina partial |
| Hacker News | w3m | jina | w3m cleanest |
| GitHub | defuddle | jina, markdown | defuddle: local, README-only, no rate limits |
| Python Docs | defuddle | jina | defuddle: content-only markdown |
| Wikipedia | jina | defuddle, lynx | defuddle richer (links/footnotes), jina leaner |
| Medium | jina | markdown | defuddle/w3m get JS shell |
| MDN | defuddle | jina | defuddle: content-only, half the size |

## Tool Ranking

| Rank | Tool | Score | Best For |
|------|------|-------|----------|
| 🥇 | jina | ⭐⭐⭐⭐⭐ | Docs, blogs, Medium |
| 🥈 | defuddle | ⭐⭐⭐⭐⭐ | GitHub, docs/article pages (local, unlimited) |
| 🥉 | w3m | ⭐⭐⭐⭐ | Reddit, HN, text sites |
| 4 | markdown | ⭐⭐⭐ | Fallback, blocked sites |
| 5 | lynx | ⭐⭐⭐ | Simple, fast |
| 6 | chawan | ⭐⭐ | Visual debugging only |

## Site-Specific Notes

### Reddit
- **jina**: ❌ Blocked ("You've been blocked by network security")
- **markdown**: ⚠️ Partial content
- **w3m**: ✅ Best - clean, readable
- **lynx**: ✅ Good alternative

### StackOverflow
- **jina**: ⚠️ Navigation only, misses code
- **markdown**: ✅ Works, shows question title
- **chawan**: ⚠️ Shows layout but cluttered

### Hacker News
- **jina**: ✅ Good
- **markdown**: ❌ Table rendering broken
- **w3m**: ✅ **Best** - clean formatting

### GitHub
- **defuddle**: ✅ **Best** - local, free, README-only output (13KB vs 20KB w3m nav chrome)
- **jina**: ✅ Clean, but anonymous access gets per-domain abuse blocks (403 for days)
- **markdown**: ✅ Clean
- **w3m**: ❌ Gunzip errors + nav chrome on some pages

### Documentation Sites (Python, MDN, etc.)
- **defuddle**: ✅ **Best** - local, content-only markdown (MDN: 3.9KB vs 7.2KB w3m)
- **jina**: ✅ Good
- **markdown**: ✅ Good
- **w3m**: ⚠️ Navigation-heavy output

### Defuddle notes (added 2026-10, benchmark `references/inspirations.md`)
- Local main-content extraction (Obsidian Web Clipper engine) via `npx defuddle`,
  fetched with curl_cffi (Chrome TLS impersonation). Needs Node.js.
- Nav shells on JS-built pages are detected via wordCount gate (<100 words = shell →
  fallthrough), so it never shadows jina/markdown on JS sites.
- Weak on list/index pages (HN: raw HTML tables) — those stay on w3m.

## Blocked Sites

Sites known to block jina API:
- reddit.com
- twitter.com (use peep skill)
- youtube.com (use video-transcript skill)

## Chawan

Chawan is a modern text browser with CSS/JS support, but output includes box artifacts:

```
┌─────┐
│ Nav │
└─────┘
```

**Use chawan for:**
- Debugging page layout
- Visual structure inspection

**Don't use for:**
- Content extraction (use jina/w3m instead)
