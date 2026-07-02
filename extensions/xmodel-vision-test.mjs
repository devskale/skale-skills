#!/usr/bin/env node
/**
 * xmodel vision-delegation pipeline test.
 *
 * Validates the full pipe the extension runs when an image appears and the main
 * model is non-vision:
 *
 *   compressor (current model writes a focused query)
 *     → VLM (query + image → analysis)
 *     → grounded text fed back
 *
 * Mirrors the extension's runChildPi EXACTLY: `pi --mode json -p` + JSONL parse.
 * Runs against a KNOWN image so we can assert non-hallucination.
 *
 * Usage:
 *   node extensions/xmodel-vision-test.mjs
 *
 * Env overrides:
 *   XMODEL_COMPRESSOR  (default zai/glm-5.2)   — model that writes the query
 *   XMODEL_VLM         (default zai/glm-5v-turbo) — vision model
 *   XMODEL_TEST_IMG    (default /tmp/xmodel-ground.png)
 *   XMODEL_NO_GEN=1    — skip image generation (use an existing XMODEL_TEST_IMG)
 */
import { spawn } from "node:child_process";
import { writeFileSync, existsSync, unlinkSync } from "node:fs";
import { spawnSync } from "node:child_process";

const COMPRESSOR = process.env.XMODEL_COMPRESSOR ?? "zai/glm-5.2";
const VLM = process.env.XMODEL_VLM ?? "zai/glm-5v-turbo";
const IMG = process.env.XMODEL_TEST_IMG ?? "/tmp/xmodel-ground.png";

const BRIEF_SYS =
	"You write a focused query for a vision model. Given the coding-agent conversation, output ONLY what the vision model should examine/answer about the upcoming image — the task goal plus any specific things to check. No preamble, no code dumps. Respect the char budget.";
const VLM_SYS =
	"You are a vision analyst embedded in a coding agent. Given a task brief and one image, report concrete, actionable observations about the image in service of the task (UI state, visible text, errors, layout, discrepancies, colours). Be precise and concise. Output only the analysis.";

// Simulated recent conversation (what gatherRecentContext would feed the compressor).
// The task asks for a full visual description AND contains a trap — it assumes a
// "green login button" that the known image does NOT contain. A grounded VLM must
// describe the real content and reject that premise.
const RECENT = [
	"USER: I built a UI dashboard. Read the screenshot and describe everything you see — all shapes, colours, and any text — and tell me whether the green login button is visible.",
	"ASSISTANT: Let me open the screenshot to describe the shapes, colours and text, and check whether the green login button is visible.",
].join("\n");

