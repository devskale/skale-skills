/**
 * xmodel-vision-utils — pure, stateless helpers for the xmodel vision pipeline.
 *
 * Extracted from xmodel.ts. These touch no extension state (no visionCfg, no
 * ctx.ui) — they only transform data (image bytes, text, child-pi execution)
 * and write forensic/debug logs. The stateful vision functions (delegateVision,
 * humanVision, viewOnly, analyzeImageFile, resolveVlm, buildBrief,
 * gatherRecentContext) stay in xmodel.ts.
 */

import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { tmpdir, homedir } from "node:os";
import { spawn } from "node:child_process";
import { isValidImage } from "./image-utils";
import { normalizeImageForVlm, type NormalizeResult, TILE_PROGRESSION_INSTRUCTION } from "./image-normalize";

/** Parse a positive int from an env var; undefined when unset/invalid (→ library default). */
export function envInt(v: string | undefined): number | undefined {
	const n = Number(v);
	return v !== undefined && v !== "" && Number.isFinite(n) && n >= 0 ? n : undefined;
}

/** Default timeout for a child-pi VLM sub-call.
 * Overridable via XMODEL_VLM_TIMEOUT_MS (ms) — e.g. for slow cloud VLMs or tests. */
export const VLM_TIMEOUT_MS =
	Number(process.env.XMODEL_VLM_TIMEOUT_MS) > 0 ? Number(process.env.XMODEL_VLM_TIMEOUT_MS) : 90_000;

/** Forensic log — ALWAYS on (image-data debugging for MCP path). */
export function forensic(tag: string, data: Record<string, unknown>): void {
	try {
		const fs2 = require("node:fs");
		fs2.appendFileSync("/tmp/xmodel-forensic.log", `${new Date().toISOString()} [${tag}] ${JSON.stringify(data)}\n`);
	} catch {}
}

/** Forensic log — append-only, off by default (set XMODEL_DEBUG=1). */
export function debug(tag: string, data: Record<string, unknown>): void {
	if (process.env.XMODEL_DEBUG !== "1") return;
	try {
		const line = `${new Date().toISOString()} [${tag}] ${JSON.stringify(data)}\n`;
		const fs = require("node:fs");
		fs.appendFileSync("/tmp/xmodel-debug.log", line);
	} catch {}
}

/** Result of a child-pi sub-call. `text` is the assistant output (may be empty).
 *  `timedOut` is true when the hard timeout fired; `aborted` is true when the
 *  caller's AbortSignal fired (user pressed Esc) and the child was killed early. */
export interface ChildPiResult {
	text: string;
	timedOut: boolean;
	aborted: boolean;
	reason: string;
}

/**
 * Run a child `pi --mode json -p` sub-process and stream back its assistant text.
 * Used for the VLM sub-call (and the compressor). JSONL-parses stdout for
 * text_delta / message_end, so it never parses the giant agent_end that embeds
 * an image. Same recipe as the official pi-subagents package.
 *
 * Pass `opts.signal` to wire the caller's abort signal (e.g. `ctx.signal`, which
 * fires when the user presses Esc) so the child is killed promptly instead of
 * hanging until the timeout — otherwise Esc appears to "not work" while xm is
 * running a vision sub-call.
 */
