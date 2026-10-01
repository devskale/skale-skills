/**
 * image-utils — shared image-type predicates for pi extensions.
 *
 * Extracted from xmodel (isValidImage, isVisionCapable) and imagegen
 * (guessMime, isVisionCapable). These identify image type by magic bytes or
 * base64 prefix, and whether a model can see images. Shared so both
 * extensions agree on one implementation instead of each carrying a copy.
 *
 * Not here: imagegen's prompt-metadata embedding (embedMetadata/pngCrc32) and
 * xmodel's VLM-delegation helpers (readImageFileBlock/writeImageTmp) — those
 * are extension-specific.
 */

import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

/** True if a model accepts image input (vision-capable). */
export function isVisionCapable(model: unknown): boolean {
	return !!model && Array.isArray((model as any).input) && (model as any).input.includes("image");
}

/** Guess the MIME type of a base64-encoded image from its leading bytes. */
export function guessMime(b64: string): string {
	if (b64.startsWith("/9j/")) return "image/jpeg";
	if (b64.startsWith("UklGR")) return "image/webp";
	if (b64.startsWith("R0lGOD")) return "image/gif";
	// PNG base64 starts with iVBOR
	return "image/png";
}

/** Validate an image buffer by magic bytes (PNG/JPEG/GIF/BMP/WebP). */
export function isValidImage(buf: Buffer): boolean {
	if (buf.length < 32) return false;
	const h = buf;
	return (
		(h[0] === 0x89 && h[1] === 0x50 && h[2] === 0x4e && h[3] === 0x47) || // PNG
		(h[0] === 0xff && h[1] === 0xd8 && h[2] === 0xff) || // JPEG
		(h[0] === 0x47 && h[1] === 0x49 && h[2] === 0x46) || // GIF
		(h[0] === 0x42 && h[1] === 0x4d) || // BMP
		(h[0] === 0x52 && h[1] === 0x49 && h[2] === 0x46 && h[3] === 0x46 && h[8] === 0x57 && h[9] === 0x45 && h[10] === 0x42 && h[11] === 0x50) // WebP
	);
}

/** True when the decoded bytes already carry the PNG signature. */
export function isPng(buf: Buffer): boolean {
	return buf.length >= 8 && buf[0] === 0x89 && buf[1] === 0x50 && buf[2] === 0x4e && buf[3] === 0x47;
}

/**
 * Normalise a base64 image to PNG for terminal display.
 *
 * WHY THIS EXISTS: pi-tui's Kitty encoder (`encodeKitty`) hardcodes the control
 * key `f=100`, which means PNG. It ignores `mimeType` — that is only consulted
 * for dimension probing. So a .webp/.jpg/.gif/.bmp gets its raw bytes sent with
 * a "this is a PNG" label. Ghostty parses the PNG signature, finds RIFF/WEBP,
 * and drops the image *silently*: the TUI writes a valid-looking Kitty APC, but
 * nothing appears. Verified 2026-10-01 on Ghostty → herdr → pi (webp+jpeg with
 * f=100/f=101 both invisible; PNG with f=100 renders).
 *
 * Non-PNG therefore has to be transcoded, not just relabelled — the host
 * terminal's Kitty path only accepts PNG payloads.
 *
 * Returns the (possibly re-encoded) base64 PNG. On any failure the input is
 * returned unchanged, so a converter that is missing or refuses a format
 * degrades to the previous behaviour instead of dropping the image.
 */
export function toDisplayPng(b64: string): string {
	// Already PNG (the overwhelmingly common case): one decode, no work, no shell.
	try {
		const head = Buffer.from(b64.slice(0, 16), "base64");
		if (isPng(head) || (head.length < 8 && guessMime(b64) === "image/png")) return b64;
	} catch {
		return b64;
	}

	// Non-PNG: transcode via sips (ships with macOS — no extra dependency).
	let dir: string | undefined;
	try {
		const raw = b64.startsWith("data:") ? (b64.split(",")[1] ?? "") : b64;
		const buf = Buffer.from(raw, "base64");
		if (!isValidImage(buf)) return b64;
		dir = mkdtempSync(join(tmpdir(), "img2png-"));
		// sips picks the decoder from the extension, so name the input by its real format.
		const inPath = join(dir, `in.${(guessMime(b64).split("/")[1] || "png").replace("jpeg", "jpg")}`);
		const outPath = join(dir, "out.png");
		writeFileSync(inPath, buf);
		execFileSync("sips", ["-s", "format", "png", inPath, "--out", outPath], {
			stdio: ["ignore", "ignore", "ignore"],
			timeout: 10000,
		});
		const png = readFileSync(outPath);
		return isPng(png) ? png.toString("base64") : b64;
	} catch {
		return b64;
	} finally {
		if (dir) {
			try {
				rmSync(dir, { recursive: true, force: true });
			} catch {
				/* best effort */
			}
		}
	}
}
