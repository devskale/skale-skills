#!/usr/bin/env node
import { spawn } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { YoutubeTranscript } from "youtube-transcript-plus";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

function die(message, code = 1) {
  process.stderr.write(String(message).trimEnd() + "\n");
  process.exit(code);
}

function parseArgs(argv) {
  // Tiny no-deps parser.
  // - `--flag` => boolean
  // - `--key value`
  // - `--` => forward remaining args to yt-dlp
  const positional = [];
  const opts = {};
  let i = 0;
  while (i < argv.length) {
    const a = argv[i];
    if (a === "--") {
      opts.extra = argv.slice(i + 1);
      break;
    }
    if (!a.startsWith("--")) {
      positional.push(a);
      i += 1;
      continue;
    }
    const key = a.slice(2);
    const next = argv[i + 1];
    const isValue = next !== undefined && !next.startsWith("--");
    if (!isValue) {
      opts[key] = true;
      i += 1;
      continue;
    }
    if (opts[key] === undefined) opts[key] = next;
    else if (Array.isArray(opts[key])) opts[key].push(next);
    else opts[key] = [opts[key], next];
    i += 2;
  }
  return { positional, opts };
}

function toArray(v) {
  if (v === undefined) return [];
  if (Array.isArray(v)) return v;
  return [v];
}

function which(cmd) {
  // Avoid shelling out to `which`; keep it portable + fast.
  const envPath = process.env.PATH || "";
  const parts = envPath.split(path.delimiter);
  for (const p of parts) {
    const full = path.join(p, cmd);
    if (fs.existsSync(full)) return full;
  }
  return null;
}

function resolveBin(name, fallback) {
  // Check for local .venv/bin/yt-dlp relative to this script
  const localBin = path.resolve(__dirname, "../.venv/bin", name);
  if (fs.existsSync(localBin)) return localBin;

  return which(name) || (fallback && fs.existsSync(fallback) ? fallback : null);
}

function run(cmd, args, { cwd } = {}) {
  return new Promise((resolve) => {
    // Capture stdout + stderr to keep yt-dlp’s error context intact.
    const child = spawn(cmd, args, { cwd, stdio: ["ignore", "pipe", "pipe"] });
    let out = "";
    child.stdout.on("data", (d) => (out += d.toString()));
    child.stderr.on("data", (d) => (out += d.toString()));
    child.on("close", (code) => resolve({ code, out }));
  });
}

function isYouTubeUrl(url) {
  return /(^https?:\/\/)?(www\.)?(youtube\.com|youtu\.be)\//i.test(url);
}

function extractYouTubeId(input) {
  if (!input) return null;
  const raw = String(input).trim();
  if (/^[a-zA-Z0-9_-]{11}$/.test(raw)) return raw;
  const m = raw.match(/(?:v=|youtu\.be\/)([a-zA-Z0-9_-]{11})/);
  return m ? m[1] : null;
}

