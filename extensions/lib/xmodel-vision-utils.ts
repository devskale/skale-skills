/**
 * xmodel-vision-utils — pure, stateless helpers for the xmodel vision pipeline.
 *
 * Extracted from xmodel.ts. These touch no extension state (no visionCfg, no
 * ctx.ui) — they only transform data (image bytes, text, child-pi execution)
 * and write forensic/debug logs. The stateful vision functions (delegateVision,
 * humanVision, viewOnly, analyzeImageFile, resolveVlm, buildBrief,
 * gatherRecentContext) stay in xmodel.ts.
 */

import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { spawn } from "node:child_process";
import { isValidImage } from "./image-utils";

/** Default timeout for a child-pi VLM sub-call. */
export const VLM_TIMEOUT_MS = 90_000;

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

/**
 * Run a child `pi --mode json -p` sub-process and stream back its assistant text.
 * Used for the VLM sub-call (and the compressor). JSONL-parses stdout for
 * text_delta / message_end, so it never parses the giant agent_end that embeds
 * an image. Same recipe as the official pi-subagents package.
 */
export function runChildPi(opts: { model: string; systemPrompt: string; prompt: string; imageFile?: string; timeoutMs?: number }): Promise<string> {
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
		if (opts.imageFile) args.push(`@${opts.imageFile}`);
		args.push(opts.prompt);
		const timeoutMs = opts.timeoutMs ?? VLM_TIMEOUT_MS;
		debug("runChildPi", { model: opts.model, hasImage: !!opts.imageFile, promptLen: opts.prompt.length, timeoutMs });
		const proc = spawn("pi", args, { stdio: ["ignore", "pipe", "pipe"], env: { ...process.env, NO_COLOR: "1" } });
		let deltaText = "";          // accumulated assistant text deltas (small, no image)
		let lastMsgEndText = "";      // last assistant message_end text (small, no image)
		let lineBuf = "";
		let outLen = 0;
		const t0 = Date.now();
		const timer = setTimeout(() => proc.kill("SIGTERM"), timeoutMs);
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
			onLine(lineBuf); // flush trailing partial line
			const elapsed = ((Date.now() - t0) / 1000).toFixed(1);
			const text = (deltaText.trim() || lastMsgEndText.trim());
			debug("runChildPi done", { model: opts.model, reason, outLen, elapsed, textLen: text.length, via: deltaText.trim() ? "delta" : lastMsgEndText.trim() ? "msgEnd" : "none" });
			forensic("runChildPi done", { model: opts.model, reason, outLen, elapsedSec: elapsed, textLen: text.length, via: deltaText.trim() ? "delta" : lastMsgEndText.trim() ? "msgEnd" : "none", imageFile: opts.imageFile });
			if (!text) forensic("runChildPi empty", { model: opts.model, reason, outLen, elapsedSec: elapsed, imageFile: opts.imageFile });
			resolve(text);
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

/** Write an image block (base64) to a temp file for VLM delegation. Returns the path + validity. */
export function writeImageTmp(img: any): { path: string; valid: boolean; bytes: number } {
	const mt = (img.mimeType || "image/png") as string;
	const rawData: string = typeof img.data === "string" ? img.data : "";
	forensic("writeImageTmp in", { mimeType: mt, dataLen: rawData.length, dataHead: rawData.slice(0, 40), hasData: !!img.data });
	const sub = (mt.split("/")[1] || "png").toLowerCase();
	const ext = /^(png|jpe?g|gif|webp|bmp|tiff?)$/.test(sub) ? sub.replace("jpeg", "jpg") : "png";
	const p = join("/tmp", `xmodel-vision-${Date.now()}-${Math.random().toString(36).slice(2, 8)}.${ext}`);
	let buf: Buffer;
	try {
		buf = rawData.startsWith("data:") ? Buffer.from(rawData.split(",")[1] ?? "", "base64") : Buffer.from(rawData, "base64");
	} catch {
		buf = Buffer.alloc(0);
	}
	writeFileSync(p, buf);
	const valid = isValidImage(buf);
	forensic("writeImageTmp out", { path: p, fileBytes: buf.length, valid, magic: buf.slice(0, 8).toString("hex") });
	return { path: p, valid, bytes: buf.length };
}
