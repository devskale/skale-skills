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
 *   { model: "provider@modelid", prompt, size, n }
 *
 * Model discovery probes the per-provider GET <proxy>/v1/image/models/<provider>
 * catalog (fallback: filtered /models) — no hardcoded model names. When a
 * requested model is unavailable (400 invalid model) or unaffordable (402),
 * the extension auto-probes the provider's other available models, cheapest-
 * first by learned cost, and caches the last-good model. See extensions/imagegen.md
 * for the full design doc.
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
import { guessMime, isVisionCapable } from "./lib/image-utils";

// ctx.sessionManager is typed as ReadonlySessionManager (read-only surface), but at
// runtime it IS the full SessionManager — which exposes appendCustomMessageEntry for
// writing inline custom entries. Cast to the write-capable subset to use it.
interface WritableSessionManager {
	appendCustomMessageEntry<T = unknown>(
		customType: string,
		content: string | Array<{ type: string; text?: string; data?: string; mimeType?: string }>,
		display: boolean,
		details?: T,
	): string;
}
function writeEntry(ctx: ExtensionContext, ...args: Parameters<WritableSessionManager["appendCustomMessageEntry"]>) {
	return (ctx.sessionManager as unknown as WritableSessionManager).appendCustomMessageEntry(...args);
}

// execFile (no shell) promisified — used for credgoo + chafa so the event loop
// never blocks on a slow child process. Args are passed as arrays (no shell
// interpolation), which also removes any filename-injection surface.
const execFileAsync = promisify(execFile);

// ── Config ───────────────────────────────────────────────────────────────────

const PROXY_BASE =
	process.env.UNIINFER_PROXY_URL?.replace(/\/+$/, "") || "https://uniinfer.skale.dev/v1";

// Default model per provider. pollinations@dreamshaper is the cheapest
// pollinations model (~0.0001 pollen vs flux's 0.0020); tu@z-image-turbo is
// TU's only model. Override with IMAGEGEN_MODEL (a full provider@modelid).
const DEFAULT_MODEL = process.env.IMAGEGEN_MODEL || "tu@z-image-turbo";
const DEFAULT_SIZE = process.env.IMAGEGEN_SIZE || "512x512";
const ASCII_COLS = 64;
const ASCII_ROWS = 22;

/** customType for the direct-command result message (rendered inline). */
const IMAGEGEN_MSG = "imagegen-result";
/** customType for the /imagegen help panel (rendered inline). */
const IMAGEGEN_HELP_MSG = "imagegen-help";

// Known provider → credgoo service name overrides. Unlisted providers use
// their provider name as the credgoo service. This is the only provider-ish
// map, and it's purely a key-lookup convenience — any provider is allowed.
const CREDGOO_SERVICE: Record<string, string> = {
	pollinations: "pollinations",
	tu: "tu",
};

// ── Persistent state: last-good model + learned costs per provider ─────────
// Nothing about models or prices is hardcoded. The extension discovers the
// live model list from the proxy's OpenAI-compatible /models catalog, learns
// per-model cost from 402 responses ("costs ~N pollen"), and remembers which
// model last generated successfully so it can auto-fix the default. Stored in
// ~/.pi/agent/imagegen-state.json.
const STATE_PATH = path.join(os.homedir(), ".pi", "agent", "imagegen-state.json");
const MODEL_CACHE_TTL_MS = 60 * 60 * 1000; // refresh model list after 1h

interface ImagegenState {
	lastGoodModel?: Record<string, string>; // provider -> modelId that last succeeded
	costs?: Record<string, Record<string, number>>; // provider -> modelId -> learned cost
	imageModels?: { models: string[]; at: number }; // cached live image model list ("provider@modelid")
	settings?: ImagegenSettings; // user-chosen defaults from the settings menu
}

/** User-chosen defaults (persisted in imagegen-state.json, win over auto-heal). */
interface ImagegenSettings {
	model?: string; // full "provider@modelid"
	size?: string;
	n?: number;
}

function loadState(): ImagegenState {
	try {
		return JSON.parse(fs.readFileSync(STATE_PATH, "utf8")) as ImagegenState;
	} catch {
		return {};
	}
}

function saveState(state: ImagegenState): void {
	try {
		fs.mkdirSync(path.dirname(STATE_PATH), { recursive: true });
		fs.writeFileSync(STATE_PATH, JSON.stringify(state, null, 2));
	} catch {
		/* non-fatal: state is an optimization, not a requirement */
	}
}