function decodeHtmlEntities(input) {
  if (!input) return input;
  // Some transcripts come back double-encoded (e.g. "&amp;#39;").
  // Decode up to 2 passes; stop once stable.
  let text = input;
  for (let i = 0; i < 2; i++) {
    const decoded = text
      .replace(/&amp;/g, "&")
      .replace(/&lt;/g, "<")
      .replace(/&gt;/g, ">")
      .replace(/&quot;/g, '"')
      .replace(/&apos;/g, "'")
      .replace(/&#(\d+);/g, (_, dec) => String.fromCodePoint(Number(dec)))
      .replace(/&#x([0-9a-fA-F]+);/g, (_, hex) =>
        String.fromCodePoint(parseInt(hex, 16)),
      );
    if (decoded === text) break;
    text = decoded;
  }
  return text;
}

function formatTimestamp(seconds) {
  const s = Math.max(0, Math.floor(seconds));
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const sec = Math.floor(s % 60);
  if (h > 0)
    return `${h}:${String(m).padStart(2, "0")}:${String(sec).padStart(2, "0")}`;
  return `${m}:${String(sec).padStart(2, "0")}`;
}

function slugifyForFile(input) {
  const base = String(input || "video")
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-zA-Z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .toLowerCase()
    .slice(0, 60);
  return base || "video";
}

function buildTranscriptFilename({ uploadDate, title, id }) {
  let datePart;
  if (uploadDate && /^\d{8}$/.test(uploadDate)) {
    datePart = `${uploadDate.slice(0, 4)}-${uploadDate.slice(4, 6)}-${uploadDate.slice(6, 8)}`;
  } else {
    const now = new Date();
    const yyyy = now.getFullYear();
    const mm = String(now.getMonth() + 1).padStart(2, "0");
    const dd = String(now.getDate()).padStart(2, "0");
    datePart = `${yyyy}-${mm}-${dd}`;
  }
  const baseNameSource = title || id || "video";
  const slug = slugifyForFile(baseNameSource);
  return `${datePart}_${slug}.md`;
}

async function getVideoMeta(url) {
  const ytdlp = resolveBin("yt-dlp", "/opt/homebrew/bin/yt-dlp");
  if (!ytdlp)
    throw new Error(
      "missing yt-dlp; install `yt-dlp` and ensure it is on PATH",
    );
  const args = [
    "--print",
    "%(upload_date)s|%(title).200B|%(id)s|%(view_count)s|%(like_count)s|%(uploader)s|%(duration)s|%(webpage_url)s",
    "--skip-download",
    url,
  ];
  const r = await run(ytdlp, args);
  if (r.code !== 0) throw new Error(r.out.trim() || "yt-dlp metadata failed");
  const line = r.out
    .split("\n")
    .map((l) => l.trim())
    .filter(Boolean)
    .find((l) => l.split("|").length >= 3);
  if (!line) return {};
  const [
    uploadDate,
    title,
    id,
    viewCount,
    likeCount,
    uploader,
    duration,
    webpageUrl,
  ] = line.split("|");
  return {
    uploadDate: uploadDate || null,
    title: title || null,
    id: id || null,
    viewCount: viewCount || "0",
    likeCount: likeCount || "0",
    uploader: uploader || "Unknown",
    duration: duration || "0",
    webpageUrl: webpageUrl || url,
  };
}

async function saveTranscriptToFile({ text, url, transcriptDir, meta }) {
  if (!meta) {
    meta = await getVideoMeta(url);
  }
  const filename = buildTranscriptFilename(meta);
  const dir = path.resolve(transcriptDir);
  fs.mkdirSync(dir, { recursive: true });
  const fullPath = path.join(dir, filename);

  const frontmatter = [
    "---",
    `title: "${(meta.title || "video").replace(/"/g, '\\"')}"`,
    `date: ${meta.uploadDate ? `${meta.uploadDate.slice(0, 4)}-${meta.uploadDate.slice(4, 6)}-${meta.uploadDate.slice(6, 8)}` : new Date().toISOString().split("T")[0]}`,
    `id: ${meta.id}`,
    `url: ${meta.webpageUrl}`,
    `uploader: "${(meta.uploader || "").replace(/"/g, '\\"')}"`,
    `likes: ${meta.likeCount}`,
    `views: ${meta.viewCount}`,
    `duration: ${meta.duration}`,
    "---",
    "",
  ].join("\n");

  fs.writeFileSync(
    fullPath,
    frontmatter + String(text || "").trimEnd() + "\n",
    "utf8",
  );
  return fullPath;
}

function cleanSegments(segments, { keepBrackets } = {}) {
  const cleaned = [];
  let prev = "";

  for (const seg of segments) {
    // Handle both string segments and object segments {text, offset}
    const rawText = typeof seg === "object" ? seg.text : seg;
    const s = String(rawText || "")
      .replace(/\s+/g, " ")
      .trim();
    if (!s) continue;

    // Subtitles often contain HTML-ish tags; strip them.
    const withoutTags = s.replace(/<[^>]+>/g, "").trim();
    const withoutBrackets = keepBrackets
      ? withoutTags
      : withoutTags.replace(/\[[^\]]*\]/g, "").trim();
    const withoutCurlies = withoutBrackets
      .replace(/\{[^}]+\}/g, "")
      .replace(/♪/g, "")
      .trim();
    const t = withoutCurlies.replace(/\s+/g, " ").trim();
    if (!t) continue;
    if (t === prev) continue;
    // Dedup heuristic: captions often repeat previous line with a longer suffix.
    if (prev && t.startsWith(prev)) {
      const newPart = t.slice(prev.length).trim();
      if (newPart) cleaned.push(newPart);
    } else if (prev && t.includes(prev)) {
      // Another common pattern: current line contains previous line in the middle.
      const idx = t.indexOf(prev);
      const newPart = (t.slice(0, idx) + t.slice(idx + prev.length)).trim();
      if (newPart) cleaned.push(newPart);
    } else {
      cleaned.push(t);
    }
    prev = t;
  }

  return cleaned;
}

