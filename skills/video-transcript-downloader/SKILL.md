---
name: video-transcript-downloader
description: "Download videos, audio, subtitles, and clean paragraph-style transcripts from YouTube and any other yt-dlp supported site. Transcripts are saved to file by default. Use when asked to download this video, save this clip, rip audio, get subtitles, get transcript, or to troubleshoot yt-dlp/ffmpeg and formats/playlists."
metadata:
  author: skale
  version: "1.1.0"
---

# Video Transcript Downloader

```bash
vtd transcript --url 'https://www.youtube.com/watch?v=...'
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

Default: saves to `./YYYY-MM-DD_title.md` with YAML frontmatter (title, date, url, views, tags).

```bash
vtd transcript --url 'https://...'
vtd transcript --url 'https://...' --timestamps         # with timestamps
vtd transcript --url 'https://...' --lang de             # language
vtd transcript --url 'https://...' --no-file             # print to stdout
vtd transcript --url 'https://...' --transcript-dir ./t/  # output directory
```

**Agent:** The script outputs the saved file path. Your task is done — just report the path.

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
| `--timestamps` | off | Include timestamps |
| `--keep-brackets` | off | Keep `[Music]` etc. |
| `--no-file` | off | Print to stdout instead of saving |
| `--transcript-dir` | `.` | Where to save transcripts |
| `--output-dir` | `~/Downloads` | Where to save downloads |
| `--limit` | 1 | Search results count |
| `--` (separator) | | Pass extra args to yt-dlp |

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Missing yt-dlp | `bash install.sh` |
| Missing ffmpeg | `brew install ffmpeg` |
| No subtitles found | Try different `--lang` or check if video has captions |

## Notes

- YouTube: fetches transcript via `youtube-transcriptPlus` first, falls back to yt-dlp subtitles
- Non-YouTube: always uses yt-dlp subtitles
- **Default output is sectioned by chapters**: if the video has chapter markers, the body is split into `### MM:SS Title` sections (one paragraph per chapter), with a `## Chapters` table of contents at the top. Videos without chapters fall back to a single clean paragraph.
- Transcript files include YAML frontmatter with video metadata
- `--timestamps` overrides sectioning: emits `[MM:SS] text` lines with real per-segment times (use for precise quoting)
- Use `vtd chapters --url ...` for quick stdout chapter lookup without downloading the transcript
