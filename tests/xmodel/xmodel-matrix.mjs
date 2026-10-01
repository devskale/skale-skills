// tests/xmodel/xmodel-matrix.mjs — mocked-ExtensionAPI routing matrix for xmodel v0.5.1
//
// Loaded by tests/xmodel/test.sh with:
//   HOME=<isolated tmp>   (empty config → default delegate mode, no user presets)
//   PATH=<tmp>/bin:$PATH  (fake failing curl → deterministic throway failure)
//   JITI_DIR=<pi node_modules> (jiti, the same loader pi uses for extensions)
// argv[2] = absolute path to extensions/xmodel.ts
//
// Prints `CHECK <name>: ok|FAIL` lines; exits non-zero on any FAIL.
import { createRequire } from "node:module";
import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";

if (process.argv.length < 3) {
	console.error("usage: xmodel-matrix.mjs <path-to-xmodel.ts>");
	process.exit(2);
}
const JITI_DIR = process.env.JITI_DIR;
if (!JITI_DIR) {
	console.error("JITI_DIR env not set (pi's node_modules containing jiti)");
	process.exit(2);
}
const require = createRequire(import.meta.url);
const { createJiti } = require(join(JITI_DIR, "jiti"));
const jiti = createJiti(import.meta.url);
const mod = await jiti.import(process.argv[2]);
const loadExtension = mod.default ?? mod;

const PNG_B64 =
	"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==";
const NO_VISION_NOTE =
	"[Current model does not support images. The image will be omitted from this request.]";
const NON_VISION = { provider: "test", id: "text-model", input: ["text"] };
const VISION = { provider: "test", id: "vlm-model", input: ["text", "image"] };

let failures = 0;
const check = (name, cond) => {
	console.log(`CHECK ${name}: ${cond ? "ok" : "FAIL"}`);
	if (!cond) failures++;
};

// ── mocked ExtensionAPI ─────────────────────────────────────────────────────
const handlers = {};
const renderers = {};
const tools = [];
const pi = {
	on: (ev, fn) => {
		(handlers[ev] ??= []).push(fn);
	},
	registerTool: (t) => tools.push(t),
	registerCommand: () => {},
	registerShortcut: () => {},
	registerMessageRenderer: (type, fn) => {
		renderers[type] = fn;
	},
	appendEntry: () => {},
	getThinkingLevel: () => "high",
	getActiveTools: () => [],
	getAllTools: () => [],
	setModel: async () => true,
	setThinkingLevel: () => {},
	setActiveTools: () => {},
};

loadExtension(pi);

function makeCtx(model) {
	const entries = [];
	const notes = [];
	return {
		cwd: process.cwd(),
		mode: "test",
		model,
		modelRegistry: { find: () => undefined, getAvailable: () => [] },
		isProjectTrusted: () => false,
		hasUI: false,
		signal: undefined,
		ui: {
			notify: (m, l) => notes.push(`${l ?? ""}: ${m}`),
			setStatus: () => {},
			theme: { fg: (_c, s) => s, bold: (s) => s },
		},
		sessionManager: {
			appendCustomMessageEntry: (type, content, display, details) =>
				entries.push({ type, content, display, details }),
			getEntries: () => [],
		},
		_notes: notes,
		_entries: entries,
	};
}

let seq = 0;
const readEvent = (input) => ({
	type: "tool_result",
	toolCallId: `t-${seq++}`,
	toolName: "read",
	input,
	content: [
		{ type: "image", data: PNG_B64, mimeType: "image/png" },
		{ type: "text", text: `Read image file [image/png]\n${NO_VISION_NOTE}` },
	],
	isError: false,
});

const textOf = (r) => (r?.content ?? []).filter((b) => b.type === "text").map((b) => b.text).join("\n");
const hasImage = (r) => (r?.content ?? []).some((b) => b.type === "image");

async function fireToolResult(event, ctx) {
	for (const h of handlers.tool_call ?? []) await h(event, ctx);
	return handlers.tool_result[0](event, ctx);
}

// session_start loads presets + vision config from the isolated HOME
await handlers.session_start[0]({}, makeCtx(NON_VISION));

// ── (a) default read img, non-vision model → handover display-only ─────────
{
	const ctx = makeCtx(NON_VISION);
	const res = await fireToolResult(readEvent({ path: "img.png" }), ctx);
	check("a: model content has NO image blocks", !hasImage(res));
	check("a: handover note present", textOf(res).includes("xmodel handover"));
	check("a: note teaches understand:true", textOf(res).includes("understand:true"));
	check("a: pi non-vision note stripped", !textOf(res).includes("omitted from this request"));
	const entry = ctx._entries[0];
	check(
		"a: display entry written (visible)",
		ctx._entries.length === 1 && entry.type === "xmodel-view" && entry.display === true,
	);
	check("a: display entry carries image", (entry?.details?.images ?? []).length === 1);
	// Truth-telling: the note must state HOW it rendered (pixels inline OR chafa ASCII),
	// and must never claim a render when the terminal can't actually draw it.
	const note = textOf(res);
	check("a: note states a render mode", /displayed (inline|as ASCII block art)/.test(note));
	check("a: note does NOT claim render when it could not", !/could NOT render/.test(note));
}

