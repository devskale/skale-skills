# Curation guide — refining a youtube list

When the user asks to *refine* a list ("more of this", "exclude that channel", "move
these to maybe", "tag the deep dives"), you operate on the saved `.md` in `./lists/`.
The file is a **living document** — read it, edit it directly, and re-save. The CLI
only steps in for the few bulk ops that are error-prone by hand.

## The list structure

```md
# <topic>
_Search: 2026-08-01 · pool 24 · preset deep · `<query>`_

## Picks            ← the ones you're recommending
- [**Title**](https://www.youtube.com/watch?v=ID) — Channel · 29:32 · 99K views · 7mo ago ★0.81 ucid:UCxxx

## Candidates       ← passed filters, not yet promoted — curate from here
- [**…**](https://www.youtube.com/watch?v=ID) — …

## Maybe / look into later
- [**…**](https://www.youtube.com/watch?v=ID) — … `#candidate`

## Excluded         ← what you rejected and why (so you don't re-add it)
- [**…**](https://www.youtube.com/watch?v=ID) — … `#excluded channel:foo`

## Expanded         ← appended by `youtube expand …`
- [**…**](https://www.youtube.com/watch?v=ID) — …
```

Each entry is one line carrying a real **`youtube.com/watch?v=ID`** (so the list is
ready to feed to `vtd transcript`) plus, when Invidious provides it, a `ucid:UC…`
token for precise channel matching.

The structure is a **convention, not a schema** — reorganise sections freely as you
learn what the user wants. Keep entries on one line each so the CLI helpers can parse them.

## How to curate (you edit the file)

| Intent | What you do |
|---|---|
| "these are the picks" | move the line(s) under `## Picks` |
| "this one's a maybe" | move it under `## Maybe / look into later` |
| "tag the lectures" | append ` #lecture` to those lines |
| "drop this one" | move it under `## Excluded` with a `#excluded …` note (or delete it) |
| "rank by length / views" | reorder lines within a section |

Tags are freeform — starter vocabulary: `#deep-dive` `#lecture` `#tutorial`
`#short` `#candidate` `#excluded`. Evolve it.

## When to use the CLI helpers (bulk / mechanical)

Do these by hand and you'll miss entries. Use the command instead:

```bash
youtube exclude --channel "Channel Name" --list <name>   # remove every entry from a channel
youtube dedup                  --list <name>               # drop duplicate video IDs
youtube expand  --like <url> | --channel <name> | --more "<q>"  [--list <name>]  # add candidates
```

- `exclude --channel` matches by `ucid:` if present, else by channel-name substring.
- `expand --like <url>` resolves the video's channel (from the entry's `ucid:`, or the
  Invidious `/videos` endpoint) and appends more from that creator. If Invidious blocks
  the endpoint and the video isn't in the list, use `--channel <name>` or `--more "<topic>"`.
- All three default to the **newest** list in `./lists/` if `--list` is omitted.

## Channel preferences (global, builds up over time)

`~/.config/youtube-skill/channels.md` holds favourites and a blocklist that apply to
**every** search:

```bash
youtube channel --block "Tutorial Purge"   # never see them again (auto-excluded)
youtube channel --fav   "Two Minute Papers" # ranked higher when they match
youtube channel --list                     # show current favs/blocks
```

Blocked channels are filtered out before ranking; favourites get a score boost
(disable per-query with `--no-favs`). To remove an entry, edit `channels.md` directly.

## The full refine loop

1. `youtube "<q>" [filters]` → writes `./lists/<slug>.md`
2. read the list, curate by editing (promote / section / tag / drop)
3. bulk ops via the CLI helpers above
4. repeat until the `## Picks` are what the user wants
5. hand a pick's URL to `vtd transcript --url …` when they want the content
