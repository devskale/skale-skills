// tests/image-normalize/probe.mjs — behaviour assertions for image-normalize.
// Usage: node <pi-cli.js> probe.mjs <compiled-image-normalize.js> <fixturesDir>
// Prints "ok <name>" / "FAIL <name>" / "warn <name> (reason)" lines.
import { readFileSync } from "node:fs";
import { join } from "node:path";

const [modPath, fixDir] = JSON.parse(process.env.PROBE_ARGS ?? "[]");
const mod = await import(modPath);
const { normalizeImageForVlm, normalizeImageForDisplay, isNormalizationAvailable } = mod;

const results = [];
const ok = (name) => results.push(`ok ${name}`);
const FAIL = (name) => results.push(`FAIL ${name}`);
const warn = (name, why) => results.push(`warn ${name} (${why})`);

const available = isNormalizationAvailable();
if (!available) {
	// Degraded machine: the ONLY contract is "null, never throw".
	warn("photon available", "not resolvable here — degraded-mode checks only");
	const buf = readFileSync(join(fixDir, "big.png"));
	try {
		const r = normalizeImageForVlm(buf, "image/png");
		if (r === null) ok("degraded: normalizeImageForVlm returns null (no throw)");
		else FAIL("degraded: expected null, got a resize");
		const d = normalizeImageForDisplay(buf, "image/png");
		if (d === null) ok("degraded: normalizeImageForDisplay returns null (no throw)");
		else FAIL("degraded: display expected null");
	} catch (e) {
		FAIL(`degraded: threw ${e.message}`);
	}
} else {
	ok("photon available");

	// 1. big PNG → downscaled, aspect preserved, under both ceilings
	const big = readFileSync(join(fixDir, "big.png"));
	const r = normalizeImageForVlm(big, "image/png", { jpegQuality: 80 });
	if (!r) {
		FAIL("big: expected a resize");
	} else {
		if (r.originalWidth === 1430 && r.originalHeight === 2275) ok("big: original dims reported");
		else FAIL(`big: original dims ${r.originalWidth}x${r.originalHeight}`);
		const ar0 = r.originalWidth / r.originalHeight;
		const ar1 = r.width / r.height;
		if (Math.abs(ar0 - ar1) / ar0 < 0.02) ok("big: aspect ratio preserved");
		else FAIL(`big: aspect drifted ${ar0.toFixed(3)} -> ${ar1.toFixed(3)}`);
		if (Math.max(r.width, r.height) <= 1568) ok("big: long edge ≤ 1568");
		else FAIL(`big: long edge ${Math.max(r.width, r.height)} > 1568`);
		if (r.width * r.height <= 2_000_000) ok("big: under the 2MP pixel cap");
		else FAIL(`big: ${r.width * r.height} px over cap`);
		if (r.wasResized) ok("big: wasResized flag");
		else FAIL("big: wasResized missing");
		if (r.data.length < big.length) ok(`big: payload shrunk (${big.length} -> ${r.data.length})`);
		else FAIL(`big: payload grew (${big.length} -> ${r.data.length})`);
	}

	// 2. small PNG → null (never upscaled)
	const small = readFileSync(join(fixDir, "small.png"));
	if (normalizeImageForVlm(small, "image/png") === null) ok("small: untouched (null, no upscale)");
	else FAIL("small: should be null");

	// 3. big JPEG in → JPEG out, downscaled
	const jpg = readFileSync(join(fixDir, "photo.jpg"));
	const rj = normalizeImageForVlm(jpg, "image/jpeg", { jpegQuality: 80 });
	if (rj && rj.mimeType === "image/jpeg" && rj.originalWidth === 2000) ok("jpeg: decoded + downscaled, stays JPEG");
	else FAIL("jpeg: expected a JPEG resize");

	// 4. EXIF orientation 6 → 200x100 comes back 100x200 (rotated upright)
	const exif = readFileSync(join(fixDir, "exif6.jpg"));
	const re = normalizeImageForVlm(exif, "image/jpeg", { maxEdge: 0, maxPixels: 0 });
	if (re && re.width === 100 && re.height === 200) ok("exif6: orientation applied (200x100 -> 100x200)");
	else if (re) FAIL(`exif6: got ${re.width}x${re.height}, want 100x200`);
	else FAIL("exif6: expected a rotation result, got null");

	// 5. env ceilings: maxEdge=0 disables the edge rule; pixel cap still bites
	const rCap = normalizeImageForVlm(big, "image/png", { maxEdge: 0, maxPixels: 1_000_000, jpegQuality: 80 });
	if (rCap && rCap.width * rCap.height <= 1_000_000 && Math.max(rCap.width, rCap.height) > 1568 / 2) {
		ok("caps: pixel cap applies with the edge rule disabled");
	} else FAIL("caps: pixel-cap-only path misbehaved");

	// 6. PNG opt-out (jpegQuality 0) keeps PNG mime
	const rPng = normalizeImageForVlm(big, "image/png", { jpegQuality: 0 });
	if (rPng && rPng.mimeType === "image/png") ok("jpegQuality=0: stays PNG");
	else FAIL("jpegQuality=0: expected PNG");

	// 7. display path: PNG out, capped at 1200
	const d = normalizeImageForDisplay(big, "image/png");
	if (d && d.length > 32 && d[0] === 0x89 && d[1] === 0x50) ok("display: PNG out");
	else FAIL("display: expected PNG bytes");
	// small image: re-encoded as-is (no upscale) — must still be a valid PNG
	const dSmall = normalizeImageForDisplay(small, "image/png");
	if (dSmall && dSmall.length > 32 && dSmall[0] === 0x89 && dSmall[1] === 0x50)
		ok("display: small image re-encoded, no upscale");
	else FAIL("display: small image should re-encode to PNG");

	// 8. garbage in → null, never a throw
	try {
		const junk = Buffer.alloc(4096, 0x41);
		if (normalizeImageForVlm(junk, "image/png") === null) ok("garbage: null (no throw)");
		else FAIL("garbage: expected null");
	} catch (e) {
		FAIL(`garbage: threw ${e.message}`);
	}

	// 9. tiny buffer → null
	if (normalizeImageForVlm(Buffer.alloc(8), "image/png") === null) ok("tiny buffer: null");
	else FAIL("tiny buffer: expected null");
}

for (const line of results) console.log(line);
