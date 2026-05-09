---
name: peep
description: X/Twitter CLI for reading, searching, posting, and managing bookmarks via cookie auth.
---

# peep

X/Twitter CLI for tweeting, replying, reading, searching, and managing your Twitter/X account via the GraphQL API. Includes local SQLite caching, first-class bookmark management, AI inbox scoring, and tweet rendering.

## Install

```bash
git clone https://github.com/devskale/peep.git
cd peep
pnpm install
pnpm run build
```

### Compiled Binary

A pre-compiled binary is available (no Node.js or native modules needed for core commands):

```bash
curl -sL https://skale.dev/peep/install.sh | sh
```

The binary supports all core commands (read, search, home, tweet, etc.). Cache features (starred, blocks, local-search, etc.) require `node dist/cli.js` with `pnpm install` completed.

## Initial Setup

- **[Initial Setup Guide](references/setup.md)** - Create config.json5, find your browser profiles, and verify setup

## Quick Start

```bash
peep whoami               # Check logged-in account
peep read <url/id>        # Read a tweet
peep 1234567890           # Shorthand for read
peep home                 # Home timeline (For You)
peep home --following     # Following feed
peep search "query"       # Search tweets
peep mentions             # Your mentions
peep user-tweets @x       # User's tweets
peep bookmarks            # Your bookmarks
peep tweet "hello"        # Post a tweet (--allow-write required)
```

**Note:** Use `--json` for JSON output and `--plain` for human-readable output without emojis/colors.

## Commands

### Core

| Command | Description |
|---------|-------------|
| `peep whoami` | Show logged-in account |
| `peep check` | Check credential availability |
| `peep read <url/id>` | Fetch a tweet |
| `peep thread <url/id>` | Full conversation thread |
| `peep replies <url/id>` | Replies to a tweet |
| `peep home` | Home timeline (For You) |
| `peep home --following` | Following feed |
| `peep search <query>` | Search tweets |
| `peep mentions` | Your mentions |
| `peep user-tweets <handle>` | User's profile timeline |
| `peep following [user]` | Who you/they follow |
| `peep followers [user]` | Who follows you/them |
| `peep likes` | Your liked tweets |
| `peep bookmarks` | Your bookmarks |
| `peep unbookmark <id...>` | Remove bookmarks |
| `peep lists` | Your owned Twitter lists |
| `peep lists --member-of` | Lists you're a member of |
| `peep list-timeline <id>` | Tweets from a list |
| `peep news` / `peep trending` | AI-curated news |
| `peep about <user>` | Account origin/location info |
| `peep query-ids [--fresh]` | Inspect/refresh cached GraphQL query IDs |

### Write Commands (disabled by default)

| Command | Description |
|---------|-------------|
| `peep tweet "text"` | Post a tweet |
| `peep reply <id> "text"` | Reply to a tweet |
| `peep follow <user>` | Follow a user |
| `peep unfollow <user>` | Unfollow a user |

Write commands require explicit opt-in: `--allow-write` flag, `PEEP_ALLOW_WRITE=1` env var, or `allowWrite: true` in config.

### Local Cache & Bookmarks

| Command | Description |
|---------|-------------|
| `peep starred` | List starred bookmarks with filters |
| `peep starred note <id> "text"` | Add a note to a bookmark |
| `peep starred tag <id> "tag1,tag2"` | Set tags |
| `peep starred priority <id> <level>` | Set priority: low, normal, high, critical |
| `peep starred folder <id> <name>` | Assign to a folder |
| `peep starred revisit <id>` | Toggle revisit flag |
| `peep starred mark-read <id>` | Mark as read |
| `peep starred unread <id>` | Mark as unread |
| `peep starred tags` | List all tags |
| `peep starred folders` | List all folders |
| `peep starred stats` | Bookmark statistics |
| `peep starred media --all` | Download images for all starred bookmarks |
| `peep starred media --tweet <id>` | Download images for one tweet |
| `peep starred media --stats` | Media cache statistics |
| `peep starred media --list` | List cached media files |
| `peep starred media --clear` | Delete all cached media |
| `peep local-search <query>` | Full-text search over cached tweets |
| `peep cache` | Show cache statistics |
| `peep archive --import <path>` | Import Twitter/X archive |
| `peep blocks` | Manage local blocklist |
| `peep mutes` | Manage local mutelist |
| `peep inbox` | AI-scored inbox from cached mentions |
| `peep profile replies <user>` | Inspect a user's reply behavior |