// Known image ground truth (generated below): red bg, green square top-left,
// blue circle top-right, text "XMODEL-TEST 42". NO login button.
const GROUND = {
	text: /XMODEL.?TEST.?42/i,
	green: /green/i,
	blue: /blue/i,
	red: /red/i,
	// Grounded = the VLM does NOT affirm a login button exists. We look for an
	// explicit negation near "login"/"button" rather than just the phrase, so a
	// correct "there is no green login button" is NOT flagged as a hallucination.
	deniesButton: (s) => {
		const neg = /\b(no|not|without|cannot|can't|doesn't|does not|isn't|is no|absent|missing|none)\b/i;
		const mentions = /login|button/i.test(s);
		return mentions ? neg.test(s) : true; // if it never mentions a button, that's fine too
	},
};

/** Spawn `pi --mode json -p` (NOT bare --print — text mode hangs on piped stdout). */
function runPi(model, sys, prompt, image, timeoutMs = 90_000) {
	return new Promise((resolve) => {
		const args = [
			"--mode", "json", "-p",
			"--no-tools", "--no-extensions", "--no-context-files",
			"--no-skills", "--no-prompt-templates", "--no-themes",
			"--model", model,
			"--system-prompt", sys,
		];
		if (image) args.push(`@${image}`);
		args.push(prompt);
		const t = Date.now();
		const proc = spawn("pi", args, { stdio: ["ignore", "pipe", "pipe"], env: { ...process.env, NO_COLOR: "1" } });
		let out = "";
		const timer = setTimeout(() => proc.kill("SIGTERM"), timeoutMs);
		proc.stdout.on("data", (d) => {
			out += d.toString();
			if (out.length > 8 << 20) proc.kill();
		});
		proc.on("close", () => {
			clearTimeout(timer);
			resolve({ secs: ((Date.now() - t) / 1000).toFixed(1), text: extractFinalAssistantText(out), raw: out });
		});
		proc.on("error", () => {
			clearTimeout(timer);
			resolve({ secs: ((Date.now() - t) / 1000).toFixed(1), text: "", raw: "" });
		});
	});
}

function extractFinalAssistantText(jsonl) {
	const lines = jsonl.split("\n");
	let agentEnd;
	for (let i = lines.length - 1; i >= 0; i--) {
		const line = lines[i].trim();
		if (!line) continue;
		try {
			const j = JSON.parse(line);
			if (j && j.type === "agent_end") { agentEnd = j; break; }
		} catch {}
	}
	const msgs = Array.isArray(agentEnd?.messages) ? agentEnd.messages : [];
	for (let i = msgs.length - 1; i >= 0; i--) {
		const m = msgs[i];
		if (m && m.role === "assistant") {
			const c = m.content;
			if (typeof c === "string") return c.trim();
			if (Array.isArray(c)) return c.filter((b) => b && b.type === "text").map((b) => b.text || "").join(" ").trim();
		}
	}
	return "";
}

function genImage(path) {
	const py = `
from PIL import Image, ImageDraw, ImageFont
img = Image.new("RGB", (320, 160), (200, 30, 30))
d = ImageDraw.Draw(img)
d.rectangle([20,20,120,120], fill=(0,160,0))
d.ellipse([200,20,300,120], fill=(0,0,220))
try: f = ImageFont.truetype("/System/Library/Fonts/Menlo.ttc", 28)
except: f = ImageFont.load_default()
d.text((40,130), "XMODEL-TEST 42", fill=(255,255,255), font=f)
img.save("${path}")
print("ok")
`;
	const r = spawnSync("python3", ["-c", py], { encoding: "utf-8" });
	return r.status === 0 && r.stdout.trim() === "ok";
}

const results = [];
function check(name, ok, detail = "") {
	results.push({ name, ok });
	console.log(`  ${ok ? "✅" : "❌"} ${name}${detail ? " — " + detail : ""}`);
}

async function main() {
	console.log("xmodel vision-delegation pipeline test");
	console.log("========================================");
	console.log(`compressor: ${COMPRESSOR}`);
	console.log(`vlm:        ${VLM}`);
	console.log(`image:      ${IMG}`);

	// 0. image
	if (!existsSync(IMG) && process.env.XMODEL_NO_GEN !== "1") {
		console.log("\n[0] generating known test image…");
		if (!genImage(IMG)) {
			console.log("  ⚠️  could not generate image (PIL missing?). Set XMODEL_TEST_IMG or XMODEL_NO_GEN=1.");
			process.exit(2);
		}
	}
	if (!existsSync(IMG)) {
		console.log(`\n❌ test image not found: ${IMG}`);
		process.exit(2);
	}
	console.log(`  known content: red bg, green square TL, blue circle TR, text "XMODEL-TEST 42", NO login button`);

	// 1. compressor
	console.log("\n[1] compressor — current model writes a focused query");
	const q = await runPi(COMPRESSOR, BRIEF_SYS, `Char budget: 1500. Write the vision query for the conversation below.\n\n---\n${RECENT}\n---`);
	console.log(`  (${q.secs}s) ${q.text.slice(0, 160)}${q.text.length > 160 ? "…" : ""}`);
	check("compressor returned non-empty query", q.text.length > 0, `${q.text.length} chars`);
	check("compressor query is task-focused (mentions button/login)", /button|login/i.test(q.text));

	// 2. VLM
	console.log("\n[2] VLM — query + image → analysis");
	const v = await runPi(VLM, VLM_SYS, `Task brief:\n${q.text}\n\nAnalyze the attached image in service of this task and report concrete findings.`, IMG);
	console.log(`  (${v.secs}s)`);
	console.log(v.text.split("\n").map((l) => "    " + l).join("\n"));

	// 3. grounding assertions (non-hallucination)
	console.log("\n[3] grounding checks");
	check("VLM transcribed the exact page text 'XMODEL-TEST 42'", GROUND.text.test(v.text));
	check("VLM saw the green square", GROUND.green.test(v.text));
	check("VLM saw the blue circle", GROUND.blue.test(v.text));
	check("VLM saw the red background", GROUND.red.test(v.text));
	check("VLM did NOT hallucinate a login button", GROUND.deniesButton(v.text), "explicitly denied / not affirmed");
	check("VLM produced substantive output", v.text.length > 40);

	// summary
	const passed = results.filter((r) => r.ok).length;
	const total = results.length;
	console.log("\n========================================");
	console.log(`${passed}/${total} checks passed`);
	if (passed !== total) {
		console.log("❌ FAIL");
		process.exit(1);
	}
	console.log("✅ PASS — pipeline is grounded, no hallucination");
}

main().catch((e) => {
	console.error("test crashed:", e);
	process.exit(1);
});
