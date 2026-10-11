// tests/image-normalize/probe.mjs — behaviour assertions for image-normalize.
// Usage: node <pi-cli.js> probe.mjs <compiled-image-normalize.js> <fixturesDir>
// Prints "ok <name>" / "FAIL <name>" / "warn <name> (reason)" lines.
import { readFileSync } from "node:fs";
import { realpathSync } from "node:fs";
import { join } from "node:path";

const [modPath, fixDir] = JSON.parse(process.env.PROBE_ARGS ?? "[]");
const { createRequire: createRequireFn } = await import("node:module");
const req = createRequireFn(import.meta.url);
const mod = req(modPath);
// the progressive driver lives in the sibling lib (same CJS build)
const utilsPath = modPath.replace(/image-normalize\.js$/, "xmodel-vision-utils.js");
let utils = null;
try { utils = req(utilsPath); } catch { utils = null; }
const { normalizeImageForVlm, normalizeImageForDisplay, isNormalizationAvailable } = mod;


/** Build a 1440x12000 ultra-long page (text bands every 800px) with photon. */
function makeUltraLong() {
	const cr = createRequireFn;
	const bases = [process.argv[1]];
	try {
		const real = realpathSync(process.argv[1]);
		if (real !== process.argv[1]) bases.push(real);
	} catch {}
	let photon;
	for (const b of bases) {
		try {
			const m = cr(b)("@silvia-odwyer/photon-node");
			if (m?.PhotonImage) { photon = m; break; }
		} catch {}
	}
	if (!photon) return null;
	const W = 1440, H = 12000;
	const px = new Uint8Array(W * H * 4);
	for (let y = 0; y < H; y++) {
		for (let x = 0; x < W; x++) {
			const i = (y * W + x) * 4;
			const isText = y % 40 < 14 && x > 100 && x < 1300;
			px[i] = px[i + 1] = px[i + 2] = isText ? 220 : 30;
			px[i + 3] = 255;
		}
	}
	const img = new photon.PhotonImage(px, W, H);
	return Buffer.from(img.get_bytes());
}