## Common Options

### Global Options

| Flag | Description |
|------|-------------|
| `--json` | JSON output |
| `--json-full` | JSON with raw API response |
| `--render` | Render tweets with expanded URLs and clean mentions/hashtags |
| `--markdown` | Render tweets as markdown with clickable links |
| `--plain` | Plain output (no emoji/color) |
| `--no-emoji` | Disable emoji output |
| `--no-color` | Disable ANSI colors |
| `--timeout <ms>` | Request timeout |
| `--quote-depth <n>` | Max quoted tweet depth |
| `--allow-write` | Enable write commands |

### Auth Options

| Flag | Description |
|------|-------------|
| `--cookie-source <source>` | Cookie source: chrome, firefox, safari (repeatable) |
| `--chrome-profile <name>` | Chrome profile name (default: Profile 2) |
| `--firefox-profile <name>` | Firefox profile name (default: default-release) |
| `--chrome-profile-dir <path>` | Chrome/Chromium profile directory path |
| `--auth-token <token>` | Twitter auth_token cookie |
| `--ct0 <token>` | Twitter ct0 cookie |

### Starred Filters

| Flag | Description |
|------|-------------|
| `-n, --count <number>` | Number of items (default: 20) |
| `--unread` | Show only unread bookmarks |
| `--revisit` | Show only items flagged for revisiting |
| `--tag <tag>` | Filter by tag |
| `--folder <name>` | Filter by folder |
| `--priority <level>` | Filter by priority |
| `--author <handle>` | Filter by author |
| `--search <query>` | Search in bookmark text |
| `--sort <field>` | Sort by: bookmarked_at, priority, tweet_created_at |

## Tweet Rendering

`--render` and `--markdown` work globally on any command that outputs tweets:

```bash
peep search "geopolitics" -n 5 --render      # Expanded URLs, clean text
peep home --markdown                         # Clickable markdown links
peep bookmarks --all --render                # Bookmarks with full URLs
peep read <id> --markdown                    # Single tweet as markdown
peep user-tweets @handle --render            # User tweets with expanded URLs
```

- `--render`: Expands `t.co` URLs to full URLs, keeps `@mentions` and `#hashtags` as-is
- `--markdown`: Creates `[@user](https://x.com/user)` links, `[display](url)` links, escaped special chars
- `--json` takes precedence (rendering is text-mode only)
- Quoted tweets are also rendered
- Tweets without entities pass through unchanged

## Pagination

For paginated commands (likes, bookmarks, home, search, etc.):

```bash
peep likes                     # Single page (default)
peep likes --all               # Fetch all pages
peep likes --all --max-pages 5 # Limit to 5 pages (requires --all)
peep likes --cursor <string>   # Resume from cursor
peep likes --delay 1000        # Delay between pages (ms)
```

Note: `--max-pages` must be used with `--all` or `--cursor`.

## Local Cache

Peep silently caches fetched tweets, profiles, and media in a local SQLite database at `~/.peep/cache.db`. This enables offline search, bookmark management, and AI inbox scoring.

### Cache Features (require `node dist/cli.js` + `pnpm install`)

The `better-sqlite3` native module is **lazy-loaded** — core commands work without it. Cache features give a clear error if the module is missing.

- **Full-text search**: `peep local-search "query"` over all cached tweets
- **Starred bookmarks**: First-class bookmark management with notes, tags, priority, folders, read/unread state
- **Media caching**: Download images for starred bookmarks with FIFO eviction (100MB default)
- **Archive import**: `peep archive --import <path>` imports Twitter/X data archives
- **Block/mute management**: Local blocklist/mutelist storage
- **AI inbox**: Score cached mentions with OpenAI for priority sorting
- **Profile inspection**: Analyze a user's reply behavior patterns

### Cache Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `PEEP_CACHE_DIR` | Cache directory path | `~/.peep` |
| `PEEP_MEDIA_CACHE_MAX_MB` | Max media cache size in MB | `100` |

## Auth

### Cookie-Based Auth (Recommended)

#### Browser Profiles
```bash
# Firefox (default: default-release)
peep --firefox-profile default-release whoami

# Chrome (default: Profile 2)
peep --chrome-profile "Default" whoami
peep --chrome-profile "Profile 2" whoami

# Chromium-based (Brave, Arc, etc.)
peep --chrome-profile-dir "/path/to/Brave/Profile" whoami
```

