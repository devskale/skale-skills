/**
 * image-normalize — portable image normalisation for the vision path.
 *
 * WHY: every vision provider silently downscales images server-side (Claude
 * 1568px/~1.15MP, GPT-4o 2048-box→768→tiles, Qwen3-VL max_pixels≈576 tokens,
 * Gemini token budget). Sending a 5000px full-page screenshot therefore only
 * pays bandwidth + base64 payload (the child-pi output stream grew to 3.4 MB
 * during the 2026-10-09 timeout incident) for pixels the model never sees.
 *
 * The fix has to run EVERYWHERE (mac, Linux, Windows — the package ships to all
 * three), so no `sips`, no ImageMagick, no native binary. pi bundles
 * @silvia-odwyer/photon-node (WASM, cross-platform) for its own image-resize
 * worker; we resolve it the same way pi does (createRequire from pi's entry,
 * process.argv[1]) and reuse it. Zero new dependencies, zero OS branching.
 *
 * Contract (fail-soft, never worse than the input):
 *   - decode → honour EXIF orientation → aspect-preserving DOWNscale only
 *     (never upscale a small image) → cap total pixels → re-encode
 *   - returns null on ANY failure (missing photon, corrupt bytes, oversize):
 *     callers fall back to the original bytes. Normalisation is an optimisation,
 *     never a gate.
 */

import { createRequire } from "node:module";

/** Long-edge ceiling for the VLM payload. 1568px = Claude's processing ceiling and
 * comfortably above Qwen3-VL's ~576-token budget; every provider sees ≤ this. */
export const DEFAULT_MAX_EDGE = 1568;

/** Total-pixel ceiling — catches extreme panoramas / long full-page captures that
 * slip through the long-edge rule (a 1:8 strip at 1568px would be 19k px tall). */
export const DEFAULT_MAX_PIXELS = 2_000_000; // ~2MP ≈ 1600×1250

export interface NormalizeOptions {
	/** Long-edge ceiling in px (default 1568). Set 0/undefined to disable. */
	maxEdge?: number;
	/** Total-pixel ceiling (default 2MP). Set 0/undefined to disable. */
	maxPixels?: number;
	/** Re-encode as JPEG at this quality instead of PNG (0 = keep PNG). */
	jpegQuality?: number;
}

export interface NormalizeResult {
	data: Buffer;
	mimeType: string;
	width: number;
	height: number;
	originalWidth: number;
	originalHeight: number;
	wasResized: boolean;
	wasReencoded: boolean;
}

type PhotonModule = any;

let cachedPhoton: PhotonModule | null | undefined;

/**
 * Resolve pi's bundled photon-node. Mirrors pi's own image-resize-worker:
 * createRequire(process.argv[1]) — argv[1] is pi's cli.js, whose node_modules
 * holds photon. Returns null when unavailable (degraded mode: caller keeps the
 * original image, exactly the pre-normalisation behaviour).
 */
function loadPhoton(): PhotonModule | null {
	if (cachedPhoton !== undefined) return cachedPhoton;
	try {
		const entry = process.argv[1];
		if (!entry) {
			cachedPhoton = null;
			return null;
		}
		// createRequire resolves from the entry file's own node_modules chain,
		// which is pi's installation root on every platform.
		const req = createRequire(entry);
		const mod = req("@silvia-odwyer/photon-node") as unknown as PhotonModule;
		cachedPhoton = mod && typeof mod.PhotonImage === "function" ? mod : null;
	} catch {
		cachedPhoton = null;
	}
	return cachedPhoton;
}

