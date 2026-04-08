---
name: peep
description: X/Twitter CLI for reading, searching, and posting via cookie auth.
---

# peep

X/Twitter CLI for tweeting, replying, reading, searching, and managing your Twitter/X account via the GraphQL API.

## Install

```bash
git clone https://github.com/devskale/peep.git
cd peep
pnpm install
pnpm run build
```

## Initial Setup

After installation, configure peep with default settings:

- **[Initial Setup Guide](references/setup.md)** - Create config.json5, find your browser profiles, and verify setup

## Quick Start

```bash
peep whoami          # Check logged-in account
peep read <url/id>   # Read a tweet
peep 1234567890      # Shorthand for read
peep home            # Home timeline
peep search "query"  # Search tweets
peep mentions        # Your mentions
peep user-tweets @x  # User's tweets
peep bookmarks       # Your bookmarks
peep tweet "hello"   # Post a tweet (confirm first!)
```

**Note:** JSON output is enabled by default in the config file. Use `--plain` for human-readable output without emojis/colors.

## Commands

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
| `peep lists` | Your Twitter lists |
| `peep list-timeline <id>` | Tweets from a list |
| `peep news` / `peep trending` | AI-curated news |
| `peep about <user>` | Account origin/location info |
| `peep tweet "text"` | Post a tweet |
| `peep reply <id> "text"` | Reply to a tweet |
| `peep follow <user>` | Follow a user |
| `peep unfollow <user>` | Unfollow a user |

## Common Options

| Flag | Description |
|------|-------------|
| `--json` | JSON output |
| `--json-full` | JSON with raw API response |
| `--plain` | Plain output (no emoji/color) |
| `--timeout <ms>` | Request timeout |
| `--cookie-source <source>` | Cookie source: chrome, firefox, safari (repeatable) |
| `--chrome-profile <name>` | Chrome profile name (default: Profile 2) |
| `--firefox-profile <name>` | Firefox profile name (default: default-release) |
| `--chrome-profile-dir <path>` | Chrome/Chromium profile directory path |
| `--quote-depth <n>` | Max quoted tweet depth |

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
peep --cookie-source safari whoami

# Multiple sources (tries in order)
peep --cookie-source firefox --cookie-source chrome whoami
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
  cookieSource: ["chrome", "firefox"],
  chromeProfile: "Profile 2",
  firefoxProfile: "default-release",
  cookieTimeoutMs: 30000,
  timeoutMs: 20000,
  quoteDepth: 1
}
```

### Environment Variables
- `PEEP_TIMEOUT_MS` - Request timeout
- `PEEP_COOKIE_TIMEOUT_MS` - Cookie extraction timeout
- `PEEP_QUOTE_DEPTH` - Max quoted tweet depth
- `AUTH_TOKEN` / `TWITTER_AUTH_TOKEN` - Twitter auth token
- `CT0` / `TWITTER_CT0` - Twitter CSRF token

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
peep --chrome-profile-dir "$HOME/Library/Application Support/Google/Chrome/Profile 2" whoami
```

### Cookie Priority (How peep finds cookies)

1. **Command-line flags** (`--cookie-source chrome`) - highest priority
2. **Config file** (`~/.config/peep/config.json5`)
3. **Default behavior** - tries Safari on macOS, then other browsers

### Finding Chrome Profile
```bash
# List Chrome profiles on macOS
ls -la ~/Library/Application\ Support/Google/Chrome/

# Common profile names:
# - Default
# - Profile 1, Profile 2, Profile 3, etc.
```

### Cookie Extraction Timeout
If cookie extraction fails, increase timeout:
```bash
peep --cookie-timeout 60000 whoami   # 60 seconds
```

## Extended Docs

- [Initial Setup](references/setup.md) - Create config.json5, find browser profiles, verify setup
- [Auth Details](references/auth.md) - Cookie sources, browser profiles, manual tokens
- [Pagination](references/pagination.md) - All pagination options explained
- [Bookmarks](references/bookmarks.md) - Folder support, thread expansion options
- [News & Trending](references/news.md) - Explore tabs, filters, AI-curated content
- [Media](references/media.md) - Image/video uploads, supported formats
- [JSON Output](references/json.md) - Schema, fields, pagination format
