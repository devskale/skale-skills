/**
 * Image Generation Extension
 *
 * Two entry points, both backed by one shared core (generateAndSave):
 *   • a `generate_image` TOOL the LLM calls autonomously, and
 *   • a `/imagegen` (alias `/img`) COMMAND for direct, no-LLM generation:
 *       /imagegen <prompt> [--model M] [--size WxH] [--n N] [--seed S]
 *
 * The generated image is returned as an **image content block** (so vision-capable
 * models can iterate on it) PLUS a compact ASCII preview (so text-only models
 * still get a visual signal, and the user sees something under terminal
 * multiplexers that strip graphics protocols).
 *
 * Backends are reached through the uniinfer proxy using the `provider@modelid`
 * convention — the extension has no backend branching:
 *
 *   POST <proxy>/v1/images/generations
 *   Authorization: Bearer <credgoo key for the provider>
 *   { model: "pollinations@flux" | "tu@z-image-turbo", prompt, size, n }
 *
 * See extensions/imagegen.md for the full design doc.
 */

import { execFile } from "node:child_process";
import { promisify } from "node:util";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import process from "node:process";

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Container, Image, Spacer, Text, type Component } from "@earendil-works/pi-tui";
import { Type } from "typebox";

// execFile (no shell) promisified — used for credgoo + chafa so the event loop
// never blocks on a slow child process. Args are passed as arrays (no shell
// interpolation), which also removes any filename-injection surface.
const execFileAsync = promisify(execFile);

// ── Config ───────────────────────────────────────────────────────────────────

const PROXY_BASE =
	process.env.UNIINFER_PROXY_URL?.replace(/\/+$/, "") || "https://uniinfer.skale.dev/v1";

const DEFAULT_MODEL = process.env.IMAGEGEN_MODEL || "pollinations@flux";
const DEFAULT_SIZE = process.env.IMAGEGEN_SIZE || "512x512";
const ASCII_COLS = 64;
const ASCII_ROWS = 22;

/** customType for the direct-command result message (rendered inline). */
const IMAGEGEN_MSG = "imagegen-result";

// Known image providers — first segment of the `provider@modelid` string.
const PROVIDER_KEYS: Record<string, { env: string; credgoo: string; authFile?: string }> = {
	pollinations: { env: "POLLINATIONS_API_KEY", credgoo: "pollinations" },
	tu: { env: "TU_API_KEY", credgoo: "tu", authFile: "tu-aqueduct" },
};

// ── Helpers ──────────────────────────────────────────────────────────────────

function splitProviderModel(model: string): { provider: string; modelId: string } {
	const idx = model.indexOf("@");
	if (idx === -1) {
		// No provider prefix: assume the default provider with the given id.
		const defaultProvider = DEFAULT_MODEL.split("@")[0];
		return { provider: defaultProvider, modelId: model };
	}
	return { provider: model.slice(0, idx), modelId: model.slice(idx + 1) };
}

/** Resolve the API key for a provider: env → credgoo → ~/.pi/agent/auth.json.
 *  Async because credgoo can take seconds — never block the event loop on it. */
async function resolveKey(provider: string): Promise<string | null> {
	const cfg = PROVIDER_KEYS[provider];
	if (!cfg) return null;

	// 1. Environment variable
	const fromEnv = process.env[cfg.env];
	if (fromEnv && fromEnv.trim()) return fromEnv.trim();

	// 2. credgoo (suppress its stdout chatter). Try the PATH binary, then ~/.local/bin.
	for (const cmd of ["credgoo", path.join(os.homedir(), ".local", "bin", "credgoo")]) {
		try {
			const { stdout } = await execFileAsync(cmd, [cfg.credgoo], {
				encoding: "utf8",
				timeout: 8000,
			});
			const out = stdout.trim();
			if (out && !/^error/i.test(out)) return out;
		} catch {
			/* try next */
		}
	}

	// 3. ~/.pi/agent/auth.json (e.g. tu-aqueduct)
	if (cfg.authFile) {
		try {
			const authPath = path.join(os.homedir(), ".pi", "agent", "auth.json");
			const auth = JSON.parse(fs.readFileSync(authPath, "utf8"));
			const entry = auth[cfg.authFile];
			if (entry?.key) return entry.key;
		} catch {
			/* not present */
		}
	}

	return null;
}