export function runChildPi(opts: {
	model: string;
	systemPrompt: string;
	prompt: string;
	/** One or more image files attached to the child call (multi-image verified 2026-10-11). */
	imageFile?: string | string[];
	timeoutMs?: number;
	signal?: AbortSignal;
	thinkingLevel?: string;
}): Promise<ChildPiResult> {
	return new Promise((resolve) => {
		// --mode json -p (NOT bare --print): text mode tries TUI init that hangs on piped stdout.
		// This is the same recipe the official pi-subagents package uses.
		const args = [
			"--mode", "json", "-p",
			"--no-tools", "--no-extensions", "--no-context-files",
			"--no-skills", "--no-prompt-templates", "--no-themes",
			"--model", opts.model,
			"--system-prompt", opts.systemPrompt,
		];
		if (opts.thinkingLevel) args.push("--thinking", opts.thinkingLevel);
		// Multiple @files are attached in order; the child sees them as image 1..N.
		for (const f of typeof opts.imageFile === "string" ? [opts.imageFile] : (opts.imageFile ?? [])) {
			args.push(`@${f}`);
		}
		args.push(opts.prompt);
		const timeoutMs = opts.timeoutMs ?? VLM_TIMEOUT_MS;
		debug("runChildPi", { model: opts.model, hasImage: !!opts.imageFile, promptLen: opts.prompt.length, timeoutMs });
		// The child must SEE the image even when the user blocks image pixels globally
		// (settings.json → images.blockImages). The child inherits that setting and then
		// answers "NO IMAGE" (observed 2026-10-01: outLen 1.4 MB, textLen 8 — literally
		// "NO IMAGE"), which our NO-IMAGE filter turns into "no usable analysis".
		// Fix: a fully ISOLATED agent dir via PI_CODING_AGENT_DIR — settings.json with
		// blockImages off, plus copies of models.json (custom models like zai/* live
		// there) and auth.json (provider keys). Deterministic: pi 1.0's project-scope
		// settings merge is correct in isolation but does not reach the -p runtime
		// (verified 2026-10-01 — the child still blocked images), so we don't rely on
		// project scope at all. The temp dir is removed in finish(); the user's real
		// config is never touched.
		let agentDirOverride: string | undefined;
		if (opts.imageFile) {
			try {
				agentDirOverride = mkdtempSync(join(tmpdir(), "xmodel-vlm-"));
				writeFileSync(join(agentDirOverride, "settings.json"), JSON.stringify({ images: { blockImages: false } }));
				for (const f of ["models.json", "auth.json"]) {
					const src = join(homedir(), ".pi", "agent", f);
					if (existsSync(src)) writeFileSync(join(agentDirOverride, f), readFileSync(src));
				}
			} catch {
				agentDirOverride = undefined;
			}
		}
		const childEnv: Record<string, string> = { ...process.env, NO_COLOR: "1" };
		if (agentDirOverride) childEnv.PI_CODING_AGENT_DIR = agentDirOverride;
		const proc = spawn("pi", args, { stdio: ["ignore", "pipe", "pipe"], env: childEnv });
		let deltaText = "";          // accumulated assistant text deltas (small, no image)
		let lastMsgEndText = "";      // last assistant message_end text (small, no image)
		let lineBuf = "";
		let outLen = 0;
		const t0 = Date.now();
		let timedOut = false;
		let aborted = false;
		const onAbort = () => { aborted = true; proc.kill("SIGTERM"); };
		const timer = setTimeout(() => { timedOut = true; proc.kill("SIGTERM"); }, timeoutMs);
		if (opts.signal) {
			if (opts.signal.aborted) onAbort();
			else opts.signal.addEventListener("abort", onAbort, { once: true });
		}
		const onLine = (line: string) => {
			line = line.trim();
			if (!line) return;
			try {
				const j = JSON.parse(line);
				// stream assistant text deltas (avoids parsing the giant agent_end that embeds the image)
				if (j.type === "message_update" && j.assistantMessageEvent?.type === "text_delta") {
					deltaText += j.assistantMessageEvent.delta || "";
				} else if (j.type === "message_end" && j.message?.role === "assistant") {
					const c = j.message.content;
					lastMsgEndText = typeof c === "string" ? c : Array.isArray(c) ? c.filter((b: any) => b && b.type === "text").map((b: any) => b.text || "").join(" ") : "";
				}
			} catch {}
		};
		proc.stdout.on("data", (d: Buffer) => {
			const s = d.toString(); outLen += s.length;
			if (outLen > 16 << 20) { proc.kill(); return; } // cap memory
			lineBuf += s;
			let nl: number;
			while ((nl = lineBuf.indexOf("\n")) >= 0) {
				onLine(lineBuf.slice(0, nl));
				lineBuf = lineBuf.slice(nl + 1);
			}
		});
		const finish = (reason: string) => {
			clearTimeout(timer);
			if (opts.signal) opts.signal.removeEventListener("abort", onAbort);
			onLine(lineBuf); // flush trailing partial line
			const elapsed = ((Date.now() - t0) / 1000).toFixed(1);
			const text = (deltaText.trim() || lastMsgEndText.trim());
			debug("runChildPi done", { model: opts.model, reason, timedOut, aborted, outLen, elapsed, textLen: text.length, via: deltaText.trim() ? "delta" : lastMsgEndText.trim() ? "msgEnd" : "none" });
			forensic("runChildPi done", { model: opts.model, reason, timedOut, aborted, outLen, elapsedSec: elapsed, textLen: text.length, via: deltaText.trim() ? "delta" : lastMsgEndText.trim() ? "msgEnd" : "none", imageFile: opts.imageFile });
			if (!text) forensic("runChildPi empty", { model: opts.model, reason, timedOut, aborted, outLen, elapsedSec: elapsed, imageFile: opts.imageFile });
			if (agentDirOverride) {
				try { rmSync(agentDirOverride, { recursive: true, force: true }); } catch {}
			}
			resolve({ text, timedOut, aborted, reason: timedOut ? "timeout" : aborted ? "abort" : reason });
		};
		proc.on("close", () => finish("close"));
		proc.on("error", () => finish("error"));
	});
}

/** Extract text content from a tool-result block (string or array of text parts). */
export function textOf(content: unknown): string {
	if (typeof content === "string") return content;
	if (Array.isArray(content)) {
		return content.filter((b: any) => b && b.type === "text").map((b: any) => b.text || "").join(" ");
	}
	return "";
}