/** Read EXIF orientation (1..8) from JPEG/WebP bytes; 1 when absent. */
function readExifOrientation(bytes: Buffer): number {
	try {
		let tiff = -1;
		if (bytes.length >= 2 && bytes[0] === 0xff && bytes[1] === 0xd8) {
			// JPEG: walk segments to APP1/Exif
			let off = 2;
			while (off + 4 <= bytes.length) {
				if (bytes[off] !== 0xff) break;
				const marker = bytes[off + 1];
				if (marker === 0xd8 || (marker >= 0xd0 && marker <= 0xd7) || marker === 0x01) {
					off += 2;
					continue;
				}
				if (marker === 0xda) break;
				const len = (bytes[off + 2] << 8) | bytes[off + 3];
				if (marker === 0xe1 && len >= 8) {
					const s = off + 4;
					if (bytes[s] === 0x45 && bytes[s + 1] === 0x78 && bytes[s + 2] === 0x69 && bytes[s + 3] === 0x66) {
						tiff = s + 6;
						break;
					}
				}
				off += 2 + len;
			}
		} else if (bytes.length >= 12 && bytes.toString("latin1", 8, 12) === "WEBP") {
			// WebP: walk chunks to EXIF
			let off = 12;
			while (off + 8 <= bytes.length) {
				const id = bytes.toString("latin1", off, off + 4);
				const size = bytes.readUInt32LE(off + 4);
				if (id === "EXIF") {
					tiff = off + 8;
					break;
				}
				off += 8 + size + (size % 2);
			}
		}
		if (tiff < 0 || tiff + 8 > bytes.length) return 1;
		const le = ((bytes[tiff] << 8) | bytes[tiff + 1]) === 0x4949;
		const u16 = (p: number) => (le ? bytes[p] | (bytes[p + 1] << 8) : (bytes[p] << 8) | bytes[p + 1]);
		const u32 = (p: number) =>
			le
				? (bytes[p] | (bytes[p + 1] << 8) | (bytes[p + 2] << 16) | (bytes[p + 3] << 24)) >>> 0
				: ((bytes[p] << 24) | (bytes[p + 1] << 16) | (bytes[p + 2] << 8) | bytes[p + 3]) >>> 0;
		const ifd = tiff + u32(tiff + 4);
		if (ifd + 2 > bytes.length) return 1;
		const entries = u16(ifd);
		for (let i = 0; i < entries; i++) {
			const e = ifd + 2 + i * 12;
			if (e + 12 > bytes.length) break;
			if (u16(e) === 0x0112) {
				const v = u16(e + 8);
				return v >= 1 && v <= 8 ? v : 1;
			}
		}
	} catch {
		/* orientation is best-effort */
	}
	return 1;
}

/**
 * Apply EXIF orientation. Returns a (possibly new) PhotonImage; the caller must
 * free the ORIGINAL when the returned object differs. photon's own rotate() is
 * in-place and dimension-preserving (verified: a 200x100 stays 200x100), so the
 * 90-degree cases transpose the raw pixels explicitly with swapped dimensions.
 */
function applyOrientation(photon: PhotonModule, img: any, orientation: number): any {
	if (orientation <= 1) return img;
	const w = img.get_width();
	const h = img.get_height();
	const src: Uint8Array = img.get_raw_pixels();
	// Destination mapping per EXIF spec. `map(x,y)` returns the destination
	// linear index for source pixel (x,y) in an image of size (dw,dh).
	let dw = w;
	let dh = h;
	let map: (x: number, y: number) => number;
	switch (orientation) {
		case 2: // mirror horizontal
			map = (x, y) => (y * w + (w - 1 - x)) * 4;
			break;
		case 3: // rotate 180
			map = (x, y) => ((h - 1 - y) * w + (w - 1 - x)) * 4;
			break;
		case 4: // mirror vertical
			map = (x, y) => ((h - 1 - y) * w + x) * 4;
			break;
		case 5: // transpose (mirror horizontal + rotate 90 CW)
			dw = h;
			dh = w;
			map = (x, y) => ((h - 1 - y) * dh + x) * 4;
			break;
		case 6: // rotate 90 CW
			dw = h;
			dh = w;
			map = (x, y) => (x * dh + (h - 1 - y)) * 4;
			break;
		case 7: // transverse (mirror horizontal + rotate 270 CW)
			dw = h;
			dh = w;
			map = (x, y) => (y * dh + x) * 4;
			break;
		case 8: // rotate 270 CW
			dw = h;
			dh = w;
			map = (x, y) => ((w - 1 - x) * dh + y) * 4;
			break;
		default:
			return img;
	}
	const dst = new Uint8Array(src.length);
	for (let y = 0; y < h; y++) {
		for (let x = 0; x < w; x++) {
			const s = (y * w + x) * 4;
			const d = map(x, y);
			dst[d] = src[s];
			dst[d + 1] = src[s + 1];
			dst[d + 2] = src[s + 2];
			dst[d + 3] = src[s + 3];
		}
	}
	return new photon.PhotonImage(dst, dw, dh);
}

/**
 * Normalise an image for the vision path. Returns null when nothing should
 * change (already small) OR when normalisation is impossible — callers must
 * treat null as "use the original bytes".
 */
