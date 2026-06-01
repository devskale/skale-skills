# GitHub with fetch-url

GitHub rendered pages often return HTML soup with text browsers. Use raw URLs for clean content.

## Quick Start

```bash
# GitHub blob URL → raw URL → fetch
fetch-url "https://raw.githubusercontent.com/owner/repo/main/README.md"

# Or just fetch the blob URL — jina handles it
fetch-url "https://github.com/owner/repo/blob/main/README.md"
```

## URL Conversion

| GitHub URL | Raw URL |
|-----------|---------|
| `github.com/{owner}/{repo}/blob/{branch}/{path}` | `raw.githubusercontent.com/{owner}/{repo}/{branch}/{path}` |

```bash
# Pattern:
# github.com/.../blob/main/  →  raw.githubusercontent.com/.../main/
```

## Methods

### fetch-url (recommended)

```bash
fetch-url "https://raw.githubusercontent.com/owner/repo/main/README.md"    # Raw URL
fetch-url "https://github.com/owner/repo/blob/main/docs/guide.md" -v      # Jina auto-selects
```

### curl (for large files, searching)

```bash
# Preview
curl -s https://raw.githubusercontent.com/owner/repo/main/README.md | head -100

# Search
curl -s https://raw.githubusercontent.com/owner/repo/main/README.md | grep -i "install"

# Extract section
curl -s https://raw.githubusercontent.com/owner/repo/main/README.md | sed -n '100,180p'

# Save
curl -s https://raw.githubusercontent.com/owner/repo/main/README.md > readme.txt
```

### gh CLI (for API access)

```bash
gh repo view owner/repo --path README.md
gh api repos/owner/repo/contents/docs --jq '.[].name'
```

## Choosing a Method

| Method | Best For |
|--------|----------|
| **fetch-url** | Quick reads, clean output |
| **curl + head** | Previewing large files |
| **curl + grep** | Searching content |
| **gh CLI** | Authenticated API access |

## Troubleshooting

| Problem | Fix |
|---------|-----|
| HTML soup from blob URL | Use raw URL or `--tool jina` |
| w3m gunzip error | Use `--tool jina` or raw URL |
| Wrong branch | Try `main` vs `master` |
| File too large | Use `curl ... \| head -200` |

## Quick Reference

```bash
# Blob → raw conversion
blob: github.com/{owner}/{repo}/blob/{branch}/{path}
raw:  raw.githubusercontent.com/{owner}/{repo}/{branch}/{path}

# Fetch
fetch-url "<raw-url>"

# Preview
curl -s "<raw-url>" | head -100

# Search
curl -s "<raw-url>" | grep -i "keyword"
```
