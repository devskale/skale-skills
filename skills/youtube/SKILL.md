---
disable-model-invocation: true
name: youtube
version: "2.2.1"
description: Search YouTube for long, recent, well-watched content and curate ranked lists you can refine and transcribe. Use when the user wants to find videos or build a watch list.
---

# YouTube Search + Curation

```bash
youtube "system design interviews"            # → saves ./lists/system-design-interviews.md
youtube "rl lectures" --captions --num 8      # only videos WITH transcripts
youtube "rust async" --preset fresh           # ranking preset
youtube "query" --stdout                      # print only (legacy)
```

Finds fresh, long, deep content (Invidious API, no key), ranks it, and **saves a list you curate** — promote picks, tag, exclude channels, expand. When the Picks are right: `vtd transcript --list <name>` transcribes them all → [vtd skill](../video-transcript-downloader/SKILL.md). Zero dependencies (stdlib only).

## Install

Run the installer from this skill's own directory (next to `SKILL.md`):

```bash
./install.sh        # → ~/.local/bin/youtube (no deps; symlink only)
```

## Search → list

```bash
youtube "<query>" [filters]      # saves ./lists/<slug>.md, prints path + preview
youtube "<query>" --save rl-set  # name the list explicitly
```

Each entry carries a real `youtube.com/watch?v=ID` (vtd-ready) + channel · duration · views · age · ★score.

### Filters

| Flag | Default | What |
|---|---|---|
| `--num N` | 8 | picks surfaced (rest → `## Candidates`) |
| `--pool N` | 30 | candidates fetched+ranked |
| `--preset` | deep | `deep` · `trending` · `fresh` (ranking profiles) |
| `--fresh SPEC` | 18m | max age: `3m` `1y` `2w` `14d` `all` |
| `--min-views N` | 1000 | view floor |
| `--any-length` | off | include shorts |
| `--captions` | off | **only videos with subtitles** (transcript-friendly) |
| `--channel NAME\|UCID` | — | search within a channel |
| `--exclude-channel X` | — | drop a channel (repeatable) |
| `--min-duration` / `--max-duration` | 1200 / — | seconds |
| `--region CC` | — | locale |
| `--rank MODE` | — | raw sort: relevance/date/views/rating (disables deep mode) |
| `--backend X` | invidious | `invidious` (anonymous default) or `ytdlp` (reliable, but your IP queries YouTube — [references/privacy.md](references/privacy.md)); ytdlp is also the automatic fallback when every instance fails |
| `--no-favs` | off | disable favourite-channel boost |

## Refine a list (curation)

The list is a living `.md` — curate by **editing it directly** (promote, tag, move to "maybe", drop). Use the CLI only for bulk/mechanical ops:

```bash
youtube exclude --channel "Name" --list <name>   # remove every entry from a channel
youtube dedup                  --list <name>     # drop duplicate video IDs
youtube expand --like <url> | --channel <name> | --more "<q>" [--list <name>]   # add candidates
```

→ **Read [references/curation.md](references/curation.md)** for section semantics, tag vocabulary, and the full refine loop. **Read when** curating a list.

## Privacy (who sees what)

Searches over Invidious are anonymous against Google (the instance's IP hits YouTube — but the operator sees your queries). Transcript downloads never are: your IP talks to YouTube. 🔒 restricted content has **no anonymous path** — cookies attach an account. **Read [references/privacy.md](references/privacy.md)** for the full matrix, proxy/Tor notes, and what stays local. **Read when** privacy matters or a backend choice is questioned.

## Channel preferences (global, grows over time)

```bash
youtube channel --block "Tutorial Purge"     # auto-excluded from every search
youtube channel --fav   "Two Minute Papers"  # ranked higher when they match
youtube channel --list
```

Stored at `~/.config/youtube-skill/channels.md`. Blocked → filtered before ranking; favourites → score boost.

## Playlist import (any playlist → curatable list)

```bash
youtube playlist-import "https://www.youtube.com/playlist?list=PL…"   # → ./lists/<slug>.md
youtube playlist-import "https://www.youtube.com/watch?v=X&list=PL…"  # watch URL works too
youtube playlist-import PLunPKX4o0PQ… --save my-name                 # bare id + explicit name
```

Imports **any** playlist (own, unlisted, foreign) as a `## Picks` list — complete listing via yt-dlp (Invidious search is query-limited), ready for curation and `vtd transcript --list`. Requires `yt-dlp` on PATH. Writes `./lists/` relative to cwd.

## Update / health

```bash
youtube hosts [--probe]   # which instances are alive (probe: active check + latency;
                          #   both views show registry uptime % + api flag + region)
youtube --update | --selfcheck | --discover
```

## Gotchas

- **Invidious `date`/`duration` API filters are leaky** — deep mode re-checks age + duration client-side.
- **Age-restricted videos** are marked `🔒 age-restricted` — the public Invidious stream returns 403 for them. Transcribe via `vtd … --cookies`; which profile passes the age gate is account-specific → [vtd SKILL.md](../video-transcript-downloader/SKILL.md) ("Profile selection"). Translated captions often 429 — prefer the original language.
- **Invidious `/videos/{id}` (related videos) is widely blocked** — so `expand --like` resolves the video's *channel* instead (more from creator). If that fails, use `--channel` or `--more`.
- **Watch links are `youtube.com`** (not the Invidious host), so they're ready for `vtd transcript --url …`.
- **Fewer picks than `--num`?** Filters are strict. Widen with `--fresh all`, `--any-length`, lower `--min-views`, or bigger `--pool`.
- **"all instances failed"** → the skill now auto-retries via the **yt-dlp backend** (loudly announced — less anonymous). If that also fails: `youtube --discover` (parallel probe, rebuilds the cache). Most public instances die regularly — the self-heal (evict/promote/merge) usually recovers on its own. You can also search yt-dlp directly: `youtube "q" --backend ytdlp`.
- **The long-term fix is a yt-dlp backend rewrite** — tracked on the skale-skills board as issue `youtube-ytdlp-rewrite` (`.work/issues/backlog/`, machine-local symlink).

## How it works

1. Instance resolution, self-healing and **self-maintaining**: probe order is fresh cache → hosts with recent real-world success (health history in `.instance-stats.json`, recorded on every search) → cold-start pool. Dead hosts are evicted, healthy ones promoted; rotted entries (45d without success) are pruned automatically. On cache-miss, a parallel probe (registry + pool, browser-UA retry) refreshes the cache for 4h. Registry metadata (uptime %, api flag, region from api.invidious.io, cached 6h in `.instance-registry.json`) ranks the probe order — api-enabled, high-uptime hosts first — and shows in `youtube hosts` (an instance can be 99% "up" while its operator disabled the API; the flag is the kill criterion).
2. Search `/api/v1/search` (or `/channels/{ucid}/search` for `--channel`) with filters
3. Deep mode: apply fav/block + filters → score (preset weights) → rank → split picks/candidates
4. Write `./lists/<slug>.md`; print path + preview