function toParagraph(segments, { keepBrackets } = {}) {
  const cleaned = cleanSegments(segments, { keepBrackets });
  return cleaned.join(" ").replace(/\s+/g, " ").trim();
}

function parseTime(str) {
  if (!str) return 0;
  const [hms, msStr] = str.replace(",", ".").split(".");
  const parts = hms.split(":").map(Number);
  let s = 0;
  if (parts.length === 3) s = parts[0] * 3600 + parts[1] * 60 + parts[2];
  else if (parts.length === 2) s = parts[0] * 60 + parts[1];
  return s * 1000 + (msStr ? Number(msStr) : 0);
}

function parseSrt(text) {
  const lines = String(text).split(/\r?\n/);
  const segments = [];
  let currStart = 0;
  let currText = [];

  for (const line of lines) {
    const l = line.trim();
    if (!l) {
      if (currText.length > 0) {
        segments.push({ offset: currStart, text: currText.join(" ") });
        currText = [];
      }
      continue;
    }
    if (/^\d+$/.test(l)) continue;
    if (l.includes("-->")) {
      const [start] = l.split("-->");
      currStart = parseTime(start.trim());
      continue;
    }
    currText.push(l);
  }
  if (currText.length > 0) {
    segments.push({ offset: currStart, text: currText.join(" ") });
  }
  return segments;
}

function parseVtt(text) {
  const lines = String(text).split(/\r?\n/);
  const segments = [];
  let currStart = 0;
  for (const line of lines) {
    const l = line.trim();
    if (!l) continue;
    if (l === "WEBVTT" || l.startsWith("Kind:") || l.startsWith("Language:"))
      continue;
    if (/^(align|position|size|line):/i.test(l)) continue;
    if (l.includes("-->")) {
      currStart = parseTime(l.split("-->")[0].trim());
      continue;
    }
    // Remove inline timestamps like "<00:00:00.000>"
    const cleaned = l.replace(/<\d{2}:\d{2}:\d{2}\.\d{3}>/g, "").trim();
    if (cleaned) segments.push({ offset: currStart, text: cleaned });
  }
  return segments;
}

async function ytDlpSubtitlesToTemp({ url, lang, ytdlpPath, extra }) {
  const ytdlp = ytdlpPath || resolveBin("yt-dlp", "/opt/homebrew/bin/yt-dlp");
  if (!ytdlp)
    throw new Error(
      "missing yt-dlp; install `yt-dlp` and ensure it is on PATH",
    );

  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "vtd-subs-"));
  const outTemplate = path.join(tmpDir, "%(id)s.%(ext)s");

  const args = [];
  args.push(
    "--write-sub",
    "--write-auto-sub",
    "--skip-download",
    "--sub-lang",
    lang,
    "-o",
    outTemplate,
  );
  if (extra?.length) args.push(...extra);
  args.push(url);

  const r = await run(ytdlp, args);
  if (r.code !== 0) {
    fs.rmSync(tmpDir, { recursive: true, force: true });
    throw new Error(r.out.trim() || "yt-dlp subtitle download failed");
  }

  const files = fs
    .readdirSync(tmpDir)
    .map((f) => path.join(tmpDir, f))
    .filter((f) => /\.(vtt|srt|ass|ttml)$/i.test(f))
    .sort((a, b) => fs.statSync(b).mtimeMs - fs.statSync(a).mtimeMs);

  if (files.length === 0) {
    fs.rmSync(tmpDir, { recursive: true, force: true });
    throw new Error(`no subtitles found (lang=${lang})`);
  }

  return { tmpDir, subtitlePath: files[0] };
}