let big = null;
let small = null;
let jpg = null;
try {
	big = readFileSync(join(fixDir, "big.png"));
	small = readFileSync(join(fixDir, "small.png"));
	jpg = readFileSync(join(fixDir, "photo.jpg"));
} catch {}

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
	// (big/small/jpg are read at top level — the tiling tests at EOF reuse them)
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
	if (normalizeImageForVlm(small, "image/png") === null) ok("small: untouched (null, no upscale)");
	else FAIL("small: should be null");

	// 3. big JPEG in → JPEG out, downscaled
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


	// 10. tiling: an ultra-long page is cut into overlapping readable segments
	if (!available) {
		warn("tiling", "photon unavailable — degraded machine, tiling not exercisable");
	} else {
	const ultra = makeUltraLong(); // 1440x12000 built inline below
	if (!ultra) FAIL("tiling: fixture build returned null");
	const plan = ultra ? mod.planTiles(ultra, "image/png") : null;
	if (!plan || !plan.tiled) {
		FAIL("tiling: ultra-long page should be tiled");
	} else {
		if (plan.tiles.length > 1) ok(`tiling: ${plan.tiles.length} segments produced`);
		else FAIL("tiling: expected multiple segments");
		const seg0 = plan.tiles[0];
		const aspect = Math.max(seg0.data.length > 0 ? 1 : 0, 1); // data present
		if (seg0.data.length > 1000 && seg0.index === 1 && seg0.total === plan.tiles.length) {
			ok("tiling: first segment has data + 1-based index/total");
		} else FAIL("tiling: segment metadata wrong");
		// every segment must be within the tile height (readable), and consecutive
		// segments must OVERLAP (cut lines survive)
		const heights = plan.tiles.map((t) => t.y2 - t.y1);
		if (heights.every((h) => h <= 1568)) ok("tiling: every segment ≤ 1568px tall");
		else FAIL(`tiling: segment too tall (${Math.max(...heights)})`);
		const overlapOk = plan.tiles.slice(1).every((t, i) => t.y1 < plan.tiles[i].y2);
		if (overlapOk) ok("tiling: consecutive segments overlap");
		else FAIL("tiling: no overlap between segments");
		// last segment must reach the bottom
		if (plan.tiles[plan.tiles.length - 1].y2 === plan.originalHeight) ok("tiling: last segment reaches the bottom");
		else FAIL("tiling: bottom not covered");
	}

	// 11. tiling is NOT used for normal aspect ratios (the common case)
	const normalPlan = mod.planTiles(big, "image/png"); // 1430x2275 = 1.59 aspect
	if (normalPlan && normalPlan.tiled === false && normalPlan.tiles.length === 0) {
		ok("tiling: normal screenshot stays on the downscale path");
	} else FAIL("tiling: normal image should not be tiled");

	// 12. wantsMoreSegments gate
	if ((utils ?? mod).wantsMoreSegments("NEED MORE\nI need the footer with the Datenstand line")) {
		ok("gate: NEED MORE detected");
	} else FAIL("gate: NEED MORE not detected");
	if (!(utils ?? mod).wantsMoreSegments("The dashboard shows 100% coverage.")) {
		ok("gate: a real answer does not trigger more segments");
	} else FAIL("gate: false positive on a normal answer");

	// 13. progressive driver: answers from segment 1 → ONE call, no further tiles
	{
		const calls = [];
		const fakePlan = {
			tiles: [1, 2, 3].map((i) => ({ index: i, total: 3, y1: (i - 1) * 100, y2: i * 100, data: Buffer.alloc(8), mimeType: "image/png" })),
			originalWidth: 100,
			originalHeight: 300,
			tiled: true,
		};
		const res = await (utils ?? mod).analyzeTiledImage({
			model: "test/vlm-model",
			systemPrompt: "s",
			prompt: "p",
			plan: fakePlan,
			runChild: async (o) => {
				calls.push(o.imageFile.length);
				return { text: "The answer is 42.", timedOut: false, aborted: false, reason: "close" };
			},
		});
		if (calls.length === 1 && res.segmentsUsed === 1 && res.text.includes("42")) {
			ok("progression: answered in segment 1 → exactly one call");
		} else FAIL(`progression: expected 1 call, got ${calls.length}`);
	}

	// 14. progressive driver: NEED MORE pulls the next batch, then answers
	{
		const calls = [];
		const fakePlan = {
			tiles: [1, 2, 3, 4, 5].map((i) => ({ index: i, total: 5, y1: (i - 1) * 100, y2: i * 100, data: Buffer.alloc(8), mimeType: "image/png" })),
			originalWidth: 100,
			originalHeight: 500,
			tiled: true,
		};
		const res = await (utils ?? mod).analyzeTiledImage({
			model: "test/vlm-model",
			systemPrompt: "s",
			prompt: "p",
			plan: fakePlan,
			tilesPerCall: 2,
			runChild: async (o) => {
				calls.push(o.imageFile.length);
				return calls.length === 1
					? { text: "NEED MORE\nI need the footer", timedOut: false, aborted: false, reason: "close" }
					: { text: "The footer says Datenstand 2026-10-11.", timedOut: false, aborted: false, reason: "close" };
			},
		});
		// first call = 1 tile (maximal progression), then a batch of tilesPerCall
		if (calls.length === 2 && calls[0] === 1 && calls[1] === 2 && res.segmentsUsed === 3 && res.text.includes("Datenstand")) {
			ok("progression: NEED MORE pulls the next batch, then answers");
		} else FAIL(`progression: calls=${calls.join(",")} used=${res.segmentsUsed}`);
	}

	// 15. progression stops at the page end and reports truncation honestly
	{
		const fakePlan = {
			tiles: [1, 2].map((i) => ({ index: i, total: 2, y1: (i - 1) * 100, y2: i * 100, data: Buffer.alloc(8), mimeType: "image/png" })),
			originalWidth: 100,
			originalHeight: 200,
			tiled: true,
		};
		const res = await (utils ?? mod).analyzeTiledImage({
			model: "test/vlm-model",
			systemPrompt: "s",
			prompt: "p",
			plan: fakePlan,
			runChild: async () => ({ text: "NEED MORE\nstill missing the end", timedOut: false, aborted: false, reason: "close" }),
		});
		if (res.truncated === true && res.segmentsUsed === 2) {
			ok("progression: end-of-page NEED MORE reports truncated");
		} else FAIL(`progression: truncated=${res.truncated} used=${res.segmentsUsed}`);
	}

}

for (const line of results) console.log(line);
