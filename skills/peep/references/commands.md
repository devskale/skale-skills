# peep — full command + flag reference

peep reuses your logged-in X/Twitter session (cookie auth). `peep help [command]` shows the authoritative surface; this mirrors it. Global flags (apply to most commands) are listed last.

## Read / conversation

| Command | Flags | Notes |
|---|---|---|
| `read <id-or-url>` | `--json`, `--json-full` | Fetch one tweet. Bare ID or full URL both accepted. Returns full text for Notes/Articles. |
| `<id-or-url>` | `--json` | Shorthand for `read`. |
| `thread <id-or-url>` | `--all`, `--max-pages N`, `--cursor <s>`, `--delay ms`, `--json` | Author's self-reply chain. |
| `replies <id-or-url>` | `--all`, `--max-pages N`, `--cursor <s>`, `--delay ms`, `--json` | Everyone's replies to a tweet. `--max-pages` needs `--all`/`--cursor`. |

## Search & mentions

| Command | Flags | Notes |
|---|---|---|
| `search "<query>"` | `-n N`, `--all`, `--max-pages N`, `--cursor <s>`, `--json` | `from:user`, `since:`/`until:YYYY-MM-DD`, `#hashtag`, `-exclude`. `--max-pages` needs `--all`/`--cursor`. |
| `mentions` | `-n N`, `--user @handle`, `--json` | Tweets mentioning you (or `--user`). |

## Feeds

| Command | Flags | Notes |
|---|---|---|
| `home` | `-n N`, `--following`, `--json`, `--json-full` | "For You" feed; `--following` = following feed. |
| `bookmarks` | `-n N`, `--folder-id <id>`, `--all`, `--max-pages N`, `--cursor <s>`, `--json` + expansion flags below | Your bookmarks or a folder (`https://x.com/i/bookmarks/<folder-id>`). |
| `likes` | `-n N`, `--all`, `--max-pages N`, `--cursor <s>`, `--json`, `--json-full` | Your likes. |

### Bookmarks expansion flags (control thread context)

| Flag | Effect |
|---|---|
| `--expand-root-only` | expand threads only when the bookmark is a root tweet |
| `--author-chain` | keep only the bookmarked author's connected self-reply chain |
| `--author-only` | include all tweets from the bookmarked author within the thread |
| `--full-chain-only` | keep the entire reply chain connected to the bookmark (all authors) |
| `--include-ancestor-branches` | include sibling branches for ancestors (with `--full-chain-only`) |
| `--include-parent` | include the direct parent tweet for non-root bookmarks |
| `--thread-meta` | add thread metadata fields to each tweet |
| `--sort-chronological` | sort output oldest→newest (default preserves bookmark order) |

## User content

| Command | Flags | Notes |
|---|---|---|
| `user-tweets <@handle>` | `-n N`, `--cursor <s>`, `--max-pages N`, `--delay ms`, `--json` | Profile timeline. Auto-paginates when `-n > 20`. |
| `about <@handle>` | `--json` | Account origin/location (`accountBasedIn`, `locationAccurate`, …). |

## News & trending (Explore tabs)

| Command | Flags | Notes |
|---|---|---|
| `news` (alias `trending`) | `-n N`, `--ai-only`, `--with-tweets`, `--tweets-per-item N`, `--for-you`, `--news-only`, `--sports`, `--entertainment`, `--trending-only`, `--json`, `--json-full` | AI-curated news. Default tabs: For You, News, Sports, Entertainment (Trending excluded). Headlines deduped across tabs. |

Tab flags combine. `--ai-only` filters out regular trends. `--with-tweets` attaches related tweets (limit via `--tweets-per-item`). `--json-full` includes the raw API response per item.

## Lists

| Command | Flags | Notes |
|---|---|---|
| `lists` | `--member-of`, `-n N`, `--json` | Your lists (owned or memberships). |
| `list-timeline <list-id-or-url>` | `-n N`, `--all`, `--max-pages N`, `--cursor <s>`, `--json` | Tweets from a list. `--max-pages` implies `--all`. |

> `lists` / `list-timeline` do **not** yet support `--cursor`/`--max-pages` pagination for `lists` itself.

## Social graph

