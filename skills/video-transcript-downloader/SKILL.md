---
name: video-transcript-downloader
version: "1.3.0"
description: "Download videos, audio, subtitles, and clean paragraph-style transcripts (no timestamps by default; duration in YAML; --timestamps/--sections for time anchors) from YouTube and any yt-dlp-supported site. Browser-cookie auth (--cookies) unlocks age-restricted videos. Transcripts save to a file by default. Also transcribes a whole youtube-skill list's Picks in one go (--list), with resume + a manifest. Use when asked to download a video, rip audio, get subtitles, fetch a transcript, or transcribe a list of videos. Triggers on: download this video, get the transcript, rip audio, extract subtitles, save this clip, transcribe these, yt-dlp."
---

# Video Transcript Downloader

```bash
vtd transcript --url 'https://www.youtube.com/watch?v=...'
vtd transcript --list rust-async                # transcribe a youtube list's Picks
vtd search "top 3 AI videos"
vtd download --url 'https://...'
vtd audio --url 'https://...'
vtd chapters --url 'https://...'            # print video chapters (fast, no transcript fetch)
```

## Install

**Linux / macOS (bash):**
```bash
bash install.sh
```

**Windows (cmd):**
```cmd
install.bat
```

Requires: `uv`, `node` (with pnpm/npm), `ffmpeg` (for audio extraction).

## Transcript

Default: saves to `./YYYY-MM-DD_title.md` with YAML frontmatter (title, date, url, uploader, views, **duration**, tags). Body = clean prose — **no timestamps by default** (duration lives in the YAML).

```bash
vtd transcript --url 'https://...'
vtd transcript --url 'https://...' --timestamps         # with [MM:SS] per line
vtd transcript --url 'https://...' --sections           # split by chapter (### MM:SS Title + TOC)
vtd transcript --url 'https://...' --lang de             # language
vtd transcript --url 'https://...' --no-file             # print to stdout
vtd transcript --url 'https://...' --transcript-dir ./t/  # output directory
```

**Agent:** The script outputs the saved file path. Your task is done — just report the path.

## Transcribe a youtube list

Transcribe every video in a [`youtube`](../youtube) skill list's `## Picks` (the curated winners) — closes the *youtube curates → vtd transcribes* loop.

```bash
vtd transcript --list rust-async                # bare name → ./lists/rust-async.md
vtd transcript --list ./lists/rl-lectures.md    # or a path
vtd transcript --list rust-async --limit 5      # cap a big list
vtd transcript --list rust-async --force        # re-fetch even if already done
```

- **Selection:** `## Picks` only; `## Excluded` never; `## Candidates` / `## Maybe` ignored.
- **Output:** `./transcripts/<list-name>/<videoID>__<title>.md` (one per video).
- **Resume:** re-running skips videos whose transcript already exists — only missing ones are fetched. Re-run after a failure to self-heal.
- **Robust:** a video that fails (no captions, unavailable) doesn't abort the batch; exit code is non-zero if anything failed.
- **Manifest:** writes `./transcripts/<list-name>/INDEX.md` — a table of each Pick, its status, and transcript file.

## Search

Search and **auto-download a transcript for each result** (saves to file by default). This is for retrieval, not link discovery — if you only want a list of video links, use the separate `youtube` skill instead, which is lighter (no yt-dlp, no transcript fetch).

```bash
vtd search "reinforcement learning" --limit 3 --transcript-dir ./transcripts/
vtd search "nextjs tutorial" --timestamps
```

## Download / Audio / Subtitles / Formats

```bash
vtd download --url 'https://...' --output-dir ~/Downloads
vtd audio --url 'https://...' --output-dir ~/Downloads
vtd subs --url 'https://...' --lang en --output-dir ~/Downloads
vtd formats --url 'https://...'                            # list available formats
vtd download --url 'https://...' -- --format 137+140       # specific format
```

## Options

