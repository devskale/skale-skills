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

import { normalizeImageForDisplay } from "./image-normalize";

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
 * Normalise a base64 image to PNG (+ 1200px long-edge cap) for terminal display.
 *
 * WHY THIS STILL EXISTS (updated 2026-10-17): the original bug — pi-tui's
 * Kitty encoder hardcoding f=100 (PNG) so non-PNG payloads were dropped
 * silently by the terminal (verified 2026-10-01 on Ghostty) — is FIXED
 * upstream since pi 1.0.1 (earendil-works/pi#10292): pi-tui's Image now
 * converts through a registered photon transcoder at render time.
 *
 * But pi's transcoder only CONVERTS — it never resizes (pi 1.3.0,
 * image-convert.js encodePng: decode → EXIF-orient → re-encode, dimensions
 * unchanged). A full-res photo (2880px, 2–3 MB) would cross the Kitty APC for
 * ~100 cells of screen. This caps the long edge at 1200px (~5× smaller
 * payload, still crisp on retina) and runs once per image per session (the
 * Image component caches its rendered lines).
 *
 * PNG passes through byte-identical. On any failure the input is returned
 * unchanged — pi's render-time transcoder then gets a second shot, so the
 * worst case is a full-res image, never a vanished one.
 */
export function toDisplayPng(b64: string): string {
	// Already PNG (the overwhelmingly common case): one decode, no work, no shell.
	try {
		const head = Buffer.from(b64.slice(0, 16), "base64");
		if (isPng(head) || (head.length < 8 && guessMime(b64) === "image/png")) return b64;
	} catch {
		return b64;
	}

	// Non-PNG: transcode + downscale via photon — the same WASM engine pi
	// itself ships (sips fallback removed 2026-10-17: macOS-only, and in test
	// contexts it silently masked a non-resolving photon).
	try {
		const raw = b64.startsWith("data:") ? (b64.split(",")[1] ?? "") : b64;
		const buf = Buffer.from(raw, "base64");
		if (!isValidImage(buf)) return b64;
		const norm = normalizeImageForDisplay(buf, guessMime(b64));
		if (norm) return norm.toString("base64");
	} catch {
		/* return the input unchanged */
	}
	return b64;
}