async function downloadTranscript({
  url,
  lang,
  timestamps,
  keepBrackets,
  extra,
  toFile,
  transcriptDir,
  meta,
}) {
  if (!url) throw new Error("missing url");

  if (isYouTubeUrl(url)) {
    const id = extractYouTubeId(url);
    if (id) {
      try {
        // Preferred path: direct transcript fetch (no yt-dlp / no files).
        const transcript = await YoutubeTranscript.fetchTranscript(id, {
          lang,
        });
        if (timestamps) {
          const lines = transcript.map((entry) => {
            const ts = formatTimestamp(entry.offset / 1000);
            const text = decodeHtmlEntities(entry.text)
              .replace(/\s+/g, " ")
              .trim();
            return `[${ts}] ${text}`;
          });
          const output = lines.join("\n");
          if (toFile) {
            const filePath = await saveTranscriptToFile({
              text: output,
              url,
              transcriptDir,
              meta,
            });
            process.stdout.write(filePath + "\n");
          } else {
            process.stdout.write(output + "\n");
          }
          return;
        }
        const paragraph = toParagraph(
          transcript.map((e) => decodeHtmlEntities(e.text)),
          { keepBrackets },
        );
        if (!paragraph) throw new Error("empty transcript");
        if (toFile) {
          const filePath = await saveTranscriptToFile({
            text: paragraph,
            url,
            transcriptDir,
            meta,
          });
          process.stdout.write(filePath + "\n");
        } else {
          process.stdout.write(paragraph + "\n");
        }
        return;
      } catch (e) {
        // Fallback to yt-dlp if direct fetch fails
      }
    }
  }

  const { tmpDir, subtitlePath } = await ytDlpSubtitlesToTemp({
    url,
    lang,
    extra,
  });

  try {
    const raw = fs.readFileSync(subtitlePath, "utf8");
    const segments = subtitlePath.endsWith(".srt")
      ? parseSrt(raw)
      : parseVtt(raw);

    if (timestamps) {
      const lines = segments.map((entry) => {
        const ts = formatTimestamp(entry.offset / 1000);
        const text = decodeHtmlEntities(entry.text).replace(/\s+/g, " ").trim();
        return `[${ts}] ${text}`;
      });
      const output = lines.join("\n");
      if (toFile) {
        const filePath = await saveTranscriptToFile({
          text: output,
          url,
          transcriptDir,
          meta,
        });
        process.stdout.write(filePath + "\n");
      } else {
        process.stdout.write(output + "\n");
      }
      return;
    }

    const paragraph = toParagraph(segments, { keepBrackets });
    if (!paragraph) throw new Error("empty transcript from subtitles");
    if (toFile) {
      const filePath = await saveTranscriptToFile({
        text: paragraph,
        url,
        transcriptDir,
        meta,
      });
      process.stdout.write(filePath + "\n");
    } else {
      process.stdout.write(paragraph + "\n");
    }
  } finally {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  }
}

async function cmdTranscript(opts) {
  try {
    await downloadTranscript(opts);
  } catch (e) {
    die(e.message);
  }
}

