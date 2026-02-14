# GitHub Pages with fetch-url

GitHub rendered pages are complex and text browsers often return HTML soup instead of clean markdown. This guide covers strategies for fetching GitHub content.

## Quick Start

When fetch-url returns HTML soup from GitHub, convert the URL to raw format:

```bash
# GitHub blob URL (returns HTML soup)
https://github.com/owner/repo/blob/main/README.md

# → Convert to raw URL
https://raw.githubusercontent.com/owner/repo/main/README.md

# Then fetch
cd ~/.pi/agent/skills/fetch-url
uv run fetch.py "https://raw.githubusercontent.com/owner/repo/main/README.md"
```

## Why GitHub is Difficult

- **Complex rendering**: GitHub serves HTML with navigation, avatars, and interactive elements
- **Text browser limitations**: w3m/lynx can't parse complex structure well
- **Mixed content**: You get page chrome, not just file content

**Example issue with fetch-url:**
```bash
# This returns HTML soup with hundreds of avatar links
uv run fetch.py "https://github.com/owner/repo/blob/main/README.md"
```

## URL Conversion Patterns

### GitHub to Raw GitHub

| GitHub URL Type | Format | Example |
|----------------|--------|----------|
| **Blob view** | `https://github.com/{owner}/{repo}/blob/{branch}/{path}` | `https://github.com/openclaw/openclaw/blob/main/README.md` |
| **Raw content** | `https://raw.githubusercontent.com/{owner}/{repo}/{branch}/{path}` | `https://raw.githubusercontent.com/openclaw/openclaw/main/README.md` |

### Converting URLs Manually

```bash
# GitHub blob URL
https://github.com/owner/repo/blob/main/docs/guide.md

# → Replace with raw URL
https://raw.githubusercontent.com/owner/repo/main/docs/guide.md

# Pattern: Replace "github.com/.../blob/" with "raw.githubusercontent.com/.../"
```

## Method 1: fetch-url with Raw URLs

Best for: Quick reads of small to medium markdown files.

```bash
cd ~/.pi/agent/skills/fetch-url

# Direct fetch of raw README
uv run fetch.py "https://raw.githubusercontent.com/openclaw/openclaw/main/README.md"

# Any markdown file
uv run fetch.py "https://raw.githubusercontent.com/owner/repo/main/docs/guide.md"

# Clean output (remove empty lines)
uv run fetch.py "https://raw.githubusercontent.com/owner/repo/main/README.md" --clean
```

## Method 2: curl Directly

Best for: Large files, specific sections, searching content.

### Basic Fetch

```bash
# Get full content
curl -s https://raw.githubusercontent.com/owner/repo/main/README.md

# Save to file
curl -s https://raw.githubusercontent.com/owner/repo/main/README.md > readme.txt

# Display with line numbers
curl -s https://raw.githubusercontent.com/owner/repo/main/README.md | cat -n
```

### Preview Large Files

```bash
# First 100 lines
curl -s https://raw.githubusercontent.com/owner/repo/main/README.md | head -100

# First 200 lines
curl -s https://raw.githubusercontent.com/owner/repo/main/README.md | head -200

# Last 100 lines
curl -s https://raw.githubusercontent.com/owner/repo/main/README.md | tail -100
```

### Extract Specific Sections

```bash
# Lines 100-180
curl -s https://raw.githubusercontent.com/owner/repo/main/README.md | sed -n '100,180p'

# Multiple ranges (lines 1-50 and 150-200)
curl -s https://raw.githubusercontent.com/owner/repo/main/README.md | sed -n '1,50p;150,200p'
```

### Search Content

```bash
# Case-insensitive search
curl -s https://raw.githubusercontent.com/owner/repo/main/README.md | grep -i "keyword"

# Show line numbers
curl -s https://raw.githubusercontent.com/owner/repo/main/README.md | grep -n -i "keyword"

# Get context (2 lines before/after)
curl -s https://raw.githubusercontent.com/owner/repo/main/README.md | grep -C 2 -i "keyword"

# Search for multiple terms
curl -s https://raw.githubusercontent.com/owner/repo/main/README.md | grep -E "(keyword1|keyword2)"
```

## Method 3: GitHub CLI (gh)

Best for: GitHub API access, authenticated requests.

### Installation

```bash
# macOS
brew install gh

# Linux
sudo apt install gh

# Or visit: https://cli.github.com/
```

### Usage

```bash
# View file in terminal
gh repo view owner/repo --path README.md

# Get raw content (base64 encoded)
gh api repos/owner/repo/contents/README.md \
  -q '.content' \
  -H "Accept: application/vnd.github.raw" \
  | base64 -d

# List files in a directory
gh api repos/owner/repo/contents/docs --jq '.[].name'

# Get file with auth required
gh api repos/owner/repo/contents/config.json \
  -H "Accept: application/vnd.github.raw"
```

## Choosing a Method

| Method | Best For | Pros | Cons |
|---------|-----------|-------|-------|
| **fetch-url + raw URL** | Quick reads, small-medium files | Uses fetch-url skill, clean output, consistent formatting |
| **curl + head** | Previewing large files | Fast, no dependency, no line highlighting |
| **curl + sed** | Extracting sections | Precise control, requires sed knowledge |
| **curl + grep** | Searching content | Fast pattern matching, no context by default |
| **gh CLI** | Authenticated access, API integration | Requires installation and auth |

## Common Workflows

### Read GitHub README