/**
 * Whether to render inline pixel images (Kitty/iTerm2) in the TUI.
 *
 * tmux/screen: pi itself returns images:null here, so ASCII is the only visual.
 * herdr is NOT special-cased — it renders Kitty when the user enables
 * experimental.kitty_graphics (off by default); when off, the model-signal
 * branch below still adds ASCII for non-vision models.
 */
function canRenderInline(): boolean {
	if (process.env.TMUX || process.env.SCREEN) return false;
	return true;
}

/** Whether chafa can run (cached). Probed by invoking it directly — no shell,
 *  no `command -v` — so it works even without a login shell on PATH. */
let _chafaAvailable: Promise<boolean> | undefined;
function chafaAvailable(): Promise<boolean> {
	if (!_chafaAvailable) {
		_chafaAvailable = execFileAsync("chafa", ["--version"], { encoding: "utf8", timeout: 3000 })
			.then(() => true)
			.catch(() => false);
	}
	return _chafaAvailable;
}

/** True if the active model accepts image input (so it can iterate on the result). */
function isVisionCapable(model: unknown): boolean {
	return !!model && Array.isArray((model as any).input) && (model as any).input.includes("image");
}

function guessMime(b64: string): string {
	if (b64.startsWith("/9j/")) return "image/jpeg";
	if (b64.startsWith("UklGR")) return "image/webp";
	if (b64.startsWith("R0lGOD")) return "image/gif";
	// PNG base64 starts with iVBOR
	return "image/png";
}

/** Render an image file to ANSI/ASCII text via chafa (async, no shell).
 *  `--format symbols` is mandatory — without it chafa auto-detects the Kitty
 *  protocol (TERM_PROGRAM=ghostty leaks through) and emits graphics escapes
 *  that a multiplexer strips. */
async function chafaPreview(imgPath: string, cols = ASCII_COLS, rows = ASCII_ROWS): Promise<string> {
	const size = ["--size", `${cols}x${rows}`];
	// color half-blocks first; fall back to plain ASCII on any failure
	try {
		const { stdout } = await execFileAsync(
			"chafa",
			["--format", "symbols", "--symbols", "block-half", "--color-space", "rgb", "--colors", "240", "--work", "5", ...size, imgPath],
			{ encoding: "utf8", timeout: 15000 },
		);
		const out = stdout.trim();
		return out || "(chafa produced no output)";
	} catch {
		try {
			const { stdout } = await execFileAsync(
				"chafa",
				["--format", "symbols", "--symbols", "ascii", "-c", "none", "--work", "5", ...size, imgPath],
				{ encoding: "utf8", timeout: 15000 },
			);
			return stdout.trim();
		} catch {
			return `(unable to render preview; see ${imgPath})`;
		}
	}
}

// ── Image metadata (dependency-free prompt embedding) ────────────────────────
// The generation prompt is baked into the saved file so it survives copies and
// stays findable later. PNG → tEXt chunks (keywords `prompt` + `parameters`);
// JPEG → a COM comment; other formats → a sidecar `<file>.txt` (in-image
// metadata needs format-specific encoders we don't ship). Read it back with:
//   exiftool -parameters <png>   ·   exiftool -Comment <jpg>   ·   cat <file>.txt

/** CRC32 table for PNG chunks (IEEE 802.3 polynomial, init/final 0xFFFFFFFF). */
const PNG_CRC_TABLE: Uint32Array = (() => {
	const t = new Uint32Array(256);
	for (let n = 0; n < 256; n++) {
		let c = n;
		for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
		t[n] = c >>> 0;
	}
	return t;
})();