| Command | Flags | Notes |
|---|---|---|
| `following` | `--user <userId>`, `-n N`, `--cursor <s>`, `--all`, `--max-pages N`, `--json` | Who you (or `--user`) follow. `--max-pages` needs `--all`. |
| `followers` | `--user <userId>`, `-n N`, `--cursor <s>`, `--all`, `--max-pages N`, `--json` | Who follows you (or `--user`). `--max-pages` needs `--all`. |

`--user` takes a **numeric user ID**, not a handle. To resolve a handle → ID, use `about` or `user-tweets` (`--json`).

## Write commands (require `--allow-write`)

| Command | Flags | Notes |
|---|---|---|
| `tweet "<text>"` | `--media <path>` (×4 img / 1 vid), `--alt <text>` (per media) | Post. GraphQL `CreateTweet`, falls back to legacy `statuses/update.json` on error 226. **Discouraged — X blocks bots.** |
| `reply <id-or-url> "<text>"` | `--media`, `--alt` | Reply. Same caveat. |
| `follow` / `unfollow <handle>` | — | — |
| `unbookmark <id-or-url...>` | — | Safe and useful (un-bookmarks one or more). |

Enable writes via `--allow-write` flag, `PEEP_ALLOW_WRITE=1`, or `allowWrite: true` in config. Prefer browser automation (`surf`/`rodney`) or the paid API for posting.

## Introspection / cache

| Command | Flags | Notes |
|---|---|---|
| `whoami` | — | Which account the cookies belong to. |
| `check` | — | Which credentials are available + where sourced. |
| `cache` | `--json` | Local cache statistics. |
| `query-ids` | `--fresh`, `--json` | Inspect / refresh cached GraphQL query IDs. |
| `local-search` | `-n N`, `--author <handle>`, `--since <date>`, `--until <date>`, `--json` | Offline FTS5 over cached tweets. See [data.md](data.md). |
| `archive find` / `archive import <path>` | `--json` | Find/import an X data export zip. See [data.md](data.md). |
| `research [query]` | `-n N`, `--thread-depth N`, `--no-live`, `--out <path>`, `--json` | Bookmarks → markdown brief (thread expansion + extracted links/handles). See [data.md](data.md). |

## Global flags

| Flag | Effect |
|---|---|
| `--allow-write` | enable write commands |
| `--auth-token <t>` / `--ct0 <t>` | set cookies manually |
| `--cookie-source <safari\|chrome\|firefox>` | cookie source (repeatable; order matters) |
| `--chrome-profile <name>` | Chrome profile name (e.g. `Default`, `Profile 2`) |
| `--chrome-profile-dir <path>` | Chrome/Chromium profile dir or cookie DB (Arc/Brave/etc.) |
| `--firefox-profile <name>` | Firefox profile |
| `--cookie-timeout <ms>` | cookie extraction timeout (keychain/OS helpers) |
| `--timeout <ms>` | per-request timeout |
| `--quote-depth <n>` | quoted-tweet depth in `--json` (default 1; 0 disables) |
| `--json` / `--json-full` | machine output (`--json-full` includes raw API response) |
| `--plain` | no emoji, no color |
| `--no-emoji` / `--no-color` | disable emoji / ANSI colors (or `NO_COLOR=1`) |
| `--render` / `--markdown` | expand URLs + clean mentions; render as markdown |
| `--media <path>` / `--alt <text>` | attach media + per-item alt (write commands) |

## Environment variables

| Var | Effect |
|---|---|
| `AUTH_TOKEN` / `CT0` (fallback `TWITTER_AUTH_TOKEN` / `TWITTER_CT0`) | cookies |
| `PEEP_ALLOW_WRITE` | enable writes |
| `PEEP_TIMEOUT_MS` / `PEEP_COOKIE_TIMEOUT_MS` | timeouts |
| `PEEP_QUOTE_DEPTH` | default quote depth |
| `PEEP_CACHE_DIR` | cache dir (default `~/.peep`) |
| `PEEP_QUERY_IDS_CACHE` | query-ID cache file |
| `OPENAI_API_KEY` / `PEEP_OPENAI_MODEL` | AI inbox scoring (model default `gpt-4o-mini`) |

## Exit codes

- `0` success
- `1` runtime error (network / auth)
- `2` invalid usage (e.g. `--user` without a valid handle, `--max-pages` without `--all`)