// ── (a2) default read img, VISION-capable model → STILL handover display-only ──
// Regression: a vision-capable main model must NOT receive pixels on a plain read.
// The isVisionCapable pass-through only applies when understand is requested.
{
	const ctx = makeCtx(VISION);
	const res = await fireToolResult(readEvent({ path: "img.png" }), ctx);
	check("a2: VISION model content has NO image blocks", !hasImage(res));
	check("a2: VISION model gets handover note", textOf(res).includes("xmodel handover"));
	const entry = ctx._entries[0];
	check("a2: VISION model display entry written", ctx._entries.length === 1 && entry.type === "xmodel-view" && entry.display === true);
}

// ── (b) understand:true + VISION model → inline display, pixels native ─────
// Contract (v0.5.6): `read` displays ALWAYS — understanding is opt-in and orthogonal.
// The vision model still gets the pixels natively (pass-through, no delegation),
// but the user must ALSO see the image inline.
{
	const ctx = makeCtx(VISION);
	const res = await fireToolResult(readEvent({ path: "img.png", understand: true }), ctx);
	check("b: pass-through (undefined)", res === undefined);
	check("b: but display entry STILL written", ctx._entries?.length === 1 && ctx._entries[0].type === "xmodel-view");
}

// ── (b2) understand:"<focus>" + VISION model → pass-through too ────────────
{
	const ctx = makeCtx(VISION);
	const res = await fireToolResult(readEvent({ path: "img.png", understand: "check the wheels" }), ctx);
	check("b2: focus string + vision model → pass-through", res === undefined);
	check("b2: display entry STILL written", ctx._entries?.length === 1 && ctx._entries[0].type === "xmodel-view");
}

// ── (c) understand:true + non-vision → no VLM configured → handover fallback
{
	const ctx = makeCtx(NON_VISION);
	const res = await fireToolResult(readEvent({ path: "img.png", understand: true }), ctx);
	check("c: fallback is handover (no pixels)", !hasImage(res) && textOf(res).includes("handover"));
	check(
		"c: no-VLM warning surfaced",
		ctx._notes.some((n) => n.includes("no vision model configured")),
	);
}

// ── (d) read is ALWAYS inline, even when _vision.mode = "view" ───────────
// Contract (v0.5.6): `read` on an image NEVER routes to throway/browser. The user
// asked to see it in their terminal, so that is what happens. `mode=view` remains
// available for OTHER tools (MCP screenshots, generate_image) via viewOnly.
{
	const home = process.env.HOME;
	mkdirSync(join(home, ".pi", "agent"), { recursive: true });
	writeFileSync(join(home, ".pi", "agent", "xmodel.json"), JSON.stringify({ _vision: { mode: "view" } }));
	await handlers.session_start[0]({}, makeCtx(NON_VISION)); // reload config
	const ctx = makeCtx(NON_VISION);
	const res = await fireToolResult(readEvent({ path: "img.png" }), ctx);
	const txt = textOf(res);
	check("d: read stays inline under mode=view", txt.includes("handover") && !txt.includes("xmodel view"));
	check("d: no throway/browser route for read", !txt.includes("throway") && !txt.includes("browser"));
	check("d: no image blocks for model", !hasImage(res));
	check("d: display entry still written", ctx._entries?.length === 1 && ctx._entries[0].type === "xmodel-view");
}

// ── (e) read_image {url} — download branch (fake curl fails deterministically) ─
{
	const tool = tools.find((t) => t.name === "read_image");
	check("e: read_image tool registered", typeof tool?.execute === "function");
	if (tool?.execute) {
		const res = await tool.execute("t-e", { url: "https://example.com/pic.jpg" }, undefined, () => {}, makeCtx(NON_VISION));
		const text = (res?.content ?? []).map((b) => b?.text ?? "").join(" ");
		check("e: url branch returns clean download error (offline)", /download failed/i.test(text));
		const resNone = await tool.execute("t-e2", {}, undefined, () => {}, makeCtx(NON_VISION));
		const textNone = (resNone?.content ?? []).map((b) => b?.text ?? "").join(" ");
		check("e: neither path nor url → clean error", /provide either/i.test(textNone));
	}
}

// ── renderer sanity ─────────────────────────────────────────────────────────
check("renderer registered for xmodel-view", typeof renderers["xmodel-view"] === "function");

process.exit(failures === 0 ? 0 : 1);