function getSettings(): ImagegenSettings {
	return loadState().settings ?? {};
}

function saveSettings(settings: ImagegenSettings): void {
	const state = loadState();
	state.settings = settings;
	saveState(state);
}

/** The modelId that last generated successfully for a provider, if any. */
function lastGoodModel(provider: string): string | undefined {
	return loadState().lastGoodModel?.[provider];
}

/** Remember this provider/model as the next default (persisted). */
function rememberLastGood(provider: string, modelId: string): void {
	const state = loadState();
	state.lastGoodModel = { ...(state.lastGoodModel ?? {}), [provider]: modelId };
	saveState(state);
}

/** Record a learned per-model pollen cost from a 402 response (persisted). */
function learnCost(provider: string, modelId: string, cost: number): void {
	const state = loadState();
	state.costs = {
		...(state.costs ?? {}),
		[provider]: { ...(state.costs?.[provider] ?? {}), [modelId]: cost },
	};
	saveState(state);
}

/** Parse "costs ~0.0020 pollen" out of a 402 error detail string. */
function parseCost(error: string): number | undefined {
	const m = /costs?\s+~?([0-9.]+)\s+pollen/i.exec(error);
	if (!m) return undefined;
	const c = parseFloat(m[1]);
	return Number.isFinite(c) ? c : undefined;
}

/**
 * Whether an error means the requested model is unavailable (renamed/removed)
 * rather than some other failure. These are "probe" signals: the model is
 * gone, so we should fall back to an available one instead of failing hard.
 * Matches the uniinfer proxy's 400 responses for bad model names/aliases.
 */
function isModelUnavailable(error: string): boolean {
	return /invalid model or alias|invalid provider_model format|model[^\n]*(not found|does not exist|unknown|unavailable)/i.test(error);
}

/**
 * Fetch the authoritative list of image-capable model ids for a provider.
 *
 * Primary source is the per-provider `/image/models/<provider>` endpoint
 * (returns `{ data: [{ id }] }` of image models only — reliable and complete,
 * e.g. 44 pollinations image models incl. zimage/flux that the general
 * /models catalog misses). Falls back to filtering the OpenAI-compatible
 * /models catalog by image type/modality if the per-provider endpoint is
 * unreachable. Returns bare model ids (no provider@ prefix), cached briefly.
 * Empty on failure.
 */
async function imageModelsForProvider(provider: string): Promise<string[]> {
	const cached = loadState().imageModels;
	if (cached && Date.now() - cached.at < MODEL_CACHE_TTL_MS) {
		return cached.models.filter((id) => id.startsWith(`${provider}@`)).map((id) => id.slice(provider.length + 1));
	}

	let models: string[] = [];
	// 1. Per-provider image model list (authoritative).
	try {
		const resp = await fetch(`${PROXY_BASE}/image/models/${provider}`);
		if (resp.ok) {
			const body = (await resp.json()) as { data?: Array<{ id?: string }> };
			models = (body.data ?? []).map((m) => m?.id).filter((id): id is string => !!id);
		}
	} catch {
		/* fall through to /models */
	}

	// 2. Fallback: filter the general catalog by image type/modality.
	if (!models.length) {
		try {
			const resp = await fetch(`${PROXY_BASE}/models`);
			if (resp.ok) {
				const body = (await resp.json()) as { data?: Array<{ id?: string; type?: string; modalities?: { output?: string[] } }> };
				const all = (body.data ?? []).filter((m) => m?.id && (m.type === "image" || (m.modalities?.output ?? []).includes("image"))).map((m) => m.id as string);
				models = all.filter((id) => id.startsWith(`${provider}@`)).map((id) => id.slice(provider.length + 1));
			}
		} catch {
			/* empty */
		}
	}

	if (models.length) {
		const state = loadState();
		const full = models.map((id) => `${provider}@${id}`);
		state.imageModels = { models: full, at: Date.now() };
		saveState(state);
	}
	return models;
}



/**
 * Ordered candidate modelIds to try for a provider: the requested model first,
 * then the provider's live image models ordered by learned cost (cheapest
 * first, unknown costs last), bounded so we don't probe the whole catalog.
 * 402s are free (rejected before generation), so probing unknown-cost models
 * only costs balance on success. If the provider isn't image-capable or has a
 * single model, we just try the requested one.
 */