/** Detect a screenshot/image saved to disk in a tool_result's text (e.g. chrome_devtools "Saved screenshot to /tmp/x.png"). */
export function detectSavedScreenshot(content: unknown): string | undefined {
	const text = Array.isArray(content) ? content.filter((b: any) => b && b.type === "text").map((b: any) => b.text || "").join("\n") : "";
	const m = text.match(/saved (?:screenshot|image|snapshot|capture)[^\n]*?\s(\/\S+\.(?:png|jpe?g|webp|gif|bmp))/i);
	return m ? m[1] : undefined;
}

/** Read an image file from disk into a synthetic image block (base64 + mimeType) for delegation. */
export function readImageFileBlock(filePath: string): any | undefined {
	try {
		if (!existsSync(filePath)) return undefined;
		const buf = readFileSync(filePath);
		if (!isValidImage(buf)) return undefined;
		const ext = filePath.toLowerCase().split(".").pop() ?? "png";
		const mimeType = ext === "jpg" || ext === "jpeg" ? "image/jpeg" : ext === "webp" ? "image/webp" : ext === "gif" ? "image/gif" : ext === "bmp" ? "image/bmp" : "image/png";
		return { type: "image", data: buf.toString("base64"), mimeType, _bytes: buf.length };
	} catch {
		return undefined;
	}
}

/** Write an image block (base64) to a temp file for VLM delegation. Returns the path + validity.
 *
 * Normalisation (portable, photon-WASM): images above the ceilings are aspect-
 * preserving downscaled and re-encoded as JPEG before they hit the child-pi VLM.
 * Every provider downscales server-side anyway (Claude 1568px, GPT-4o tiles,
 * Qwen3-VL max_pixels) — sending the full-res original only pays base64 payload
 * and latency. 2026-10-09 incident: the 434 KB full-page screenshot produced a
 * 3.4 MB child output stream. JPEG q80 keeps dense text MORE readable than a
 * same-size PNG (verified against the DGX VLM: job names survived at q80, were
 * lost at PNG-1568) at ~40% of the bytes. Failure degrades to the original. */
export function writeImageTmp(img: any): { path: string; valid: boolean; bytes: number } {
	const mt = (img.mimeType || "image/png") as string;
	const rawData: string = typeof img.data === "string" ? img.data : "";
	forensic("writeImageTmp in", { mimeType: mt, dataLen: rawData.length, dataHead: rawData.slice(0, 40), hasData: !!img.data });
	const sub = (mt.split("/")[1] || "png").toLowerCase();
	let ext = /^(png|jpe?g|gif|webp|bmp|tiff?)$/.test(sub) ? sub.replace("jpeg", "jpg") : "png";
	let buf: Buffer;
	try {
		buf = rawData.startsWith("data:") ? Buffer.from(rawData.split(",")[1] ?? "", "base64") : Buffer.from(rawData, "base64");
	} catch {
		buf = Buffer.alloc(0);
	}
	// Normalise for the VLM path. Opt-outs: XMODEL_VISION_NORMALIZE=0 disables;
	// XMODEL_VISION_MAX_EDGE / XMODEL_VISION_MAX_PIXELS override the ceilings;
	// XMODEL_VISION_JPEG=0 keeps PNG (pixel-exact tasks) instead of JPEG q80.
	let norm: NormalizeResult | null = null;
	if (process.env.XMODEL_VISION_NORMALIZE !== "0") {
		norm = normalizeImageForVlm(buf, mt, {
			maxEdge: envInt(process.env.XMODEL_VISION_MAX_EDGE),
			maxPixels: envInt(process.env.XMODEL_VISION_MAX_PIXELS),
			jpegQuality: process.env.XMODEL_VISION_JPEG === "0" ? 0 : 80,
		});
		if (norm) {
			buf = norm.data;
			ext = norm.mimeType === "image/jpeg" ? "jpg" : "png";
			forensic("writeImageTmp normalized", {
				from: { w: norm.originalWidth, h: norm.originalHeight },
				to: { w: norm.width, h: norm.height },
				mime: norm.mimeType,
			});
		}
	}
	const p = join("/tmp", `xmodel-vision-${Date.now()}-${Math.random().toString(36).slice(2, 8)}.${ext}`);
	writeFileSync(p, buf);
	const valid = isValidImage(buf);
	forensic("writeImageTmp out", { path: p, fileBytes: buf.length, valid, magic: buf.slice(0, 8).toString("hex") });
	return { path: p, valid, bytes: buf.length };
}

