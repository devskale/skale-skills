# Privacy matrix — who sees what, on which path

> **Read when** the user asks about privacy/anonymity of a search, a transcript,
> or a download — or before choosing a backend for a sensitive query.
> Verified against live behavior and 2026 web research (2026-10-23).

## The matrix

| Action | Path | Anonymous? | Who sees it |
|--------|------|------------|-------------|
| **Search** | Invidious (skill default) | ✅ vs Google | Instance operator sees your IP + query; YouTube sees the instance's IP, not yours |
| Search | yt-dlp (`playlist-import`, future `--backend ytdlp`) | ❌ | YouTube sees your IP + query — no account, but IP-profileable |
| Search | yt-dlp + `--proxy socks5://…` / Tor | ✅ | YouTube sees the exit node — slow, rate-limit prone (researched 2026-10) |
| **Transcript** | vtd fast path (`youtube-transcript-plus`) | ⚠️ | YouTube sees your IP + *which video* — no account identity |
| Transcript | vtd yt-dlp subtitles | ⚠️ | same — IP yes, identity no |
| **Transcript 🔒 age-restricted** | vtd `--cookies` | ❌❌ | Runs AS the cookie account — YouTube logs it on that account. The agent asks which profile BEFORE invoking (vtd SKILL.md hard rule) |
| Lists, scores, fav/block channels | local files only | ✅ | `./lists/`, `~/.config/youtube-skill/`, caches — never leave the machine |

## The three honest sentences

1. **Searches are anonymous against Google** as long as they run over Invidious
   (the skill default). The trade: you swap Google for the instance operator
   as observer — they see your IP and your queries.
2. **Transcript downloads are never anonymous.** From the moment text arrives,
   your IP talks to YouTube — every transcribed video is visible to them.
   Without cookies: no identity, but an interest profile tied to the IP.
3. **🔒 restricted content has no anonymous path — ever.** The age gate
   requires an authenticated session; using it attaches that account to the
   request. That's physics, not a skill limitation.

## Practical guidance

- **Sensitive topic?** Search via the Invidious default (anonymous). Think
  twice before transcribing — the transcript fetch itself is visible.
- **More privacy on the yt-dlp path?** `-- --proxy socks5://127.0.0.1:9050`
  (Tor) works with yt-dlp but is slow and rate-limited; the transcript fast
  path (`youtube-transcript-plus`) supports no proxy — vtd falls back to
  yt-dlp for it.
- **Cookies are opt-in, every time.** vtd announces the attached identity on
  stderr (`🔒 cookies: chrome:Profile 2 — …`) and the agent confirms the
  account with the user before any `--cookies` run.
- **What never leaves the machine:** lists, picks, exclusions, scores,
  fav/block channels, instance caches, job registries.

## Related

- vtd cookies + age-gate profile lore: [vtd SKILL.md](../../video-transcript-downloader/SKILL.md)
- Backend health (`youtube hosts`, uptime + api flag): [youtube SKILL.md](../SKILL.md)
