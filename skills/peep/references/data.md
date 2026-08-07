# peep — local data layer

peep is **local-first**: every read silently populates a SQLite cache at `~/.peep/cache.db`
(override with `PEEP_CACHE_DIR`). This powers offline search, starred bookmarks, the AI
inbox, and archive import. Cache writes are best-effort and never break live commands.

## Local cache

```bash
peep cache                                  # stats (tweet/profile/bookmark counts)
peep local-search "typescript"              # offline FTS5 over cached tweets
peep local-search "bug" --author @steipete --since 2025-01-01
```

| `local-search` flag | Effect |
|---|---|
| `-n N` | max results |
| `--author <handle>` | filter by author |
| `--since <date>` / `--until <date>` | date range (`YYYY-MM-DD`) |
| `--json` | machine output |

All read commands (`home`, `search`, `bookmarks`, `likes`, `user-tweets`, `read`,
`mentions`, `following`, `followers`) populate the cache.

## Archive import

Import an X/Twitter data export to search it offline:

```bash
peep archive find                          # scan disk for twitter-*.zip exports
peep archive import ~/Downloads/twitter-2025.zip
```

## Starred bookmarks

First-class bookmark management with personal metadata — treat bookmarks as "things I care about."

### List + filter

```bash
peep starred                               # all starred
peep starred --unread                      # only unread
peep starred --priority critical           # by priority
peep starred --tag "bug,idea"              # by tag (comma = AND)
peep starred --folder "work"               # by folder
peep starred --search "typescript"         # free-text over notes/tags/text
peep starred --sort priority               # sort key
```

### Add metadata (subcommands)

| Subcommand | Effect |
|---|---|
| `peep starred note <id> "follow up on this"` | set a free-text note |
| `peep starred tag <id> "bug,idea,follow-up"` | set tags (comma-separated) |
| `peep starred priority <id> critical` | set priority (see levels below) |
| `peep starred folder <id> "work"` | assign to a folder |
| `peep starred revisit <id>` | flag for later review |
| `peep starred mark-read <id>` | mark as read |
| `peep starred unread <id>` | mark as unread |

### Inspect

```bash
peep starred tags          # all tags in use
peep starred folders       # all folders
peep starred stats         # priority distribution
```

Priority levels: `low` ⚪ · `normal` 🟢 · `high` 🟠 · `critical` 🔴.

## AI Inbox

AI-ranked triage of mentions (and DMs), surfaced from local data.

```bash
peep inbox                                 # ranked inbox (heuristic scoring)
peep inbox --score                         # richer OpenAI analysis (needs OPENAI_API_KEY)
peep inbox --kind mentions -n 10           # filter by kind: mentions | dm | mixed
peep inbox --hide-low-signal --min-score 60
peep inbox --json
```

| Flag | Effect |
|---|---|
| `-n N` | item count |
| `--kind <mentions\|dm\|mixed>` | inbox kind |
| `--score` | run OpenAI scoring (`OPENAI_API_KEY`; model via `PEEP_OPENAI_MODEL`, default `gpt-4o-mini`) |
| `--hide-low-signal` | drop low-signal items |
| `--min-score N` | score floor |
| `--json` | machine output |

Works with heuristic scoring by default; `--score` adds OpenAI only if a key is present.

## Block & mute management

Local-first lists (stored in the cache, not synced to X's server block/mute).

```bash
peep blocks                                # list local blocks
peep blocks --add @username                # or: peep ban @username
peep blocks --remove @username             # or: peep unban @username
peep blocks --import-file list.txt         # handles/URLs, one per line

peep mutes                                 # list local mutes
peep mutes --add @username                 # or: peep mute @username
peep mutes --remove @username              # or: peep unmute @username
```

Aliases: `ban`/`unban` = block/unblock; `mute`/`unmute` = mute/unmute. `--import-file` accepts handles or tweet/profile URLs (one per line).

## Research

Turn bookmarked tweets into a markdown brief — a bookmark-driven thinking tool (inspired by birdclaw's `research`). Walks bookmarks matching a topic, expands each into its full thread, and renders grouped quotes with extracted links and handles.

```bash
peep research "codex" --limit 20 --thread-depth 10   # bookmarks matching a topic
peep research                                          # no query → all bookmarks
peep research --out ~/research/codex.md                # write to a file
peep research "x" --no-live --json                     # local-only JSON envelope
```

Threads reconstruct **locally first** from `~/.peep/cache.db`; a single live `peep thread` fetch per bookmark is a fallback only when ancestors are missing locally (disable with `--no-live`). Run `peep bookmarks` first so there's data to work with.

| Flag | Effect |
|------|--------|
| `[query]` | topic to search within bookmarks (omit for all) |
| `-n, --limit <n>` | max bookmarks to expand (default 20) |
| `--thread-depth <n>` | max tweets per thread (0 = unlimited) |
| `--no-live` | stay fully local — no live thread fallback |
| `--out <path>` | write the brief to a file instead of stdout |
| `--json` | emit `{ query, items, links, handles }` |

`--json` shape: `{ query, generatedAt, items: [{ tweetId, author, authorName, createdAt, url, thread: TweetData[] }], links: string[], handles: string[] }`.

## Profile inspection

```bash
peep profile replies @username -n 20       # scan a user's recent replies for bot/AI behavior
```

Useful before deciding to follow or trust an account: surfaces reply patterns indicative of automation.
