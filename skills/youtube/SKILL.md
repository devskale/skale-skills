---
name: youtube
version: "2.0.0"
description: "Search YouTube for fresh, long, deep content and curate ranked lists you can refine and later transcribe. Defaults to longform 20min+, last 18 months, 1K+ views, ranked by recency+views+duration+relevance. Saves a curated ./lists/<topic>.md you refine in natural language. Use when the user wants to find videos, build a watch/transcript list, or get recommendations. Triggers on: YouTube search, find videos, video list, find a podcast/lecture/deep dive."
---

# YouTube Search + Curation

```bash
youtube "system design interviews"            # → saves ./lists/system-design-interviews.md
youtube "rl lectures" --captions --num 8      # only videos WITH transcripts
youtube "rust async" --preset fresh           # ranking preset
youtube "query" --stdout                      # print only (legacy)
```

Finds fresh, long, deep content (Invidious API, no key), ranks it, and **saves a list you curate** — promote picks, tag, exclude channels, expand — then hand a URL to `vtd` to transcribe. Zero dependencies (stdlib only).

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
| `--no-favs` | off | disable favourite-channel boost |

## Refine a list (curation)

The list is a living `.md` — curate by **editing it directly** (promote, tag, move to "maybe", drop). Use the CLI only for bulk/mechanical ops:

```bash
youtube exclude --channel "Name" --list <name>   # remove every entry from a channel
youtube dedup                  --list <name>     # drop duplicate video IDs
youtube expand --like <url> | --channel <name> | --more "<q>" [--list <name>]   # add candidates
```

→ **Read [references/curation.md](references/curation.md)** for section semantics, tag vocabulary, and the full refine loop. **Read when** curating a list.

## Channel preferences (global, grows over time)

```bash
youtube channel --block "Tutorial Purge"     # auto-excluded from every search
youtube channel --fav   "Two Minute Papers"  # ranked higher when they match
youtube channel --list
```

Stored at `~/.config/youtube-skill/channels.md`. Blocked → filtered before ranking; favourites → score boost.

## Update / health

```bash
youtube --update           # git pull
youtube --selfcheck        # version + last update
youtube --discover         # refresh the Invidious instance cache
```

## Gotchas

- **Invidious `date`/`duration` API filters are leaky** — deep mode re-checks age + duration client-side.
- **`/videos/{id}` (related videos) is widely blocked** on Invidious — so `expand --like` resolves the video's *channel* instead (more from creator). If that fails, use `--channel` or `--more`.
- **Watch links are `youtube.com`** (not the Invidious host), so they're ready for `vtd transcript --url …`.
- **Fewer picks than `--num`?** Filters are strict. Widen with `--fresh all`, `--any-length`, lower `--min-views`, or bigger `--pool`.
- **"all instances failed"** → `youtube --discover`.

## How it works

1. Instance resolution: cache (`.instance-cache.json`, 4h TTL) → `api.invidious.io` → fallbacks
2. Search `/api/v1/search` (or `/channels/{ucid}/search` for `--channel`) with filters
3. Deep mode: apply fav/block + filters → score (preset weights) → rank → split picks/candidates
4. Write `./lists/<slug>.md`; print path + preview
