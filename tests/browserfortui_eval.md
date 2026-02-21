# Browser Evaluation Results

**System:** macOS  
**Date:** 2026-02-14

## Tested Browsers

| Browser | Version | Command |
|---------|---------|---------|
| w3m | 0.5.6 | `w3m -dump` |
| chawan (cha) | 0.3.3 | `cha` |

## Test Results

### News Sites

| Site | w3m | chawan |
|------|-----|--------|
| orf.at | ✅ Works | - |
| hackernews.com | - | ✅ Works |

### GitHub

| Site | w3m | chawan |
|------|-----|--------|
| github.com/badlogic/pi-mono | ❌ gzip error | - |
| github.com/trending | ❌ gzip error | - |

### Search Engines

| Site | w3m | chawan |
|------|-----|--------|
| duckduckgo.com | ❌ JavaScript required | - |
| lite.duckduckgo.com/lite | ✅ Works | - |
| cha ddg:query | - | ✅ Works |
| google.com | ⚠️ Cookie banner only | - |
| bing.com | - | - |

### Social

| Site | w3m | chawan |
|------|-----|--------|
| reddit.com | ✅ Works | - |

### Wikipedia

| Site | w3m | chawan |
|------|-----|--------|
| wikipedia.org | ✅ Works | ✅ Works (with JS errors) |
| de.wikipedia.org | - | ✅ Works (with JS errors) |

## Summary

**w3m:** Best for simple, text-heavy sites. Works with orf.at, wikipedia.org, reddit.com. Fails on GitHub (compression) and modern sites requiring JS (duckduckgo, google).

**chawan (cha):** Better rendering for some sites like hackernews. Wikipedia works but with JavaScript errors.

## Recommendation

- **Text browsing:** w3m
- **Interactive sites:** Neither - use headless Chromium
