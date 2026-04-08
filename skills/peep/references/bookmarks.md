# Bookmarks

## Basic Usage

```bash
peep bookmarks                       # Get recent bookmarks
peep bookmarks -n 50                # Get 50 bookmarks
peep bookmarks --json               # JSON output
peep bookmarks --all                # All bookmarks (paginated)
```

## Bookmark Folders

```bash
peep bookmarks --folder-id 123456789123456789
```

Find folder IDs via: https://x.com/i/bookmarks/<folder-id>

## Thread Expansion

Options to include more context:

| Option | Description |
|--------|-------------|
| `--expand-root-only` | Only expand when bookmark is root tweet |
| `--author-chain` | Include bookmarked author's self-reply chain |
| `--author-only` | All tweets from bookmarked author in thread |
| `--full-chain-only` | Entire reply chain connected to bookmark |
| `--include-ancestor-branches` | Sibling branches for ancestors |
| `--include-parent` | Direct parent tweet for non-root bookmarks |
| `--thread-meta` | Add thread metadata (isThread, threadPosition) |
| `--sort-chronological` | Sort oldest to newest |

## Examples

```bash
# Get all bookmarks with full threads
peep bookmarks --all --full-chain-only

# Include author chains only
peep bookmarks --author-chain

# With thread metadata
peep bookmarks --thread-meta --json

# Chronological order
peep bookmarks --sort-chronological

# Specific folder with expansion
peep bookmarks --folder-id 123 --author-only --json
```

## Unbookmark

```bash
peep unbookmark 1234567890123456789
peep unbookmark https://x.com/user/status/1234567890123456789
peep unbookmark id1 id2 id3
```