async function cmdSearch({
  query,
  limit,
  lang,
  timestamps,
  keepBrackets,
  extra,
  toFile,
  transcriptDir,
}) {
  if (!query) die("missing query");
  let searchLimit = limit ? Number(limit) : 1;

  // Auto-detect "top N" in query
  const topMatch = query.match(/top\s*(\d+)/i);
  if (topMatch && !limit) {
    searchLimit = Number(topMatch[1]);
  }

  const ytdlp = resolveBin("yt-dlp", "/opt/homebrew/bin/yt-dlp");
  if (!ytdlp) die("missing yt-dlp");

  // ytsearchN:query
  const searchArg = `ytsearch${searchLimit}:${query}`;
  const args = [
    "--print",
    "%(upload_date)s|%(title).200B|%(id)s",
    "--skip-download",
    searchArg,
  ];

  console.error(`Searching for: "${query}" (limit: ${searchLimit})...`);

  const r = await run(ytdlp, args);
  if (r.code !== 0) die("search failed: " + r.out);

  const lines = r.out
    .split("\n")
    .map((s) => s.trim())
    .filter(Boolean);

  if (lines.length === 0) {
    console.error("No videos found.");
    return;
  }

  console.error(`Found ${lines.length} videos. Processing...`);

  for (const line of lines) {
    const parts = line.split("|");
    if (parts.length < 3) continue;
    const [uploadDate, title, id] = parts;
    const meta = { uploadDate, title, id };
    const url = `https://www.youtube.com/watch?v=${id}`;

    console.error(`Processing [${id}] ${title}...`);
    try {
      await downloadTranscript({
        url,
        lang,
        timestamps,
        keepBrackets,
        extra,
        toFile: true, // Default to file for search results as per user intent
        transcriptDir,
        meta,
      });
    } catch (e) {
      console.error(`Failed to process ${url}: ${e.message}`);
    }
  }
}

async function cmdSubs({ url, lang, outputDir, extra }) {
  if (!url) die("missing --url");

  const { tmpDir, subtitlePath } = await ytDlpSubtitlesToTemp({
    url,
    lang,
    extra,
  });

  try {
    const out = path.resolve(outputDir);
    fs.mkdirSync(out, { recursive: true });
    const dest = path.join(out, path.basename(subtitlePath));
    fs.copyFileSync(subtitlePath, dest);
    process.stdout.write(dest + "\n");
  } finally {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  }
}

async function cmdDownload({ url, outputDir, extra }) {
  if (!url) die("missing --url");
  const ytdlp = resolveBin("yt-dlp", "/opt/homebrew/bin/yt-dlp");
  if (!ytdlp) die("missing yt-dlp; install `yt-dlp` and ensure it is on PATH");

  const out = path.resolve(outputDir);
  fs.mkdirSync(out, { recursive: true });

  const args = [];

  // `--print after_move:filepath` gives the final path after merges/remux.
  args.push(
    "-P",
    out,
    "-o",
    "%(title).200B (%(id)s).%(ext)s",
    "-S",
    "res,ext:mp4:m4a,tbr",
    "--print",
    "after_move:filepath",
  );
  if (extra?.length) args.push(...extra);
  args.push(url);

  const r = await run(ytdlp, args);
  if (r.code !== 0) die(r.out.trim() || "yt-dlp download failed");

  const lines = r.out.split("\n").map((l) => l.trim());
  const filePath = lines.find((l) => l.startsWith("/") && fs.existsSync(l));
  if (!filePath)
    die(r.out.trim() || "could not determine downloaded file path");
  process.stdout.write(path.resolve(filePath) + "\n");
}

async function cmdAudio({ url, outputDir, extra }) {
  if (!url) die("missing --url");
  const ytdlp = resolveBin("yt-dlp", "/opt/homebrew/bin/yt-dlp");
  if (!ytdlp) die("missing yt-dlp; install `yt-dlp` and ensure it is on PATH");
  const ffmpeg = resolveBin("ffmpeg", "/opt/homebrew/bin/ffmpeg");
  if (!ffmpeg)
    die("missing ffmpeg; install `ffmpeg` (needed for audio extraction)");

  const out = path.resolve(outputDir);
  fs.mkdirSync(out, { recursive: true });

  const args = [];

  args.push(
    "--ffmpeg-location",
    ffmpeg,
    "-P",
    out,
    "-o",
    "%(title).200B (%(id)s).%(ext)s",
    "-x",
    "--audio-format",
    "mp3",
    "--print",
    "after_move:filepath",
  );
  if (extra?.length) args.push(...extra);
  args.push(url);

  const r = await run(ytdlp, args);
  if (r.code !== 0) die(r.out.trim() || "yt-dlp audio failed");

  const lines = r.out.split("\n").map((l) => l.trim());
  const filePath = lines.find((l) => l.startsWith("/") && fs.existsSync(l));
  if (!filePath)
    die(r.out.trim() || "could not determine downloaded file path");
  process.stdout.write(path.resolve(filePath) + "\n");
}