| Flag | Default | Description |
|------|---------|-------------|
| `--url` | required | Video URL |
| `--lang` | en | Subtitle language |
| `--timestamps` | off | Include `[MM:SS]` per line |
| `--sections` | off | Split body by chapters (`### MM:SS Title` + TOC) |
| `--keep-brackets` | off | Keep `[Music]` etc. |
| `--no-file` | off | Print to stdout instead of saving |
| `--transcript-dir` | `.` | Where to save transcripts |
| `--output-dir` | `~/Downloads` | Where to save downloads |
| `--limit` | 1 | Search results count |
| `--cookies` | off | Use browser cookies for age-restricted videos |
| `--` (separator) | | Pass extra args to yt-dlp |

## Age-restricted videos

YouTube blocks age-gated content without authentication. The `youtube` skill marks these with `🔒 age-restricted` in the list. To transcribe them, pass cookies from a signed-in browser:

```bash
# One-time: persist your browser profile
vtd cookies set chrome "Profile 2"       # → ~/.config/vtd-skill/config.json

# Then transcribe age-restricted videos (reads config automatically)
vtd transcript --url 'https://...' --cookies
vtd transcript --list rl-lectures --cookies     # batch mode

# Or pass a browser spec inline (no config needed)
vtd transcript --url 'https://...' --cookies 'chrome:Profile 2'

# Disable cookies (override config)
vtd transcript --url 'https://...' --cookies false
```

### Profile selection (matters!)

Not every signed-in Chrome profile passes the age gate — YouTube accepts the age verification on the account, not the browser install. Verified 2026-09: on a machine with 9 profiles, only one consistently passed. If `--cookies` fails with `Sign in to confirm your age`, try other profiles:

```bash
# Quick probe: which profile passes the age gate?
for p in "Default" "Profile 1" "Profile 2" "Profile 5"; do
  yt-dlp --cookies-from-browser "chrome:$p" --skip-download --write-auto-subs --sub-lang en \
    -o "/tmp/probe_$p" 'https://www.youtube.com/watch?v=VIDEO_ID' 2>&1 | grep -q 'Sign in' \
    && echo "$p: ✗ age gate" || echo "$p: ✓ works"
done
```

### 429 on translated captions

For non-English videos, **original-language captions download reliably; translated captions (`--lang en`/`de` on a Spanish-original video, etc.) frequently fail with HTTP 429**. This is YouTube-side rate limiting — PO-token providers don't help. Fix: request the video's original language (`vtd chapters --url …` won't show it; check `yt-dlp --list-subs`), or retry later.

Behind the scenes `--cookies` injects `--cookies-from-browser` into every yt-dlp call (metadata + subtitles). Combine with `-- --remote-components ejs:github` when yt-dlp needs the JS challenge solver:

```bash
vtd transcript --url 'https://...' --cookies -- --remote-components ejs:github
```

> **Note:** `youtube-transcript-plus` (the preferred fast path) cannot use cookies, so age-restricted videos fall back to yt-dlp subtitles — which do carry them. Verified working end-to-end 2026-09.

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Missing yt-dlp | `bash install.sh` |
| Missing ffmpeg | `brew install ffmpeg` |
| No subtitles found | Try different `--lang` or check if video has captions |
| Age-restricted video fails | Use `--cookies` (see above) |

## Notes

- YouTube: fetches transcript via `youtube-transcriptPlus` first, falls back to yt-dlp subtitles
- Non-YouTube: always uses yt-dlp subtitles
- **Default body is clean prose** — no timestamps, no chapter markers. Video duration lives in the YAML frontmatter (`duration: "18:40"` + `duration_seconds: 1120`). Opt into `--timestamps` (per-line `[MM:SS]`) or `--sections` (chapter split + TOC) when you need time anchors.
- Transcript files include YAML frontmatter with video metadata
- `--timestamps` overrides sectioning: emits `[MM:SS] text` lines with real per-segment times (use for precise quoting)
- Use `vtd chapters --url ...` for quick stdout chapter lookup without downloading the transcript
