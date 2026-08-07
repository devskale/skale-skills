---
name: peep
version: "0.9.1"
description: "Read X/Twitter via the `peep` CLI (cookie auth, undocumented GraphQL) — read tweets/threads/replies, search, mentions, user timelines, home feed, bookmarks, likes, news/trending, lists, following/followers. Knowledge skill — drives the `peep` binary directly (no bundled scripts); requires installing the binary (see Setup). Use when the user wants to read or catch up on X/Twitter, fetch a tweet/thread by URL or ID, search tweets, list bookmarks/likes, or see who someone follows. Triggers on: read a tweet, tweet thread, X, Twitter, bookmarks, timeline, mentions, search tweets, followers, following, trending, news, peep."
license: MIT
---

# peep 👀 — read X/Twitter from the CLI

**Knowledge skill** — no scripts; the agent drives the `peep` CLI directly. Requires the `peep` binary.

```bash
peep read https://x.com/user/status/123...   # read a tweet (URL or bare ID both work)
peep thread 1234567890123456789              # full conversation thread
peep search "from:steipete" -n 5             # search
peep bookmarks -n 10                         # your bookmarks
peep whoami                                  # which account am I?
```

> **Use peep to READ.** It hits X's undocumented GraphQL with cookie auth; X blocks bots fast, so avoid posting. Write commands (`tweet`/`reply`/`follow`/…) are **off by default** — see [Write commands](#write-commands--disabled-by-default-discouraged).

## Setup / Install