function pngCrc32(buf: Buffer): number {
	let c = 0xffffffff;
	for (let i = 0; i < buf.length; i++) c = PNG_CRC_TABLE[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
	return (c ^ 0xffffffff) >>> 0;
}

/** Build a PNG `tEXt` chunk: length + "tEXt" + keyword + 0x00 + text + crc. */
function pngTextChunk(keyword: string, text: string): Buffer {
	const kw = Buffer.from(keyword, "latin1");
	const sep = Buffer.from([0]);
	const tx = Buffer.from(text, "utf8");
	const data = Buffer.concat([kw, sep, tx]);
	const type = Buffer.from("tEXt", "latin1");
	const len = Buffer.alloc(4);
	len.writeUInt32BE(data.length, 0);
	const crc = Buffer.alloc(4);
	crc.writeUInt32BE(pngCrc32(Buffer.concat([type, data])), 0);
	return Buffer.concat([len, type, data, crc]);
}

/** Insert tEXt chunks right after IHDR (offset 8 sig + 25 IHDR = 33). */
function embedPngText(buf: Buffer, chunks: { keyword: string; text: string }[]): Buffer {
	if (buf.length < 33) return buf;
	if (buf[0] !== 0x89 || buf[1] !== 0x50 || buf[2] !== 0x4e || buf[3] !== 0x47) return buf;
	const ihdrEnd = 8 + 25;
	const insert = Buffer.concat(chunks.map((c) => pngTextChunk(c.keyword, c.text)));
	return Buffer.concat([buf.subarray(0, ihdrEnd), insert, buf.subarray(ihdrEnd)]);
}

/** Build one or more JPEG COM (0xFFFE) segments — splits at 65533 data bytes. */
function jpegComSegments(text: string): Buffer {
	const data = Buffer.from(text, "utf8");
	const maxData = 65533; // 65535 segment length − 2 length bytes
	const segs: Buffer[] = [];
	for (let i = 0; i < data.length; i += maxData) {
		const part = data.subarray(i, i + maxData);
		const lenBuf = Buffer.alloc(2);
		lenBuf.writeUInt16BE(part.length + 2, 0);
		segs.push(Buffer.from([0xff, 0xfe]), lenBuf, part);
	}
	return Buffer.concat(segs);
}

/** Insert a COM comment immediately after SOI (FF D8). */
function embedJpegCom(buf: Buffer, text: string): Buffer {
	if (buf.length < 2 || buf[0] !== 0xff || buf[1] !== 0xd8) return buf;
	return Buffer.concat([buf.subarray(0, 2), jpegComSegments(text), buf.subarray(2)]);
}

interface ImageMeta {
	prompt: string;
	model: string;
	size: string;
	seed?: number;
	n: number;
}

/** Embed the generation prompt into the image, dependency-free.
 *  Returns the (possibly rewritten) buffer and, for formats we can't edit
 *  in-place, a `sidecar` string to write as `<file>.txt` so the prompt is never lost. */
function embedMetadata(buf: Buffer, mime: string, meta: ImageMeta): { buf: Buffer; sidecar?: string } {
	const paramLine = [
		`prompt: ${meta.prompt}`,
		`model: ${meta.model}`,
		`size: ${meta.size}`,
		`n: ${meta.n}`,
		...(meta.seed != null ? [`seed: ${meta.seed}`] : []),
	].join("\n");
	if (mime === "image/png") {
		return {
			buf: embedPngText(buf, [
				{ keyword: "prompt", text: meta.prompt },
				{ keyword: "parameters", text: paramLine },
			]),
		};
	}
	if (mime === "image/jpeg") {
		return { buf: embedJpegCom(buf, paramLine) };
	}
	// WebP/GIF/BMP: in-image metadata needs format-specific encoders; record a
	// sidecar .txt so the prompt is preserved alongside the image.
	return { buf, sidecar: paramLine };
}

/** Choose output dir.
 *  1. IMAGEGEN_OUTPUT_DIR env (absolute, or relative to cwd) — explicit override.
 *  2. uploads/ if it exists in cwd — web-served in πui (opt-in: create uploads/).
 *  3. ~/Pictures/generated/ on macOS — a stable home dir for generated images.
 *  4. ./generated/ — last-resort project-local default (non-mac). */
function outputDir(cwd: string): { dir: string; webUrl: boolean } {
	const override = process.env.IMAGEGEN_OUTPUT_DIR?.trim();
	if (override) {
		return { dir: path.isAbsolute(override) ? override : path.resolve(cwd, override), webUrl: false };
	}
	const uploads = path.join(cwd, "uploads");
	try {
		if (fs.statSync(uploads).isDirectory()) return { dir: uploads, webUrl: true };
	} catch {
		/* not present */
	}
	if (process.platform === "darwin") {
		const home = os.homedir();
		if (home) return { dir: path.join(home, "Pictures", "generated"), webUrl: false };
	}
	return { dir: path.join(cwd, "generated"), webUrl: false };
}

// ── Types ────────────────────────────────────────────────────────────────────

interface ImageItem {
	b64: string;
	url?: string;
	mime: string;
	path: string;
	webUrl?: string;
}

type TextBlock = { type: "text"; text: string };
// pi-native image block shape — pi's normalizeToolResultImages reads `data` and
// `mimeType` directly (Buffer.from(block.data, "base64")). The OpenAI-style
// `source: { type, mediaType, data }` shape crashes that path (data is undefined).
type ImageBlock = { type: "image"; data: string; mimeType: string };
type ContentBlock = TextBlock | ImageBlock;

// ── Shared core: validate → resolve key → call proxy → persist to disk ───────

interface GenOpts {
	prompt: string;
	model?: string;
	size?: string;
	n?: number;
	seed?: number;
	cwd: string;
	signal?: AbortSignal;
}

type GenResult =
	| { ok: true; saved: ImageItem[]; provider: string; modelId: string; size: string }
	| { ok: false; error: string };

async function generateAndSave(opts: GenOpts): Promise<GenResult> {
	const model = (opts.model || DEFAULT_MODEL).trim();
	const { provider, modelId } = splitProviderModel(model);
	if (!PROVIDER_KEYS[provider]) {
		return { ok: false, error: `unknown provider "${provider}". Known: ${Object.keys(PROVIDER_KEYS).join(", ")}` };
	}
	const size = (opts.size || DEFAULT_SIZE).trim();
	const n = Math.max(1, Math.min(4, Math.floor(opts.n ?? 1)));

	const key = await resolveKey(provider);
	if (!key) {
		const cfg = PROVIDER_KEYS[provider];
		return {
			ok: false,
			error: `no API key for provider "${provider}". Set ${cfg.env} or run \`credgoo ${cfg.credgoo}\`.`,
		};
	}

	let data: { data?: Array<{ b64_json?: string; url?: string }> };
	try {
		const resp = await fetch(`${PROXY_BASE}/images/generations`, {
			method: "POST",
			headers: { "Content-Type": "application/json", Authorization: `Bearer ${key}` },
			body: JSON.stringify({
				model: `${provider}@${modelId}`,
				prompt: opts.prompt,
				size,
				n,
				...(opts.seed != null ? { seed: opts.seed } : {}),
			}),
			signal: opts.signal,
		});
		if (!resp.ok) {
			const detail = await resp.text().catch(() => "");
			return { ok: false, error: `proxy returned ${resp.status} ${resp.statusText}${detail ? ` — ${detail}` : ""}` };
		}
		data = (await resp.json()) as typeof data;
	} catch (e) {
		const msg = e instanceof Error ? e.message : String(e);
		return { ok: false, error: `request failed — ${msg.split("Authorization")[0]}` };
	}

	const items = data.data ?? [];
	if (!items.length) return { ok: false, error: "no images returned" };

	const { dir, webUrl } = outputDir(opts.cwd);
	fs.mkdirSync(dir, { recursive: true });
	const ts = Date.now();
	const saved: ImageItem[] = [];
	for (let i = 0; i < items.length; i++) {
		const it = items[i];
		let b64 = it.b64_json;
		if (!b64 && it.url) {
			try {
				const r = await fetch(it.url, { signal: opts.signal });
				if (r.ok) b64 = Buffer.from(await r.arrayBuffer()).toString("base64");
			} catch {
				/* leave undefined */
			}
		}
		if (!b64) continue;
		const mime = guessMime(b64);
		const ext = mime === "image/jpeg" ? "jpg" : mime.split("/")[1] || "png";
		const file = items.length === 1 ? `generated-${ts}.${ext}` : `generated-${ts}-${i}.${ext}`;
		const abs = path.resolve(dir, file);
		// Bake the generation prompt into the image metadata before writing, so it
		// travels with the file (PNG tEXt / JPEG COM / sidecar .txt for others).
		const rawBuf = Buffer.from(b64, "base64");
		const { buf: writtenBuf, sidecar } = embedMetadata(rawBuf, mime, {
			prompt: opts.prompt,
			model: `${provider}@${modelId}`,
			size,
			seed: opts.seed,
			n,
		});
		fs.writeFileSync(abs, writtenBuf);
		if (sidecar) fs.writeFileSync(`${abs}.txt`, sidecar);
		// b64 stays the ORIGINAL bytes (what the model sees / iterates on) — the
		// metadata only lands on disk, keeping the inline block byte-identical to
		// what the provider returned.
		saved.push({ b64, url: it.url, mime, path: abs, webUrl: webUrl ? `/uploads/${file}` : undefined });
	}
	if (!saved.length) return { ok: false, error: "generated images had no usable data" };
	return { ok: true, saved, provider, modelId, size };
}

/** Build the ASCII preview if needed (display fallback OR model signal). */
async function maybeAscii(saved: ImageItem[], model: unknown): Promise<string | undefined> {
	const terminalCantRender = !canRenderInline();
	const modelCantSee = !isVisionCapable(model);
	if (!((await chafaAvailable()) && (terminalCantRender || modelCantSee))) return undefined;
	return (await Promise.all(saved.map((s) => chafaPreview(s.path)))).join("\n\n");
}

/** Parse `/imagegen` arg string: flags + free-form prompt. */
function parseImagegenArgs(raw: string): { prompt: string; model?: string; size?: string; n?: number; seed?: number } {
	const tokens = raw.split(/\s+/);
	const promptParts: string[] = [];
	let model: string | undefined;
	let size: string | undefined;
	let n: number | undefined;
	let seed: number | undefined;
	for (let i = 0; i < tokens.length; i++) {
		const t = tokens[i];
		const next = (): string | undefined => tokens[++i];
		if (t === "--model" || t === "-m") model = next();
		else if (t === "--size" || t === "-s") size = next();
		else if (t === "--n" || t === "-n") n = next() ? Number(tokens[i]) : undefined;
		else if (t === "--seed") seed = next() ? Number(tokens[i]) : undefined;
		else if (t.startsWith("--model=")) model = t.slice(8);
		else if (t.startsWith("--size=")) size = t.slice(7);
		else if (t.startsWith("--n=")) n = Number(t.slice(4));
		else if (t.startsWith("--seed=")) seed = Number(t.slice(7));
		else promptParts.push(t);
	}
	return { prompt: promptParts.join(" ").trim(), model, size, n, seed };
}

// ── Extension ────────────────────────────────────────────────────────────────

export default function imagegenExtension(pi: ExtensionAPI) {
	// --- 1. The TOOL (LLM-driven) ---
	pi.registerTool({
		name: "generate_image",
		label: "Generate Image",
		description:
			"Generate an image from a text prompt. Returns the image inline (the model can see it and iterate) plus an ASCII preview. " +
			'Model is "provider@modelid", e.g. "pollinations@flux" (fast, default) or "tu@z-image-turbo" (high quality). ' +
			"Images are saved to ~/Pictures/generated/ on macOS (./uploads/ if present, or ./generated/ otherwise); the prompt is embedded in the file metadata.",
		promptSnippet: "Generate an image from a text prompt; model sees the result and can iterate",
		promptGuidelines: [
			"Use generate_image when the user asks to create, draw, or generate an image/picture/illustration/logo. " +
				"After generating, review the returned image and, if needed, call generate_image again with a refined prompt.",
		],
		parameters: Type.Object({
			prompt: Type.String({ description: "Text-to-image prompt. Be vivid: subject, style, composition, lighting, mood." }),
			model: Type.Optional(
				Type.String({
					description: `provider@modelid (default: ${DEFAULT_MODEL}). Providers: pollinations (flux, kontext, nanobanana, seedream, ideogram-v4…), tu (z-image-turbo).`,
				}),
			),
			size: Type.Optional(Type.String({ description: `Image size WxH (default: ${DEFAULT_SIZE}).` })),
			n: Type.Optional(Type.Number({ description: "Number of images 1–4 (default 1)." })),
			seed: Type.Optional(Type.Number({ description: "Optional reproducibility seed." })),
		}),

		async execute(_toolCallId, params, _signal, onUpdate, ctx) {
			const prompt = (params.prompt || "").trim();
			if (!prompt) {
				return { content: [{ type: "text" as const, text: "Error: prompt is required." }], isError: true };
			}

			onUpdate?.({ content: [{ type: "text", text: "Generating…" }] });
			const res = await generateAndSave({
				prompt,
				model: params.model,
				size: params.size,
				n: params.n,
				seed: params.seed,
				cwd: ctx.cwd,
				signal: ctx.signal,
			});
			if (!res.ok) {
				return { content: [{ type: "text" as const, text: `Error: ${res.error}` }], isError: true };
			}

			const { saved, provider, modelId, size } = res;
			const content: ContentBlock[] = [];
			const locationLines = saved.map((s) => `  • ${s.webUrl ?? s.path}`).join("\n");
			content.push({
				type: "text",
				text: `Generated ${saved.length} image${saved.length > 1 ? "s" : ""} via ${provider}@${modelId} (${size}):\n${locationLines}`,
			});
			for (const s of saved) {
				content.push({ type: "image", data: s.b64, mimeType: s.mime });
			}
			const asciiArt = await maybeAscii(saved, ctx.model);
			if (asciiArt) {
				content.push({ type: "text", text: "\nASCII preview (model signal / display fallback):\n```\n" + asciiArt + "\n```" });
			}

			return {
				content,
				details: { provider, model: modelId, size, paths: saved.map((s) => s.path), asciiPreview: !!asciiArt },
			};
		},

		renderResult(result, { isPartial }, theme) {
			if (isPartial) {
				return new Text(theme.fg("warning", "🖼 generating…"), 0, 0);
			}
			const details = (
				result as { details?: { provider?: string; model?: string; size?: string; paths?: string[] } }
			).details;
			if (result.isError || !details) {
				const txt = result.content?.[0] && "text" in result.content[0] ? result.content[0].text : "error";
				return new Text(theme.fg("error", `✗ ${txt}`), 0, 0);
			}
			const count = details.paths?.length ?? 0;
			const where = details.paths?.[0] ?? "";
			const label = `🖼 ${details.provider}@${details.model} • ${count} image${count > 1 ? "s" : ""} → ${where}`;
			return new Text(theme.fg("success", label), 0, 0);
		},
	});

	// --- 2. The COMMAND (direct, no LLM) — shared core + inline-rendered result ---
	async function runImagegenCommand(args: string, ctx: ExtensionContext): Promise<void> {
		const raw = (args ?? "").trim();
		if (!raw) {
			ctx.ui.notify("imagegen: usage — /imagegen <prompt> [--model M] [--size WxH] [--n N] [--seed S]  (alias /img)", "warning");
			return;
		}
		const { prompt, model, size, n, seed } = parseImagegenArgs(raw);
		if (!prompt) {
			ctx.ui.notify("imagegen: no prompt given", "warning");
			return;
		}

		ctx.ui.setStatus("imagegen", ctx.ui.theme.fg("accent", "🖼 generating…"));
		const res = await generateAndSave({ prompt, model, size, n, seed, cwd: ctx.cwd, signal: ctx.signal });
		ctx.ui.setStatus("imagegen", undefined);
		if (!res.ok) {
			ctx.ui.notify(`imagegen: ${res.error}`, "error");
			return;
		}

		const { saved, provider, modelId, size: sz } = res;
		const asciiArt = await maybeAscii(saved, ctx.model);
		const locationLines = saved.map((s) => `  • ${s.webUrl ?? s.path}`).join("\n");
		const summary = `Generated ${saved.length} image${saved.length > 1 ? "s" : ""} via ${provider}@${modelId} (${sz}):\n${locationLines}`;

		// content (goes into LLM context for later turns) + details (for our renderer)
		const content: ContentBlock[] = [
			{ type: "text", text: summary },
			...saved.map((s): ImageBlock => ({ type: "image", data: s.b64, mimeType: s.mime })),
		];
		ctx.sessionManager.appendCustomMessageEntry(IMAGEGEN_MSG, content as any, true, {
			provider,
			model: modelId,
			size: sz,
			paths: saved.map((s) => s.path),
			images: saved.map((s) => ({ b64: s.b64, mime: s.mime })),
			asciiArt,
		});
		ctx.ui.notify(`imagegen: ${saved.length} image${saved.length > 1 ? "s" : ""} → ${saved[0].path}`, "info");
	}

	pi.registerCommand("imagegen", {
		description: "/imagegen <prompt> [--model M] [--size WxH] [--n N] [--seed S] — generate an image directly (no LLM round-trip). Alias: /img",
		handler: async (args, ctx) => {
			await runImagegenCommand(args ?? "", ctx);
		},
	});
	pi.registerCommand("img", {
		description: "Alias for /imagegen",
		handler: async (args, ctx) => {
			await runImagegenCommand(args ?? "", ctx);
		},
	});

	// --- 3. Inline renderer for the command's result message (draws the Image) ---
	pi.registerMessageRenderer(
		IMAGEGEN_MSG,
		(message, _opts, theme): Component | undefined => {
			const d = (message as { details?: {
				provider?: string;
				model?: string;
				paths?: string[];
				images?: Array<{ b64: string; mime: string }>;
				asciiArt?: string;
			} }).details;
			const c = new Container();
			const count = d?.images?.length ?? d?.paths?.length ?? 0;
			c.addChild(new Text(theme.fg("success", `🖼 ${d?.provider ?? "?"}@${d?.model ?? "?"} • ${count} image${count > 1 ? "s" : ""}`), 0, 0));
			if (d?.images) {
				for (const im of d.images) {
					c.addChild(new Spacer(1));
					c.addChild(
						new Image(im.b64, im.mime, { fallbackColor: (s: string) => theme.fg("muted", s) }, { maxWidthCells: 80, maxHeightCells: 24 }),
					);
				}
			}
			if (d?.paths?.length) {
				c.addChild(new Spacer(1));
				c.addChild(new Text(theme.fg("dim", d.paths.map((p) => `  • ${p}`).join("\n")), 0, 0));
			}
			if (d?.asciiArt) {
				c.addChild(new Spacer(1));
				c.addChild(new Text(d.asciiArt, 0, 0));
			}
			return c;
		},
	);
}
