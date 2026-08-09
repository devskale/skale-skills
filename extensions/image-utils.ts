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
