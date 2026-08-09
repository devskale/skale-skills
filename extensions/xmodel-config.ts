/**
 * xmodel-config — the pure config store for the xmodel extension.
 *
 * Owns the JSON presets + `_vision` store (global ~/.pi/agent/xmodel.json,
 * merged with project .pi/xmodel.json). Extracted from xmodel.ts so the
 * config logic lives behind a small interface (the deep module) and the
 * extension entry wiring stays in xmodel.ts.
 *
 * Pure: no pi dependency, no extension state — only node:fs + node:path.
 */

import { existsSync, readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { join, dirname } from "node:path";
import { CONFIG_DIR_NAME, getAgentDir } from "@earendil-works/pi-coding-agent";

export type ThinkingLevel = "off" | "minimal" | "low" | "medium" | "high" | "xhigh";

export interface Preset {
	provider?: string;
	model?: string;
	thinkingLevel?: ThinkingLevel;
	tools?: string[];
	instructions?: string;
	/** Preset to fall back to on rate-limit / overload of this one. */
	fallback?: string;
}

export interface PresetsConfig {
	[name: string]: Preset;
}

export type VisionMode = "delegate" | "view" | "switch" | "human" | "off";
export interface VisionConfig {
	/** delegate = build a brief from recent msgs → single VLM sub-call → feed analysis back (default).
	 *  view    = show the image to the user only — NO analysis, no VLM call, zero tokens
	 *            (non-vision models; pi-ai still strips the image at send time).
	 *  switch  = old behaviour: flip the main model to vision for the turn.
	 *  human   = ask the user to describe the image (interactive TUI overlay).
	 *  off     = do nothing. */
	mode: VisionMode;
	/** "provider/id" of the vision model for the sub-call. Auto-picked if unset. */
	vlm?: string;
	/** Optional "provider/id" of a fast model (e.g. your light preset) that summarises the
	 *  last N messages into the task brief. Heuristic extraction if unset. Short timeout,
	 *  falls back to heuristic on any error so a slow/dead model never blocks. */
	compressor?: string;
	/** Char budget for the task brief sent to the VLM. */
	maxBriefChars: number;
	/** In delegate mode, also keep the original image inline in the tool result so the
	 *  human can see it. The non-vision main model still only receives the text analysis —
	 *  pi-ai's `downgradeUnsupportedImages` strips image parts it can't process at send time. */
	keepImage?: boolean;
}

export function defaultVision(): VisionConfig {
	return { mode: "delegate", maxBriefChars: 1500 };
}

export function globalPresetsPath(): string {
	return join(getAgentDir(), "xmodel.json");
}

export function projectPresetsPath(cwd: string): string {
	return join(cwd, CONFIG_DIR_NAME, "xmodel.json");
}

export function readRaw(path: string): PresetsConfig {
	if (!existsSync(path)) return {};
	try {
		const raw = JSON.parse(readFileSync(path, "utf-8")) as Record<string, unknown>;
		const out: PresetsConfig = {};
		for (const [k, v] of Object.entries(raw)) {
			if (k.startsWith("_")) continue; // reserved: _vision, etc.
			out[k] = v as Preset;
		}
		return out;
	} catch (err) {
		console.error(`xmodel: failed to load ${path}: ${err}`);
		return {};
	}
}

function readVisionRaw(path: string): Partial<VisionConfig> {
	if (!existsSync(path)) return {};
	try {
		const raw = JSON.parse(readFileSync(path, "utf-8")) as Record<string, any>;
		return (raw && raw._vision) ? raw._vision : {};
	} catch {
		return {};
	}
}

export function loadVisionConfig(cwd: string, includeProject = true): VisionConfig {
	let v: VisionConfig = { ...defaultVision(), ...readVisionRaw(globalPresetsPath()) };
	if (includeProject) v = { ...v, ...readVisionRaw(join(cwd, CONFIG_DIR_NAME, "xmodel.json")) };
	return v;
}

/** Merge-write a single `_vision` field into the file at `path`, preserving presets + other `_vision` keys.
 *  `value === undefined` removes the field (falls back to default / other tier). */
export function writeVisionField(cwd: string, scope: "global" | "project", field: string, value: unknown): void {
	const path = scope === "project" ? projectPresetsPath(cwd) : globalPresetsPath();
	let raw: Record<string, any> = {};
	if (existsSync(path)) {
		try {
			raw = JSON.parse(readFileSync(path, "utf-8")) as Record<string, any>;
		} catch {}
	}
	if (!raw._vision || typeof raw._vision !== "object") raw._vision = {};
	if (value === undefined) delete raw._vision[field];
	else raw._vision[field] = value;
	try {
		mkdirSync(dirname(path), { recursive: true });
	} catch {}
	writeFileSync(path, JSON.stringify(raw, null, 2) + "\n", "utf-8");
}

/** Where the effective value of a `_vision` field comes from (project wins, field-level merge). */
export function visionFieldSource(cwd: string, trusted: boolean, field: keyof VisionConfig): "project" | "global" | "default" {
	if (trusted) {
		const p = readVisionRaw(projectPresetsPath(cwd));
		if (p[field] !== undefined) return "project";
	}
	const g = readVisionRaw(globalPresetsPath());
	if (g[field] !== undefined) return "global";
	return "default";
}

export function writeGlobal(cfg: PresetsConfig): void {
	// Preserve _-prefixed reserved blocks (e.g. _vision) that readRaw() strips,
	// so /xm edit and /xm rm don't clobber the vision config.
	let full: Record<string, any> = {};
	if (existsSync(globalPresetsPath())) {
		try {
			full = JSON.parse(readFileSync(globalPresetsPath(), "utf-8")) as Record<string, any>;
		} catch {}
	}
	for (const k of Object.keys(full)) if (!k.startsWith("_")) delete full[k];
	for (const [k, v] of Object.entries(cfg)) full[k] = v;
	writeFileSync(globalPresetsPath(), JSON.stringify(full, null, 2) + "\n", "utf-8");
}

export function loadPresets(cwd: string, includeProject = true): PresetsConfig {
	const global = readRaw(globalPresetsPath());
	if (!includeProject) return global;
	return { ...global, ...readRaw(join(cwd, CONFIG_DIR_NAME, "xmodel.json")) };
}