export function normalizeImageForVlm(buf: Buffer, _mimeType: string, opts: NormalizeOptions = {}): NormalizeResult | null {
	const photon = loadPhoton();
	if (!photon) return null; // degraded: no WASM available
	if (!buf || buf.length < 32) return null;

	const maxEdge = opts.maxEdge === undefined ? DEFAULT_MAX_EDGE : opts.maxEdge;
	const maxPixels = opts.maxPixels === undefined ? DEFAULT_MAX_PIXELS : opts.maxPixels;
	const jpegQuality = opts.jpegQuality ?? 0;

	let img: any;
	try {
		img = photon.PhotonImage.new_from_byteslice(new Uint8Array(buf));
		if (!img) return null;

		const orientation = readExifOrientation(buf);
		const oriented = applyOrientation(photon, img, orientation);
		if (oriented !== img) {
			try {
				img.free();
			} catch {}
			img = oriented;
		}

		const w0 = img.get_width();
		const h0 = img.get_height();
		if (!w0 || !h0 || w0 > 100000 || h0 > 100000) return null; // sanity: absurd dims
		const w = w0;
		const h = h0;

		// Already within both ceilings and no EXIF correction needed → nothing to do.
		const withinEdge = !maxEdge || (w <= maxEdge && h <= maxEdge);
		const withinPixels = !maxPixels || w * h <= maxPixels;
		if (withinEdge && withinPixels && orientation === 1) return null;

		// Aspect-preserving downscale. Two passes: long-edge rule first, then the
		// pixel cap (a 1:8 strip can pass the edge rule and still blow the budget).
		let scale = 1;
		if (maxEdge && Math.max(w, h) > maxEdge) scale = Math.min(scale, maxEdge / Math.max(w, h));
		if (maxPixels && w * h > maxPixels) scale = Math.min(scale, Math.sqrt(maxPixels / (w * h)));
		let tw = Math.max(1, Math.round(w * scale));
		let th = Math.max(1, Math.round(h * scale));

		const resized = photon.resize(img, tw, th, photon.SamplingFilter.Lanczos3);
		try {
			// verify what we actually got (photon clamps to ≥1)
			tw = resized.get_width();
			th = resized.get_height();
			let out: Buffer;
			let outMime: string;
			if (jpegQuality > 0) {
				out = Buffer.from(resized.get_bytes_jpeg(jpegQuality));
				outMime = "image/jpeg";
			} else {
				out = Buffer.from(resized.get_bytes());
				outMime = "image/png";
			}
			if (!out || out.length < 32) return null;
			return {
				data: out,
				mimeType: outMime,
				width: tw,
				height: th,
				originalWidth: w,
				originalHeight: h,
				wasResized: true,
				wasReencoded: true,
			};
		} finally {
			try {
				resized.free();
			} catch {}
		}
	} catch {
		return null;
	} finally {
		if (img) {
			try {
				img.free();
			} catch {}
		}
	}
}

/** True when the photon WASM path is usable on this machine. */
export function isNormalizationAvailable(): boolean {
	return loadPhoton() !== null;
}

/** Exposed for tests: probe whether pi's bundled photon is resolvable here. */
export function normalizationProbe(): { available: boolean; entry: string | undefined } {
	return { available: isNormalizationAvailable(), entry: process.argv[1] };
}

/**
 * Transcode + downscale an image to PNG for terminal DISPLAY (not the VLM path).
 * Same photon engine, different job: the terminal's Kitty path only accepts PNG
 * payloads, and a full-res photo is a 2–3 MB APC payload for ~100 cells of screen.
 * Returns null when photon is unavailable or the image cannot be decoded.
 */
export function normalizeImageForDisplay(buf: Buffer, _mimeType: string, maxEdge = 1200): Buffer | null {
	const photon = loadPhoton();
	if (!photon || !buf || buf.length < 32) return null;
	let img: any;
	try {
		img = photon.PhotonImage.new_from_byteslice(new Uint8Array(buf));
		if (!img) return null;
		const orientation = readExifOrientation(buf);
		const oriented = applyOrientation(photon, img, orientation);
		if (oriented !== img) {
			try {
				img.free();
			} catch {}
			img = oriented;
		}
		const w = img.get_width();
		const h = img.get_height();
		if (!w || !h) return null;
		// Display ALWAYS needs PNG bytes back (the terminal's Kitty path rejects
		// JPEG/WebP), so a small image is transcoded as-is — never upscaled, never
		// skipped. Only the size is capped.
		const target = scaleTo(w, h, maxEdge);
		const out =
			target.w === w && target.h === h
				? Buffer.from(img.get_bytes())
				: Buffer.from(photon.resize(img, target.w, target.h, photon.SamplingFilter.Lanczos3).get_bytes());
		return out.length >= 32 ? out : null;
	} catch {
		return null;
	} finally {
		if (img) {
			try {
				img.free();
			} catch {}
		}
	}
}

/** Aspect-preserving fit into a maxEdge box. */
function scaleTo(w: number, h: number, maxEdge: number): { w: number; h: number } {
	const s = maxEdge / Math.max(w, h);
	return { w: Math.max(1, Math.round(w * s)), h: Math.max(1, Math.round(h * s)) };
}
