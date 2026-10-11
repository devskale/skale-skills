// tests/image-normalize/make-fixtures.mjs — deterministic offline fixtures.
// Usage: node <pi-cli.js> make-fixtures.mjs <outDir>
// Builds: big.png (1430x2275, the incident screenshot's shape), small.png (200x100),
// photo.jpg (JPEG), exif6.jpg (JPEG carrying EXIF orientation 6 → must come back upright).
import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const outDir = JSON.parse(process.env.PROBE_ARGS ?? "[]")[0];
mkdirSync(outDir, { recursive: true });

// photon resolves from THIS file's own node_modules chain (pi's install root).
const { createRequire } = await import("node:module");
const req = createRequire(process.argv[1]);
const photon = req("@silvia-odwyer/photon-node");

/** Solid-ish RGBA raster with a deterministic pattern (gradient + blocks). */
function raster(w, h) {
	const px = new Uint8Array(w * h * 4);
	for (let y = 0; y < h; y++) {
		for (let x = 0; x < w; x++) {
			const i = (y * w + x) * 4;
			px[i] = (x * 255) / w; // horizontal gradient
			px[i + 1] = (y * 255) / h; // vertical gradient
			px[i + 2] = ((x + y) % 64) * 4; // fine texture (stands in for text)
			px[i + 3] = 255;
		}
	}
	return px;
}

function writePng(name, w, h) {
	const img = new photon.PhotonImage(raster(w, h), w, h);
	writeFileSync(join(outDir, name), Buffer.from(img.get_bytes()));
	img.free();
}

function writeJpeg(name, w, h, quality) {
	const img = new photon.PhotonImage(raster(w, h), w, h);
	writeFileSync(join(outDir, name), Buffer.from(img.get_bytes_jpeg(quality)));
	img.free();
}

// EXIF-orientation-6 JPEG: a 100x200 image tagged "rotate 90 CW" must come back
// as 200x100. We build the pixels in landscape, then hand-write a minimal JFIF
// with an APP1/Exif block carrying orientation=6 — photon decodes the pixels
// as-is, our reader must see the tag and rotate.
function writeExifOrientedJpeg(name, w, h) {
	const img = new photon.PhotonImage(raster(w, h), w, h);
	const jpeg = Buffer.from(img.get_bytes_jpeg(85));
	img.free();
	const exif = buildExif(6);
	// Insert APP1 right after SOI (first two bytes).
	const out = Buffer.concat([jpeg.subarray(0, 2), exif, jpeg.subarray(2)]);
	writeFileSync(join(outDir, name), out);
}

/** Minimal TIFF/Exif header with one IFD entry: Orientation = value. */
function buildExif(orientation) {
	const tiff = Buffer.alloc(26);
	// TIFF header (big-endian): "MM" + 0x002A + IFD offset 8
	tiff.write("MM", 0, "latin1");
	tiff.writeUInt16BE(0x2a, 2);
	tiff.writeUInt32BE(8, 4);
	// IFD: 1 entry
	tiff.writeUInt16BE(1, 8);
	// entry: tag 0x0112 (Orientation), type SHORT (3), count 1, value
	tiff.writeUInt16BE(0x0112, 10);
	tiff.writeUInt16BE(3, 12);
	tiff.writeUInt32BE(1, 14);
	tiff.writeUInt16BE(orientation, 18);
	tiff.writeUInt32BE(0, 20); // next IFD = none
	const payload = Buffer.concat([Buffer.from("Exif\0\0", "latin1"), tiff]);
	const app1 = Buffer.alloc(4);
	app1.writeUInt16BE(0xffe1, 0);
	app1.writeUInt16BE(payload.length + 2, 2);
	return Buffer.concat([app1, payload]);
}

writePng("big.png", 1430, 2275); // 3.25 MP — over both ceilings
writePng("small.png", 200, 100); // under both ceilings
writeJpeg("photo.jpg", 2000, 1500, 85); // over the edge ceiling, JPEG in
writeExifOrientedJpeg("exif6.jpg", 200, 100); // tagged rotate-90-CW
console.log("fixtures written to", outDir);