#### Cookie Sources
```bash
# Explicit cookie source (avoids Safari default issues)
peep --cookie-source chrome whoami
peep --cookie-source firefox whoami

# Multiple sources (tries in order)
peep --cookie-source chrome --cookie-source firefox whoami
```

#### Manual Tokens
```bash
peep --auth-token <token> --ct0 <token> whoami
```

Or via environment variables:
- `AUTH_TOKEN` or `TWITTER_AUTH_TOKEN`
- `CT0` or `TWITTER_CT0`

## Config & Env

### Config File
`~/.config/peep/config.json5` or `./peeprc.json5`:

```json5
{
  cookieSource: ["chrome"],
  chromeProfile: "Profile 2",
  firefoxProfile: "default-release",
  cookieTimeoutMs: 30000,
  timeoutMs: 20000,
  quoteDepth: 1,
  allowWrite: false,
}
```

### Environment Variables

| Variable | Description |
|----------|-------------|
| `PEEP_TIMEOUT_MS` | Request timeout |
| `PEEP_COOKIE_TIMEOUT_MS` | Cookie extraction timeout |
| `PEEP_QUOTE_DEPTH` | Max quoted tweet depth |
| `PEEP_ALLOW_WRITE` | Enable write commands (`1` or `true`) |
| `PEEP_CACHE_DIR` | Cache directory path |
| `PEEP_MEDIA_CACHE_MAX_MB` | Max media cache size in MB |
| `AUTH_TOKEN` / `TWITTER_AUTH_TOKEN` | Twitter auth token |
| `CT0` / `TWITTER_CT0` | Twitter CSRF token |

## Troubleshooting

### Cookie Authentication Issues

If you see errors like "Failed to read Safari cookies" or "No Twitter cookies found":

**Note:** By default, peep tries Safari first (macOS). If Safari cookies are inaccessible or you're not logged into x.com in Safari, it will fail.

```bash
# Use Chrome explicitly (recommended)
peep --cookie-source chrome whoami

# Use Firefox explicitly
peep --cookie-source firefox whoami

# Try multiple sources (tries in order)
peep --cookie-source chrome --cookie-source firefox whoami

# Specify Chrome profile directly
peep --chrome-profile "Profile 2" whoami
```

### Cookie Priority (How peep finds cookies)

1. **Command-line flags** (`--cookie-source chrome`) - highest priority
2. **Config file** (`~/.config/peep/config.json5`)
3. **Default behavior** - tries Safari on macOS, then other browsers

### Cache Features Unavailable

If you see "Local cache unavailable: better-sqlite3 native module not found":
```bash
pnpm install                    # Install native dependencies
node dist/cli.js starred stats   # Use node runtime (not binary)
```

### Stale Query IDs (most common)

X rotates GraphQL query IDs frequently. If commands fail with HTTP 404 or unexpected errors:
```bash
peep query-ids --fresh    # Force refresh from X's frontend JS bundles
```

### Rate Limited (429)

X rate-limits GraphQL requests. Wait a few minutes and retry. For bulk operations, use `--delay`:
```bash
peep bookmarks --all --delay 2000   # 2s between pages
```

### Expired Cookies (403)

Cookies expire after a period of inactivity. Re-authenticate in your browser:
1. Open x.com in Chrome/Firefox and log in
2. Run `peep check` to verify cookies are readable
3. If stuck, try `peep --cookie-source chrome whoami`

### Lists DecodeException

`peep lists` may show `DecodeException` errors for certain list banners — this is an X server-side issue. The lists data is still returned and usable.

## Extended Docs

- [Initial Setup](references/setup.md) - Create config.json5, find browser profiles, verify setup
- [Auth Details](references/auth.md) - Cookie sources, browser profiles, manual tokens
- [Pagination](references/pagination.md) - All pagination options explained
- [Bookmarks](references/bookmarks.md) - Folder support, thread expansion options
- [News & Trending](references/news.md) - Explore tabs, filters, AI-curated content
- [Media](references/media.md) - Image/video uploads, supported formats
- [JSON Output](references/json.md) - Schema, fields, pagination format
- [Profiling](references/profiling.md) - Building user profile analysis