async function fallbackCandidates(provider: string, requested: string): Promise<string[]> {
	const models = await imageModelsForProvider(provider);
	if (!models.length) return [requested];
	const costs = loadState().costs?.[provider] ?? {};
	const others = models.filter((m) => m !== requested);
	const known = others.filter((m) => costs[m] != null).sort((a, b) => (costs[a] ?? 0) - (costs[b] ?? 0));
	const unknown = others.filter((m) => costs[m] == null);
	return [requested, ...known, ...unknown].slice(0, 9);
}

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

/** Resolve an API key for a provider: env → credgoo → ~/.pi/agent/auth.json.
 *  Generic across providers — unlisted providers use their name as the credgoo
 *  service. Returns null when no key is configured (keyless providers are fine).
 *  Async because credgoo can take seconds — never block the event loop on it. */
async function resolveKey(provider: string): Promise<string | null> {
	const service = CREDGOO_SERVICE[provider] ?? provider;

	// 1. Environment variable (provider name uppercased, e.g. POLLINATIONS_API_KEY)
	const fromEnv = process.env[`${provider.toUpperCase()}_API_KEY`];
	if (fromEnv && fromEnv.trim()) return fromEnv.trim();

	// 2. credgoo (suppress its stdout chatter). Try the PATH binary, then ~/.local/bin.
	for (const cmd of ["credgoo", path.join(os.homedir(), ".local", "bin", "credgoo")]) {
		try {
			const { stdout } = await execFileAsync(cmd, [service], {
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
	try {
		const authPath = path.join(os.homedir(), ".pi", "agent", "auth.json");
		const auth = JSON.parse(fs.readFileSync(authPath, "utf8"));
		const entry = auth[service];
		if (entry?.key) return entry.key;
	} catch {
		/* not present */
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
 *  3. $XDG_CACHE_HOME/generated (default ~/.cache/generated) — XDG-standard home for
 *     regenerable generated output.
 *  4. ./generated/ — last-resort project-local default. */
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
	const xdgCache = process.env.XDG_CACHE_HOME?.trim();
	const base = xdgCache ? path.resolve(xdgCache) : path.join(os.homedir(), ".cache");
	return { dir: path.join(base, "generated"), webUrl: false };
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
	| {
			ok: true;
			saved: ImageItem[];
			provider: string;
			modelId: string;
			size: string;
			fellBack?: boolean;
			fromModel?: string;
	  }
	| { ok: false; error: string; creditExhausted?: boolean; suggested?: string };

/** Parse a 402 / insufficient-balance / out-of-credits error. */
function isCreditExhausted(error: string): boolean {
	return /402|insufficient.{0,20}(balance|credit)|out of (credit|balance)|no (credit|balance)|credit.{0,10}(exhaust|limit)|balance.{0,10}(exhaust|insufficient)/i.test(error);
}

/**
 * pollinations-free — direct fallback to pollinations' own public image API.
 *
 * The uniinfer relay bills pollinations behind its own "pollen" meter, and when
 * the relay account's balance is 0 every pollinations image model 402s. But
 * pollinations' own API (image.pollinations.ai) is free and needs NO key. When
 * the relay is credit-exhausted for pollinations, we route around it to the
 * direct endpoint instead of failing. Returns saved images (same ImageItem
 * shape as the relay path) or an error.
 */
async function generatePollinationsFree(opts: GenerateOnceOpts): Promise<GenResult> {
	const { modelId, prompt, size, n, seed, signal, cwd } = opts;
	const [w, h] = size.split("x").map((s) => parseInt(s, 10));
	const width = Number.isFinite(w) ? w : 512;
	const height = Number.isFinite(h) ? h : 512;

	// The direct API is one image per request; loop for n, each with a distinct
	// seed so variants differ (seed ? seed+i : random).
	try {
		const { dir, webUrl } = outputDir(cwd);
		fs.mkdirSync(dir, { recursive: true });
		const ts = Date.now();
		const saved: ImageItem[] = [];
		for (let i = 0; i < n; i++) {
			const s = seed != null ? seed + i : Math.floor(Math.random() * 1_000_000);
			const params = new URLSearchParams({
				width: String(width),
				height: String(height),
				model: modelId,
				seed: String(s),
				nologo: "true",
			});
			const url = `https://image.pollinations.ai/prompt/${encodeURIComponent(prompt)}?${params}`;
			const resp = await fetch(url, { signal });
			if (!resp.ok) {
				const detail = await resp.text().catch(() => "");
				return { ok: false, error: `pollinations-free returned ${resp.status} ${resp.statusText}${detail ? ` — ${detail}` : ""}` };
			}
			const rawBuf = Buffer.from(await resp.arrayBuffer());
			const mime = guessMime(rawBuf.toString("base64"));
			const ext = mime === "image/jpeg" ? "jpg" : mime.split("/")[1] || "png";
			const file = n === 1 ? `generated-${ts}.${ext}` : `generated-${ts}-${i}.${ext}`;
			const abs = path.resolve(dir, file);
			const { buf: writtenBuf, sidecar } = embedMetadata(rawBuf, mime, {
				prompt,
				model: `pollinations@${modelId}`,
				size: `${width}x${height}`,
				seed: s,
				n: 1,
			});
			fs.writeFileSync(abs, writtenBuf);
			if (sidecar) fs.writeFileSync(`${abs}.txt`, sidecar);
			saved.push({ b64: rawBuf.toString("base64"), mime, path: abs, webUrl: webUrl ? `/uploads/${file}` : undefined });
		}
		if (!saved.length) return { ok: false, error: "no images returned" };
		return { ok: true, saved, provider: "pollinations", modelId, size: `${width}x${height}` };
	} catch (e) {
		const msg = e instanceof Error ? e.message : String(e);
		return { ok: false, error: `pollinations-free request failed — ${msg}` };
	}
}

/**
 * Build a "switch model" suggestion from the provider's other image models.
 * Returns a short hint like "try pollinations@flux or pollinations@zimage".
 */
async function suggestSwitch(provider: string, current: string): Promise<string> {
	try {
		const models = await imageModelsForProvider(provider);
		const others = models.filter((m) => m !== current);
		if (!others.length) return "";
		const names = others.slice(0, 3).map((m) => `${provider}@${m}`).join(", ");
		return `try ${names}`;
	} catch {
		return "";
	}
}

async function generateAndSave(opts: GenOpts): Promise<GenResult> {
	const settings = getSettings();
	const size = (opts.size || settings.size || DEFAULT_SIZE).trim();
	const n = Math.max(1, Math.min(4, Math.floor(opts.n ?? settings.n ?? 1)));

	// Resolve the model. Explicit --model wins; then the user's settings-menu
	// choice; then the stored last-good model for the provider; else the
	// env/compile-time default.
	const defaultProvider = DEFAULT_MODEL.split("@")[0];
	const stored = lastGoodModel(defaultProvider);
	const configured = settings.model || (stored ? `${defaultProvider}@${stored}` : undefined);
	const model = (opts.model || configured || DEFAULT_MODEL).trim();
	const { provider, modelId } = splitProviderModel(model);

	// Resolve an API key if the provider has one. Keyless providers (e.g.
	// pollinations, ollama) proceed without a Bearer — the proxy handles it.
	const key = await resolveKey(provider);

	// Try the requested model, then fall back through the provider's live image
	// models ordered by learned cost. On success, persist the winner as the
	// provider's new last-good default so the next call self-heals.
	const candidates = await fallbackCandidates(provider, modelId);
	let lastError: string | undefined;
	let fellBack = false;
	for (const candidate of candidates) {
		const attempt = await generateOnce({
			provider,
			modelId: candidate,
			key,
			prompt: opts.prompt,
			size,
			n,
			seed: opts.seed,
			signal: opts.signal,
			cwd: opts.cwd,
		});
		if (attempt.ok) {
			rememberLastGood(provider, candidate);
			if (fellBack) {
				attempt.fellBack = true;
				attempt.fromModel = modelId;
			}
			return attempt;
		}
		// Learn the cost of this model from a 402 (rejected before generating),
		// so future fallback ordering is accurate. A model-unavailable 400
		// (renamed/removed) is a probe signal — fall through to an available
		// model rather than failing hard. Other non-402 errors of the requested
		// model are terminal and surfaced as-is.
		const cost = parseCost(attempt.error);
		if (cost != null) {
			learnCost(provider, candidate, cost);
			if (candidate === modelId) fellBack = true; // requested model is unaffordable
		} else if (isModelUnavailable(attempt.error)) {
			if (candidate === modelId) fellBack = true; // requested model is gone — probe onward
		} else if (candidate === modelId) {
			// Non-402, non-unavailable failure of the requested model: for
			// pollinations, still try the free direct API before calling it
			// terminal (the relay's pollinations tier is billed AND flaky — 402
			// credit-exhausted or 502 upstream); for other providers it's terminal.
			if (provider !== "pollinations") return attempt;
		}
		lastError = attempt.error;

		// pollinations-free: pollinations' own public API is free and keyless,
		// but the uniinfer relay bills it behind its own pollen meter (402 when
		// the relay balance is 0) and its upstream can 502. When the relay
		// fails for a pollinations model for ANY reason, route around the relay
		// to the direct endpoint instead of giving up.
		if (provider === "pollinations") {
			const direct = await generatePollinationsFree({
				provider,
				modelId: candidate,
				key: null,
				prompt: opts.prompt,
				size,
				n,
				seed: opts.seed,
				signal: opts.signal,
				cwd: opts.cwd,
			});
			if (direct.ok) {
				rememberLastGood(provider, candidate);
				if (fellBack) {
					direct.fellBack = true;
					direct.fromModel = modelId;
				}
				return direct;
			}
			lastError = direct.error;
		}
	}
	// Terminal failure. If the requested model is out of credits (or every
	// fallback was), return a structured error the caller can use to offer a
	// switch to another model rather than a bare "generation failed".
	//
	// Emergency pollinations-free: if the primary provider is a relay provider
	// (tu, unii, etc.) and ALL its candidates failed (credit-exhausted, 502, or
	// outright down), fall back to pollinations' own free, keyless public API
	// as a last resort so generation still succeeds even when the relay is
	// completely unusable. This only fires after the provider's own fallback
	// loop is exhausted.
	if (provider !== "pollinations" && lastError) {
		const direct = await generatePollinationsFree({
			provider,
			modelId,
			key: null,
			prompt: opts.prompt,
			size,
			n,
			seed: opts.seed,
			signal: opts.signal,
			cwd: opts.cwd,
		});
		if (direct.ok) {
			direct.fellBack = true;
			direct.fromModel = model;
			return direct;
		}
		lastError = direct.error;
	}
	const creditExhausted = lastError ? isCreditExhausted(lastError) : false;
	const suggested = creditExhausted ? await suggestSwitch(provider, modelId) : "";
	return { ok: false, error: lastError ?? "generation failed", creditExhausted, suggested };
}

interface GenerateOnceOpts {
	provider: string;
	modelId: string;
	key: string | null;
	prompt: string;
	size: string;
	n: number;
	seed?: number;
	signal?: AbortSignal;
	cwd: string;
}

/** One generation attempt with a single model. Returns saved images or error. */
async function generateOnce(opts: GenerateOnceOpts): Promise<GenResult> {
	const { provider, modelId } = opts;
	let data: { data?: Array<{ b64_json?: string; url?: string }> };
	try {
		const resp = await fetch(`${PROXY_BASE}/images/generations`, {
			method: "POST",
			headers: {
				"Content-Type": "application/json",
				...(opts.key ? { Authorization: `Bearer ${opts.key}` } : {}),
			},
			body: JSON.stringify({
				model: `${provider}@${modelId}`,
				prompt: opts.prompt,
				size: opts.size,
				n: opts.n,
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
			size: opts.size,
			seed: opts.seed,
			n: opts.n,
		});
		fs.writeFileSync(abs, writtenBuf);
		if (sidecar) fs.writeFileSync(`${abs}.txt`, sidecar);
		// b64 stays the ORIGINAL bytes (what the model sees / iterates on) — the
		// metadata only lands on disk, keeping the inline block byte-identical to
		// what the provider returned.
		saved.push({ b64, url: it.url, mime, path: abs, webUrl: webUrl ? `/uploads/${file}` : undefined });
	}
	if (!saved.length) return { ok: false, error: "generated images had no usable data" };
	return { ok: true, saved, provider, modelId, size: opts.size };
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
			'Model is any available "provider@modelid" from the proxy catalog, e.g. "pollinations@dreamshaper" (cheap, default) or "tu@z-image-turbo" (high quality). ' +
			"Images are saved to ~/.cache/generated/ (./uploads/ if present, or ./generated/ otherwise); the prompt is embedded in the file metadata.",
		promptSnippet: "Generate an image from a text prompt; model sees the result and can iterate",
		promptGuidelines: [
			"Use generate_image when the user asks to create, draw, or generate an image/picture/illustration/logo. " +
				"After generating, review the returned image and, if needed, call generate_image again with a refined prompt.",
		],
		parameters: Type.Object({
			prompt: Type.String({ description: "Text-to-image prompt. Be vivid: subject, style, composition, lighting, mood." }),
			model: Type.Optional(
				Type.String({
					description: `Any available "provider@modelid" image model from the proxy catalog (default: ${DEFAULT_MODEL}). Omit to auto-pick; discover options via the catalog.`,
				}),
			),
			size: Type.Optional(Type.String({ description: `Image size WxH (default: ${DEFAULT_SIZE}).` })),
			n: Type.Optional(Type.Number({ description: "Number of images 1–4 (default 1)." })),
			seed: Type.Optional(Type.Number({ description: "Optional reproducibility seed." })),
		}),

		async execute(_toolCallId, params, _signal, onUpdate, ctx) {
			const prompt = (params.prompt || "").trim();
			if (!prompt) {
				return { content: [{ type: "text" as const, text: "Error: prompt is required." }], isError: true, details: { error: "prompt required" } };
			}

			onUpdate?.({ content: [{ type: "text", text: "Generating…" }], details: undefined });
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
				const creditNote = res.creditExhausted
					? ` — ${res.suggested ? `model is out of credits; ${res.suggested}` : "model is out of credits; ask the user which model to switch to"}`
					: "";
				return { content: [{ type: "text" as const, text: `Error: ${res.error}${creditNote}` }], isError: true, details: { error: res.error } };
			}

			const { saved, provider, modelId, size, fellBack, fromModel } = res;
			const content: ContentBlock[] = [];
			const locationLines = saved.map((s) => `  • ${s.webUrl ?? s.path}`).join("\n");
			const fallbackNote = fellBack ? ` (auto-fell back from ${fromModel} — insufficient balance/error)` : "";
			content.push({
				type: "text",
				text: `Generated ${saved.length} image${saved.length > 1 ? "s" : ""} via ${provider}@${modelId} (${size})${fallbackNote}:\n${locationLines}`,
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
				details: {
					provider,
					model: modelId,
					size,
					paths: saved.map((s) => s.path),
					asciiPreview: !!asciiArt,
					...(fellBack ? { fellBack: true as const, fromModel } : {}),
				},
			};
		},

		renderResult(result, { isPartial }, theme) {
			if (isPartial) {
				return new Text(theme.fg("warning", "🖼 generating…"), 0, 0);
			}
			const details = (
				result as { details?: { provider?: string; model?: string; size?: string; paths?: string[]; fellBack?: boolean; fromModel?: string } }
			).details;
			if ((result as { isError?: boolean }).isError || !details) {
				const txt = result.content?.[0] && "text" in result.content[0] ? result.content[0].text : "error";
				return new Text(theme.fg("error", `✗ ${txt}`), 0, 0);
			}
			const count = details.paths?.length ?? 0;
			const where = details.paths?.[0] ?? "";
			const fb = details.fellBack ? ` (from ${details.fromModel})` : "";
			const label = `🖼 ${details.provider}@${details.model}${fb} • ${count} image${count > 1 ? "s" : ""} → ${where}`;
			return new Text(theme.fg("success", label), 0, 0);
		},
	});

	// --- 2. The COMMAND (direct, no LLM) — shared core + inline-rendered result ---

	/** Enumerate available image models across all providers (live catalog, no hardcoding). */
	async function allImageModels(): Promise<Array<{ provider: string; id: string }>> {
		// Prefer the cached authoritative per-provider list, then the live /models catalog.
		const cached = loadState().imageModels;
		if (cached && Date.now() - cached.at < MODEL_CACHE_TTL_MS) {
			return cached.models.map((m) => {
				const i = m.indexOf("@");
				return { provider: m.slice(0, i), id: m.slice(i + 1) };
			});
		}
		try {
			const resp = await fetch(`${PROXY_BASE}/models`);
			if (resp.ok) {
				const body = (await resp.json()) as { data?: Array<{ id?: string; type?: string; modalities?: { output?: string[] } }> };
				const out: Array<{ provider: string; id: string }> = [];
				for (const m of body.data ?? []) {
					if (!m.id) continue;
					if (m.type === "image" || (m.modalities?.output ?? []).includes("image")) {
						const i = m.id.indexOf("@");
						if (i === -1) continue;
						out.push({ provider: m.id.slice(0, i), id: m.id.slice(i + 1) });
					}
				}
				if (out.length) return out;
			}
		} catch {
			/* empty */
		}
		return [];
	}

	/** Render the /imagegen usage panel inline (no-args / "help"). */
	function showHelp(ctx: ExtensionContext): void {
		const s = getSettings();
		const effective = s.model || (lastGoodModel(DEFAULT_MODEL.split("@")[0]) ? `${DEFAULT_MODEL.split("@")[0]}@${lastGoodModel(DEFAULT_MODEL.split("@")[0])}` : DEFAULT_MODEL);
		const lines = [
			"🖼 imagegen — generate an image directly (no LLM round-trip)",
			"",
			"Usage:",
			"  /imagegen <prompt> [--model M] [--size WxH] [--n N] [--seed S]",
			"  /img <prompt> …                       (alias)",
			"",
			"Flags:",
			"  --model / -m  provider@modelid   (default below)",
			"  --size  / -s  WxH               (default " + (s.size ?? DEFAULT_SIZE) + ")",
			"  --n     / -n  1–4               (default " + (s.n ?? 1) + ")",
			"  --seed       number             reproducible seed",
			"",
			"Settings:",
			"  /imagegen settings   pick default model/size/count from the live catalog",
			"  /imagegen help       show this panel",
			"",
			"Current default model: " + effective,
			"  (set via settings menu, or auto-healed to the last working model)",
		].join("\n");
		writeEntry(ctx, IMAGEGEN_HELP_MSG, [{ type: "text", text: lines }] as any, true, { lines });
	}

	/** Interactive settings menu: pick default model/size/count from the live list. */
	async function runSettingsMenu(ctx: ExtensionContext): Promise<void> {
		if (!ctx.hasUI) {
			ctx.ui.notify("imagegen: settings menu needs an interactive session", "warning");
			return;
		}
		let settings = getSettings();
		const defaultProvider = DEFAULT_MODEL.split("@")[0];
		const lastGood = lastGoodModel(defaultProvider);

		/** Search-driven model picker: type a term, then pick from a short capped list. */
		const pickModel = async (): Promise<string | undefined> => {
			const models = await allImageModels();
			if (!models.length) {
				ctx.ui.notify("imagegen: no image models available from the catalog", "error");
				return undefined;
			}
			// Loop until the filtered list is short enough to present (≤10), or cancelled.
			let term = "";
			let matched = models;
			for (;;) {
				if (term) matched = models.filter((m) => `${m.provider}@${m.id}`.toLowerCase().includes(term));
				if (matched.length === 0) {
					ctx.ui.notify(`imagegen: no models match “${term}”`, "warning");
					return undefined;
				}
				if (matched.length <= 10) break;
				const next = (await ctx.ui.input(
					`imagegen — ${matched.length} models match; type a narrower filter (provider or name)`,
					term,
				))?.trim().toLowerCase();
				if (next === undefined) return undefined; // cancelled
				term = next;
			}
			const options = ["auto (last-good / default)", ...matched.map((m) => `${m.provider}@${m.id}`)];
			const picked = await ctx.ui.select("imagegen — pick a model:", options);
			if (picked === undefined) return undefined;
			return picked === "auto (last-good / default)" ? undefined : picked;
		};

		for (;;) {
			const modelLabel = settings.model ?? (lastGood ? `auto (${defaultProvider}@${lastGood})` : `auto (${DEFAULT_MODEL})`);
			const action = await ctx.ui.select(
				"imagegen settings — what to change?",
				[
					`Default model: ${modelLabel}`,
					`Default size: ${settings.size ?? DEFAULT_SIZE}`,
					`Default count (n): ${settings.n ?? 1}`,
					"Reset to auto (clear settings)",
					"Done",
				],
			);
			if (!action) break;
			// select returns the chosen string (or undefined on cancel); map label→action
			let chosen: string | undefined;
			if (action.startsWith("Default model:")) chosen = "model";
			else if (action.startsWith("Default size:")) chosen = "size";
			else if (action.startsWith("Default count")) chosen = "n";
			else if (action === "Reset to auto (clear settings)") chosen = "clear";
			else if (action === "Done") break;
			if (!chosen) break;

			if (chosen === "model") {
				const pickedModel = await pickModel();
				if (pickedModel === undefined) continue;
				settings = { ...settings, model: pickedModel };
				saveSettings(settings);
				ctx.ui.notify(`imagegen: default model → ${pickedModel || "auto"}`, "info");
			} else if (chosen === "size") {
				const picked = await ctx.ui.select("imagegen — default size:", ["auto (512x512)", "256x256", "512x512", "768x768", "1024x1024", "custom…"]);
				let size: string | undefined;
				if (picked === "custom…") size = (await ctx.ui.input("imagegen — size (WxH):", "512x512")) || undefined;
				else if (picked && picked !== "auto (512x512)") size = picked;
				if (picked !== undefined) {
					settings = { ...settings, size };
					saveSettings(settings);
					ctx.ui.notify(`imagegen: default size → ${size ?? "auto"}`, "info");
				}
			} else if (chosen === "n") {
				const picked = await ctx.ui.select("imagegen — default count (n):", ["1", "2", "3", "4"]);
				if (picked !== undefined) {
					settings = { ...settings, n: Number(picked) };
					saveSettings(settings);
					ctx.ui.notify(`imagegen: default count → ${picked}`, "info");
				}
			} else if (chosen === "clear") {
				settings = {};
				saveSettings(settings);
				ctx.ui.notify("imagegen: settings cleared — back to auto", "info");
			}
		}
	}

	async function runImagegenCommand(args: string, ctx: ExtensionContext): Promise<void> {
		const raw = (args ?? "").trim();
		if (!raw || /^(help|-h|--help)$/i.test(raw)) {
			showHelp(ctx);
			return;
		}
		if (/^settings$/i.test(raw)) {
			await runSettingsMenu(ctx);
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
			// Out of credits → ask the user to switch to another model.
			if (res.creditExhausted) {
				const provider = (model || DEFAULT_MODEL).split("@")[0];
				const models = await imageModelsForProvider(provider).catch(() => []);
				const current = (model || DEFAULT_MODEL).split("@")[1];
				const options = models.filter((m) => m !== current);
				if (options.length && ctx.hasUI) {
					const picked = await ctx.ui.select(
						`imagegen: ${res.error} — pick another model`,
						options.map((m) => `${provider}@${m}`),
					);
					if (picked) {
						ctx.ui.notify(`imagegen: retrying with ${picked} …`, "info");
						const retry = await generateAndSave({ prompt, model: picked, size, n, seed, cwd: ctx.cwd, signal: ctx.signal });
						if (retry.ok) {
							const { saved, provider: p, modelId: m2, size: sz2 } = retry;
							const lines = saved.map((s) => `  • ${s.webUrl ?? s.path}`).join("\n");
							writeEntry(ctx, IMAGEGEN_MSG, [
								{ type: "text", text: `Generated ${saved.length} image${saved.length > 1 ? "s" : ""} via ${p}@${m2} (${sz2}):\n${lines}` },
								...saved.map((s): ImageBlock => ({ type: "image", data: s.b64, mimeType: s.mime })),
							] as any, true, {
								provider: p, model: m2, size: sz2, paths: saved.map((s) => s.path),
								images: saved.map((s) => ({ b64: s.b64, mime: s.mime })),
							});
							ctx.ui.notify(`imagegen: ${saved.length} image${saved.length > 1 ? "s" : ""} → ${saved[0].path}`, "info");
							return;
						}
					}
				} else if (res.suggested) {
					ctx.ui.notify(`imagegen: ${res.error} — ${res.suggested}`, "error");
					return;
				}
			}
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
		writeEntry(ctx, IMAGEGEN_MSG, content as any, true, {
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
		description: "/imagegen <prompt> [--model M] [--size WxH] [--n N] [--seed S] — generate an image directly (no LLM round-trip). /imagegen settings opens the model/size menu. Alias: /img",
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

	// --- 2b. Inline renderer for the /imagegen help panel ---
	pi.registerMessageRenderer(
		IMAGEGEN_HELP_MSG,
		(message, _opts, theme): Component | undefined => {
			const lines = ((message as { details?: { lines?: string } }).details?.lines ?? "").split("\n");
			const c = new Container();
			for (const ln of lines) {
				if (!ln) {
					c.addChild(new Spacer(1));
				} else if (ln.startsWith("🖼")) {
					c.addChild(new Text(theme.fg("accent", ln), 0, 0));
				} else if ( // biome-ignore lint/complexity/noAdjacentSpacesInRegex: leading 2-space indent is meaningful
					/^  \/|^  --|^  -m|^  -s|^  -n|^  --seed/.test(ln)
				) {
					c.addChild(new Text(theme.fg("muted", ln), 0, 0));
				} else if (/^Current|^Settings|^Usage|^Flags/.test(ln)) {
					c.addChild(new Text(theme.fg("success", ln), 0, 0));
				} else {
					c.addChild(new Text(theme.fg("dim", ln), 0, 0));
				}
			}
			return c;
		},
	);

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
