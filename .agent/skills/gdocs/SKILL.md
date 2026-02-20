---
name: gdocs
description: Manage and edit Google Docs via gog CLI. Use when the user wants to create, read, update, export, or find/replace content in Google Docs. Triggers on mentions of "gdocs", "Google Docs", "gog docs", or when working with document IDs/URLs starting with "docs.google.com".
---

# Google Docs Management

Work with Google Docs using the `gog` CLI (must be installed and available in PATH).

## Extracting Document ID

From URL `https://docs.google.com/document/d/DOC_ID/edit`:
- The document ID is the segment between `/d/` and `/edit`
- For tab URLs like `.../edit?tab=t.0`, the doc ID is still before `/edit`

## Commands

### Read Document

```bash
# Get document metadata
gog docs info <docId>

# Read document content (first tab only!)
gog docs cat <docId>

# Limit output size
gog docs cat <docId> --max-bytes 10000

# List all tabs (IMPORTANT: docs can have multiple tabs)
gog docs list-tabs <docId>

# Read specific tab by name
gog docs cat <docId> --tab "Tab Name"

# Read all tabs content
gog docs cat <docId> --all-tabs
```

### Create Document

```bash
# Create empty doc
gog docs create "Document Title"

# Create from markdown file
gog docs create "Document Title" --file ./content.md

# JSON output (returns documentId)
gog docs create "Title" --json
```

### Update Document

```bash
# Replace entire content from markdown (DESTRUCTIVE - overwrites all tabs!)
gog docs write <docId> --replace --markdown --file ./content.md

# Update with specific format
gog docs update <docId> --format markdown --content-file ./content.md

# Find and replace text (works across ALL tabs)
gog docs find-replace <docId> "old text" "new text"

# Find-replace returns count of replacements
# Example output: replacements 3  (means 3 occurrences replaced)
```

### Export Document

```bash
# Export to PDF
gog docs export <docId> --format pdf --out ./output.pdf

# Export to DOCX
gog docs export <docId> --format docx --out ./output.docx

# Export to plain text
gog docs export <docId> --format txt --out ./output.txt
```

### Copy Document

```bash
# Copy preserves ALL tabs
gog docs copy <docId> "Copy Title"

# Get new doc ID from JSON output
gog docs copy <docId> "Copy Title" --json
```

### Drive Operations

```bash
# Move file to folder
gog drive move <fileId> --parent <folderId>

# Delete file (needs --force for non-interactive)
gog drive delete <fileId> --force

# List folder contents
gog drive ls --parent <folderId>
```

## JSON Output

Add `--json` flag for machine-readable output:

```bash
gog docs info <docId> --json
gog docs copy <docId> "Title" --json
```

## Critical Rules

### 1. Always Check Tabs First

Documents can have multiple tabs. `docs cat` only reads the first tab by default.

```bash
# ALWAYS do this first for unfamiliar documents
gog docs list-tabs <docId>
```

### 2. Find-Replace Must Match EXACTLY

The search text must match exactly including:
- Whitespace (spaces vs tabs vs newlines)
- Punctuation
- Case

```bash
# This will fail if there's extra space or different linebreak
gog docs find-replace <docId> "Autor: hans" "Autor: bot"

# Verify the exact text first
gog docs cat <docId> | grep -i "autor"
```

### 3. Find-Replace Affects ALL Tabs

A single find-replace operation can modify multiple tabs. Check the `replacements` count:

```bash
# Output: replacements 5  <- means 5 occurrences across all tabs
```

### 4. Backup Before Destructive Edits

`docs write --replace` destroys the entire document including all tabs!

```bash
# SAFE: Backup first
gog docs copy <docId> "Backup $(date +%Y-%m-%d)"

# Then make changes
gog docs write <docId> --replace --markdown --file ./content.md
```

## Workflows

### Safe Edit Workflow

```bash
# 1. List tabs
gog docs list-tabs <docId>

# 2. Read content to understand structure
gog docs cat <docId> --tab "Main"

# 3. Backup before destructive changes
gog docs copy <docId> "Backup"

# 4. Make targeted edits with find-replace
gog docs find-replace <docId> "old" "new"

# 5. Validate changes
gog docs cat <docId> | grep -i "new"
```

### Full Replace Workflow

```bash
# 1. Export current content as backup
gog docs export <docId> --format txt --out backup.txt

# 2. Create new content
cat > new_content.md << 'EOF'
# New Document
Content here...
EOF

# 3. Replace (destructive!)
gog docs write <docId> --replace --markdown --file new_content.md

# 4. Verify
gog docs cat <docId>
```

### Validate Edits Across Tabs

```bash
# Check specific edit across all tabs
gog docs cat <docId> --all-tabs | grep -i "search term"

# Or export and search
gog docs export <docId> --format txt --out check.txt
grep -c "new text" check.txt
```