```bash
# Fast preview
curl -s https://raw.githubusercontent.com/owner/repo/main/README.md | head -100

# Full content with fetch-url
cd ~/.pi/agent/skills/fetch-url
uv run fetch.py "https://raw.githubusercontent.com/owner/repo/main/README.md"
```

### Find Installation Instructions

```bash
# Search for install section
curl -s https://raw.githubusercontent.com/owner/repo/main/README.md | grep -i -A 10 "install"

# Find setup section
curl -s https://raw.githubusercontent.com/owner/repo/main/README.md | grep -i -A 10 "setup"

# Extract usage examples
curl -s https://raw.githubusercontent.com/owner/repo/main/README.md | grep -A 5 -i "example\|usage"
```

### Read Multiple Files

```bash
# Read README and package.json
curl -s https://raw.githubusercontent.com/owner/repo/main/README.md | head -50
curl -s https://raw.githubusercontent.com/owner/repo/main/package.json

# Read specific docs
curl -s https://raw.githubusercontent.com/owner/repo/main/docs/api.md
curl -s https://raw.githubusercontent.com/owner/repo/main/docs/guide.md
```

### Check License

```bash
# Get LICENSE file content
curl -s https://raw.githubusercontent.com/owner/repo/main/LICENSE

# Extract license type
curl -s https://raw.githubusercontent.com/owner/repo/main/LICENSE | head -5 | grep -i "mit\|apache\|gpl"
```

### Get Dependencies

```bash
# Read package.json dependencies
curl -s https://raw.githubusercontent.com/owner/repo/main/package.json | grep -A 20 "dependencies"

# Read requirements.txt
curl -s https://raw.githubusercontent.com/owner/repo/main/requirements.txt

# Read Cargo.toml
curl -s https://raw.githubusercontent.com/owner/repo/main/Cargo.toml | grep -A 10 "\[dependencies\]"
```

## Troubleshooting

### fetch-url with GitHub returns HTML soup

**Symptom:** You see hundreds of avatar links and navigation elements.

**Solution:** Use raw URL
```bash
# Instead of:
uv run fetch.py "https://github.com/owner/repo/blob/main/file.md"

# Use:
uv run fetch.py "https://raw.githubusercontent.com/owner/repo/file.md"
```

### curl: "No such file or directory"

**Cause:** Incorrect branch or path.

**Solution:** Verify URL in browser first
```bash
# Check actual branch name (could be master instead of main)
curl -s https://raw.githubusercontent.com/owner/repo/main/file.md

# Try different branch
curl -s https://raw.githubusercontent.com/owner/repo/master/file.md

# Check directory structure
curl -s https://raw.githubusercontent.com/owner/repo/main/ | head
```

### File too large

**Cause:** README or file is thousands of lines long.

**Solution:** Use head/tail or section extraction
```bash
# Preview first part
curl -s https://raw.githubusercontent.com/owner/repo/main/README.md | head -200

# Get specific section
curl -s https://raw.githubusercontent.com/owner/repo/main/README.md | sed -n '100,200p'

# Search for keywords instead of reading entire file
curl -s https://raw.githubusercontent.com/owner/repo/main/README.md | grep -i "installation\|setup"
```

### Need to render GitHub pages properly

**Solution:** Use a different skill
- **web-browser skill**: For full JavaScript rendering
- **GitHub CLI (gh)**: For API access
- **GitHub website**: In a real browser

### w3m "gunzip: unknown compression format" error

**Symptom:** fetch-url fails with gunzip error.

**Solutions:**
```bash
# Try lynx instead
uv run fetch.py "https://github.com/owner/repo/blob/main/file.md" --tool lynx

# Or use raw URL with curl
curl -s https://raw.githubusercontent.com/owner/repo/main/README.md
```

## Quick Reference Card

```bash
# Convert GitHub blob to raw
blob: https://github.com/{owner}/{repo}/blob/{branch}/{path}
raw:  https://raw.githubusercontent.com/{owner}/{repo}/{branch}/{path}

# Fetch with fetch-url
cd ~/.pi/agent/skills/fetch-url
uv run fetch.py "<raw-url>"

# Preview with curl
curl -s "<raw-url>" | head -100

# Extract section with curl
curl -s "<raw-url>" | sed -n 'START,ENDp'

# Search with curl
curl -s "<raw-url>" | grep -i "keyword"

# Use GitHub CLI
gh repo view owner/repo --path file.md
```

## Examples

### Example 1: Quick README Preview

```bash
curl -s https://raw.githubusercontent.com/openclaw/openclaw/main/README.md | head -100
```

### Example 2: Read Specific Section

```bash
# Lines 100-180 of OpenClaw README
curl -s https://raw.githubusercontent.com/openclaw/openclaw/main/README.md | sed -n '100,180p'
```

### Example 3: Find Installation Commands

```bash
curl -s https://raw.githubusercontent.com/openclaw/openclaw/main/README.md | grep -i -A 10 "install"
```

### Example 4: Search for Features

```bash
curl -s https://raw.githubusercontent.com/openclaw/openclaw/main/README.md | grep -i -C 2 "feature\|capability"
```

### Example 5: Get License Information

```bash
curl -s https://raw.githubusercontent.com/openclaw/openclaw/main/LICENSE
```

### Example 6: Using fetch-url with Raw URL

```bash
cd ~/.pi/agent/skills/fetch-url
uv run fetch.py "https://raw.githubusercontent.com/openclaw/openclaw/main/README.md" --clean
```
