# Site Compatibility

Tested tool rankings for popular sites.

## Summary

| Site | Best Tool | Fallback | Notes |
|------|-----------|----------|-------|
| Reddit | w3m | lynx, markdown | jina blocked |
| StackOverflow | markdown | - | jina partial |
| Hacker News | w3m | jina | w3m cleanest |
| GitHub | jina | markdown | Both work |
| Python Docs | jina | - | Clean markdown |
| Wikipedia | jina | - | Clean markdown |
| Medium | jina | - | Clean markdown |

## Tool Ranking

| Rank | Tool | Score | Best For |
|------|------|-------|----------|
| 🥇 | jina | ⭐⭐⭐⭐⭐ | Docs, blogs, GitHub |
| 🥈 | w3m | ⭐⭐⭐⭐ | Reddit, HN, text sites |
| 🥉 | markdown | ⭐⭐⭐ | Fallback, blocked sites |
| 4 | lynx | ⭐⭐⭐ | Simple, fast |
| 5 | chawan | ⭐⭐ | Visual debugging only |

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
- **jina**: ✅ Clean
- **markdown**: ✅ Clean
- **w3m**: ❌ Gunzip errors on some pages

### Documentation Sites (Python, MDN, etc.)
- **jina**: ✅ **Best** - strips nav, clean content
- **markdown**: ✅ Good
- **w3m**: ⚠️ Navigation-heavy output

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