// ── Progressive tiled vision (ultra-long pages) ───────────────────────────────
//
// A full-page capture of a long article/site downscaled into a 2MP budget becomes
// an unreadable strip (1440x12000 -> 188x1568, verified 2026-10-11). Tiling keeps
// every segment readable — but sending ALL segments costs N x tokens even when
// the answer sits in segment 1. Progression: send segment 1, continue only while
// the VLM says "NEED MORE" (it must name what is missing). One call for the common
// case, N calls only when the page really needs them.

/** Segments per FOLLOW-UP call — beyond this the context/token cost dominates.
 * The FIRST call always carries a single segment (maximal progression: if tile 1
 * answers, the rest of the page is never sent). */
export const DEFAULT_MAX_TILES_PER_CALL = 4;

export interface TiledAnalysis {
	/** Concatenated analyses, one entry per consumed segment. */
	text: string;
	/** How many segments were sent. */
	segmentsUsed: number;
	/** Total segments the plan produced. */
	segmentsTotal: number;
	/** True when the VLM asked for more but the caller stopped (budget/limit). */
	truncated: boolean;
	timedOut: boolean;
}

export interface TiledRunOptions {
	model: string;
	systemPrompt: string;
	/** Task prompt WITHOUT the tile instruction (appended automatically). */
	prompt: string;
	plan: import("./image-normalize").TilePlan;
	signal?: AbortSignal;
	thinkingLevel?: string;
	/** Segments per call (default 4). */
	tilesPerCall?: number;
	/** Hard cap on segments overall (default 12). */
	maxSegments?: number;
	/** Injectable for tests; defaults to the real runChildPi. */
	runChild?: typeof runChildPi;
}

/** True when the VLM's answer asks for the next segment. */
export function wantsMoreSegments(text: string): boolean {
	return /^\s*NEED MORE\b/i.test(text.trim());
}

/**
 * Drive the progressive tiled analysis. Returns the merged analysis text plus
 * bookkeeping. Never throws — a failure in one batch degrades to what we have.
 */
export async function analyzeTiledImage(opts: TiledRunOptions): Promise<TiledAnalysis> {
	const run = opts.runChild ?? runChildPi;
	const perCall = Math.max(1, opts.tilesPerCall ?? DEFAULT_MAX_TILES_PER_CALL);
	const maxSegments = Math.max(1, opts.maxSegments ?? 12);
	const tiles = opts.plan.tiles;
	const out: TiledAnalysis = {
		text: "",
		segmentsUsed: 0,
		segmentsTotal: tiles.length,
		truncated: false,
		timedOut: false,
	};
	if (!tiles.length) return out;

	// Write the tiles we may need to temp files lazily (a batch at a time).
	const dir = mkdtempSync(join(tmpdir(), "xmodel-tiles-"));
	const paths: string[] = [];
	try {
		for (const t of tiles.slice(0, maxSegments)) {
			const p = join(dir, `tile-${String(t.index).padStart(3, "0")}.png`);
			writeFileSync(p, t.data);
			paths.push(p);
		}
		let i = 0;
		while (i < paths.length) {
			// First call = exactly ONE segment (the user's rule: if tile 1 already
			// carries the answer, nothing else is sent). Later calls batch up.
			const size = i === 0 ? 1 : perCall;
			const batch = paths.slice(i, i + size);
			const first = tiles[i];
			const last = tiles[Math.min(i + size, tiles.length) - 1];
			const res = await run({
				model: opts.model,
				systemPrompt: opts.systemPrompt,
				prompt:
					`${opts.prompt}\n\n${TILE_PROGRESSION_INSTRUCTION}\n` +
					`(This call shows image ${first.index} of ${tiles.length}; segments ${first.index}–${last.index} of the page, top to bottom.)`,
				imageFile: batch,
				signal: opts.signal,
				thinkingLevel: opts.thinkingLevel,
			});
			out.segmentsUsed += batch.length;
			if (res.timedOut) {
				out.timedOut = true;
				if (out.text) break;
				// first batch timed out → nothing to build on
				out.text = "";
				break;
			}
			if (res.text) {
				const cleaned = res.text.trim();
				if (wantsMoreSegments(cleaned)) {
					// Keep the model's own note about what is missing — it is the
					// signal for the next batch and useful in the final analysis.
					out.text += (out.text ? "\n\n" : "") + `[segment ${first.index}–${last.index}: ${cleaned}]`;
					i += size;
					if (i >= paths.length) {
						out.truncated = true; // asked for more, but the page ended
					}
					continue;
				}
				out.text += (out.text ? "\n\n" : "") + cleaned;
				break; // answered — stop, no further segments
			}
			// Empty answer (NO IMAGE / unusable) → try the next batch once.
			i += size;
		}
		if (!out.text && !out.timedOut) out.truncated = true;
		return out;
	} catch {
		out.truncated = true;
		return out;
	} finally {
		try {
			rmSync(dir, { recursive: true, force: true });
		} catch {}
	}
}