peep is a **standalone binary** published as a GitHub release from [`devskale/peep`](https://github.com/devskale/peep). It needs **no Python/Node runtime** — just the binary on your `PATH`. Pick one install method:

### Option 1 — GitHub release binary (recommended, macOS + Linux)

Grab the prebuilt binary for your platform from the [`latest` release](https://github.com/devskale/peep/releases/latest):

```bash
# macOS (arm64/x86_64)
curl -sL https://github.com/devskale/peep/releases/download/latest/peep-darwin -o peep
# Linux x64
# curl -sL https://github.com/devskale/peep/releases/download/latest/peep-linux-x64 -o peep

chmod +x peep
sudo mv peep /usr/local/bin/          # or ~/.local/bin (add to PATH)
```

### Option 2 — install script (auto-detects OS/arch)

```bash
curl -sL https://raw.githubusercontent.com/devskale/peep/main/scripts/install.sh | sh
```

Fetches the latest GitHub release and drops `peep` into `/usr/local/bin` (or `~/.local/bin` if not writable). If it lands in `~/.local/bin`, add that to your PATH:

```bash
export PATH="$HOME/.local/bin:$PATH"   # add to ~/.bashrc / ~/.zshrc
```

> Note: the install script currently builds **macOS + Linux x64** binaries only. For Linux arm64, use the direct release download or build from source.

### Option 3 — build from source (needs bun)

```bash
git clone https://github.com/devskale/peep && cd peep
bun install && bun run build:binary   # produces ./peep
sudo mv peep /usr/local/bin/
```

### Verify

```bash
peep --version   # → 0.9.0 (…)
peep check       # → which credentials are sourced + from where
peep whoami      # → the X account the cookies belong to (needs auth, below)
```

> **Auth isn't part of install.** peep reuses your logged-in X browser session — see [Authentication](#authentication-read-this-first). Until you've logged into x.com in a browser, `whoami` will report missing credentials.

## Authentication (read this first)

peep reuses your **logged-in X/Twitter browser session** — no passwords, no API keys. Credentials resolve in order: `--auth-token`/`--ct0` flags → `AUTH_TOKEN`/`CT0` env vars → browser cookies (Safari/Chrome/Firefox, via `--cookie-source`).

- `peep check` — shows which credentials are sourced and from where.
- `peep whoami` — prints the account the cookies belong to.
- `403` / auth errors → cookies are stale; re-log into x.com in your browser, then retry.
- Chromium variants (Arc/Brave): pass the profile cookie DB via `--chrome-profile-dir`.

Persistent config at `~/.config/peep/config.json5` (JSON5):
```json5
{ cookieSource: ["safari", "chrome"], chromeProfileDir: "/path/to/Chromium/Profile" }
```

## Reading tweets (primary use)

```bash
peep read <id-or-url>              # tweet text (bare ID or full URL both accepted)
peep <id-or-url>                   # shorthand for `read`
peep thread <id-or-url>            # the author's self-reply chain
peep replies <id-or-url>           # everyone's replies to a tweet
peep search "<query>" -n 20        # from:user, since:2025-01-01, hashtags, …
peep mentions                      # tweets mentioning you (--user @handle for someone else)
peep user-tweets @handle -n 50     # a user's profile timeline
peep home -n 20                    # "For You" feed (--following for the following feed)
peep bookmarks -n 10               # your bookmarks (--folder-id for a bookmark folder)
peep likes -n 10                   # your likes
peep news --ai-only -n 10          # AI-curated trending news from Explore tabs
peep list-timeline <list-id> -n 20 # tweets from a list
peep following -n 20               # who you follow
peep followers -n 20               # who follows you
peep about @handle                 # account origin / location info
```

## Output modes (global flags)

| Flag | Use |
|------|-----|
| `--json` | machine-readable tweet objects (best when you'll parse/extract fields) |
| `--plain` | stable text, no emoji, no color — deterministic, agent-friendly |
| `--render` | expand URLs, clean @mentions / #hashtags |
| `--markdown` | render tweets as markdown with clickable links |
| `--no-color` | disable ANSI colors (or `NO_COLOR=1`) |
| `--quote-depth N` | quoted-tweet nesting depth in `--json` (default 1; 0 disables) |

Prefer `--json` when summarizing/extracting; `--plain` for clean readable text.

## Pagination — the common gotcha

Most list commands take `-n COUNT` for a quick page. To page further you **must** opt in:
```bash
peep bookmarks --all --max-pages 3 --json          # paginate, cap at 3 pages
peep search "x" --all --cursor "<cursor>" --json   # continue from a prior page
```
- `--max-pages` **requires** `--all` (or `--cursor`); using it alone is an error (exit 2).
- With pagination, `--json` output becomes `{ tweets, nextCursor }` — keep `nextCursor` to continue.
- `user-tweets` auto-paginates when `-n > 20`.

## Starred bookmarks, inbox & cache (local-first)

Every read silently populates `~/.peep/cache.db` (SQLite + FTS5):
```bash
peep cache --stats                                  # cache stats (tweet/profile/bookmark counts)
peep local-search "typescript" --author @steipete # offline FTS5 search
peep archive import ~/Downloads/twitter.zip       # import an X data export
```
Triage bookmarks with metadata and run an AI-ranked inbox:
```bash
peep starred --unread --priority critical
peep starred note <id> "follow up"                # + tag / priority / folder / revisit / mark-read
peep inbox --score                                # AI-ranked mentions (needs OPENAI_API_KEY)
peep research "codex" --thread-depth 10           # bookmarks → markdown brief (thread + links)
```
→ Full detail in [references/data.md](references/data.md). **Read when** managing bookmarks, the inbox, or working offline.

## Write commands — disabled by default, discouraged

`tweet`, `reply`, `follow`, `unfollow`, `unbookmark` are **off unless** you pass `--allow-write` (or set `allowWrite: true` / `PEEP_ALLOW_WRITE=1`).

> **Don't automate posting.** X blocks bots quickly. Use peep to **read**; if posting is unavoidable, prefer browser automation (`surf` / `rodney` skills) or the paid X API. `unbookmark` is the one write op that's safe and useful.

## Troubleshooting

| Problem | Fix |
|--------|-----|
| `403` / auth errors | Cookies stale — re-log into x.com in your browser, retry |
| `404` on a GraphQL op | Query ID rotated — peep auto-refreshes; force with `peep query-ids --fresh` |
| `429` rate limited | Back off; GraphQL is heavily rate-limited — page less, lower `-n` |
| Wrong / no account | `peep check`; set `--cookie-source` order |
| Slow / blocking cookie prompt | `--cookie-timeout 30000`; pin a profile via `--chrome-profile-dir` |
| Bad tweet arg | Accepts bare ID **or** full `https://x.com/.../status/<id>` URL |

Exit codes: `0` success · `1` runtime (network/auth) · `2` invalid usage.

## References

- [references/commands.md](references/commands.md) — exhaustive command + flag reference (bookmarks expansion flags, news tab filters, list / social-graph options). **Read when** a command needs a flag not shown above.
- [references/data.md](references/data.md) — starred bookmarks, AI inbox, local cache, archive import, blocks & mutes, profile bot-scan. **Read when** triaging bookmarks or working offline.
