# News & Trending

Fetch AI-curated news and trending topics from X's Explore page tabs.

## Basic Usage

```bash
peep news                    # Fetch 10 news items
peep trending                # Alias for news
peep news -n 20             # More results
peep news --json            # JSON output
```

## Tab Filters

| Option | Description |
|--------|-------------|
| `--for-you` | For You tab |
| `--news-only` | News tab |
| `--sports` | Sports tab |
| `--entertainment` | Entertainment tab |
| `--trending-only` | Trending tab |
| `--ai-only` | Only AI-curated headlines |

## Examples

```bash
# All tabs (default)
peep news -n 10

# AI-curated only
peep news --ai-only -n 20

# Sports only
peep news --sports

# Combine filters
peep news --sports --entertainment -n 20

# Include related tweets
peep news --with-tweets --tweets-per-item 3
```

## JSON Output

```bash
peep news --json
peep news --json-full    # Includes raw API response
```

Fields in JSON:
- `id` - Unique identifier
- `headline` - News headline
- `category` - Category (e.g., "AI · Technology", "Sports")
- `timeAgo` - Relative time (e.g., "2h ago")
- `postCount` - Number of posts
- `description` - Item description
- `url` - URL to trend/article
- `tweets` - Related tweets (with `--with-tweets`)
- `_raw` - Raw API (with `--json-full`)
