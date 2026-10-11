// tests/image-normalize/run-with-pi-entry.mjs — shim: set argv[1] to pi's entry,
// then import the real probe. Needed because the lib resolves pi's bundled
// photon via createRequire(process.argv[1]) — exactly what pi does at runtime.
// The probe's OWN arguments are passed via PROBE_ARGS (JSON) so argv[1] stays
// pi's entry for the whole run.
// Usage: node run-with-pi-entry.mjs <pi-cli.js> <probe.mjs> [args...]
import { pathToFileURL } from "node:url";
import { resolve } from "node:path";

const piEntry = process.argv[2];
const probe = resolve(process.argv[3]);
const probeArgs = process.argv.slice(4);

// argv[1] must remain pi's entry — the lib's createRequire seam depends on it.
process.argv = [process.argv[0], piEntry, ...probeArgs];
process.env.PROBE_ARGS = JSON.stringify(probeArgs);

await import(pathToFileURL(probe).href);