async function cmdFormats({ url, extra }) {
  if (!url) die("missing --url");
  const ytdlp = resolveBin("yt-dlp", "/opt/homebrew/bin/yt-dlp");
  if (!ytdlp) die("missing yt-dlp; install `yt-dlp` and ensure it is on PATH");

  // Print raw yt-dlp format table; user picks `--format <id>` for downloads.
  const args = ["-F"];
  if (extra?.length) args.push(...extra);
  args.push(url);

  const r = await run(ytdlp, args);
  if (r.code !== 0) die(r.out.trim() || "yt-dlp formats failed");
  process.stdout.write(r.out);
}

function usage() {
  const rel = path.relative(process.cwd(), path.join(__dirname, "vtd.js"));
  return [
    "usage:",
    `  ${rel} transcript --url 'https://…' [--lang en] [--timestamps] [--keep-brackets] [--no-to-file] [--transcript-dir ./transcripts] [-- <yt-dlp extra…>]`,
    `  ${rel} search     'query' [--limit 3] [--lang en] [--timestamps] [--transcript-dir ./transcripts]`,
    `  ${rel} download   --url 'https://…' [--output-dir ~/Downloads] [-- <yt-dlp extra…>]`,
    `  ${rel} audio      --url 'https://…' [--output-dir ~/Downloads] [-- <yt-dlp extra…>]`,
    `  ${rel} subs       --url 'https://…' [--output-dir ~/Downloads] [--lang en] [-- <yt-dlp extra…>]`,
    `  ${rel} formats    --url 'https://…' [-- <yt-dlp extra…>]`,
  ].join("\n");
}

async function main() {
  const { positional, opts } = parseArgs(process.argv.slice(2));
  const cmd = positional[0];

  if (!cmd || cmd === "help" || cmd === "-h" || cmd === "--help") {
    process.stdout.write(usage() + "\n");
    return;
  }

  const url = opts.url ? opts.url.replace(/['"`]+/g, "").trim() : undefined;
  const lang = opts.lang || "en";
  const outputDir = opts["output-dir"] || path.join(os.homedir(), "Downloads");

  const timestamps = Boolean(opts.timestamps);
  const keepBrackets = Boolean(opts["keep-brackets"]);
  const extra = opts.extra || [];
  const transcriptDir = opts["transcript-dir"] || path.resolve("transcripts");
  const toFile =
    opts["to-file"] !== undefined ? Boolean(opts["to-file"]) : true;
  const limit = opts.limit;

  if (cmd === "transcript") {
    await cmdTranscript({
      url,
      lang,
      timestamps,
      keepBrackets,
      extra,
      toFile,
      transcriptDir,
    });
    return;
  }
  if (cmd === "search") {
    const query = positional[1] || opts.query;
    await cmdSearch({
      query,
      limit,
      lang,
      timestamps,
      keepBrackets,
      extra,
      toFile,
      transcriptDir,
    });
    return;
  }
  if (cmd === "download") {
    await cmdDownload({ url, outputDir, extra });
    return;
  }
  if (cmd === "audio") {
    await cmdAudio({ url, outputDir, extra });
    return;
  }
  if (cmd === "subs") {
    await cmdSubs({ url, lang, outputDir, extra });
    return;
  }
  if (cmd === "formats") {
    await cmdFormats({ url, extra });
    return;
  }

  die(`unknown command: ${cmd}\n\n${usage()}`);
}

main().catch((e) => die(e?.stack || e?.message || String(e)));
