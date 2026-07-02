/**
 * xmodel (/xm) — instant model + thinking-mode switching.  v0.1.0
 *
 * One JSON dict drives the user (/xm, hotkey) and the agent (switch_model tool).
 * Auto-vision: when an image appears (read *.png, MCP screenshots, attached images),
 *   it is analysed by a VLM sub-model with a COMPRESSED context and the text
 *   analysis is fed back to the main model — the main model never switches and
 *   never blows its context window. (compressor → VLM → feedback. Set
 *   _vision.mode="switch" for the legacy main-model-flip behaviour, "off" to disable.)
 * Rate-limit fallback: on 429/503/529, auto-switches to a free variant
 * (explicit preset.fallback → `${name}-free` → any *free* preset).
 *
 * Config files (merged; project overrides global):
 *   ~/.pi/agent/xmodel.json
 *   <cwd>/.pi/xmodel.json
 *
 * Entry points (all route through applyPreset()):
 *   /xm [name]            switch preset (bare = picker)
 *   /xm edit [name]       super-UX wizard to set/edit a preset
 *   /xm rm [name]         remove a preset
 *   /xm models [query]    browse provider/model from the live registry
 *   /xm off               clear, restore defaults
 *   Ctrl+Shift+F          cycle presets
 *   switch_model tool     agent (LLM) switches itself
 *   /xm version           show version
 *
 * Preset shape:
 *   { "deep": { "provider": "zai", "model": "glm-5.2",
 *               "thinkingLevel": "high",
 *               "tools": [...],            // optional, replaces tool set
 *               "instructions": "..." } }  // optional, appended to system prompt
 *
 * Thinking levels: "off" | "minimal" | "low" | "medium" | "high" | "xhigh"
 * (clamped to model capabilities automatically)
 */

import { existsSync, readFileSync, writeFileSync, unlinkSync } from "node:fs";
import { join } from "node:path";
import { execFile, spawn } from "node:child_process";
import { Type } from "typebox";
import { StringEnum, type Api, type Model } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { CONFIG_DIR_NAME, getAgentDir } from "@earendil-works/pi-coding-agent";

const VERSION = "0.1.0";

type ThinkingLevel = "off" | "minimal" | "low" | "medium" | "high" | "xhigh";

interface Preset {
	provider?: string;
	model?: string;
	thinkingLevel?: ThinkingLevel;
	tools?: string[];
	instructions?: string;
	/** Preset to fall back to on rate-limit / overload of this one. */
	fallback?: string;
}

interface PresetsConfig {
	[name: string]: Preset;
}

type VisionMode = "delegate" | "switch" | "off";
interface VisionConfig {
	/** delegate = build a brief from recent msgs → single VLM sub-call → feed analysis back (default).
	 *  switch  = old behaviour: flip the main model to vision for the turn.
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
}
function defaultVision(): VisionConfig {
	return { mode: "delegate", maxBriefChars: 1500 };
}

function globalPresetsPath(): string {
	return join(getAgentDir(), "xmodel.json");
}

function readRaw(path: string): PresetsConfig {
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

function loadVisionConfig(cwd: string, includeProject = true): VisionConfig {
	let v: VisionConfig = { ...defaultVision(), ...readVisionRaw(globalPresetsPath()) };
	if (includeProject) v = { ...v, ...readVisionRaw(join(cwd, CONFIG_DIR_NAME, "xmodel.json")) };
	return v;
}

function writeGlobal(cfg: PresetsConfig): void {
	writeFileSync(globalPresetsPath(), JSON.stringify(cfg, null, 2) + "\n", "utf-8");
}

function loadPresets(cwd: string, includeProject = true): PresetsConfig {
	const global = readRaw(globalPresetsPath());
	if (!includeProject) return global;
	return { ...global, ...readRaw(join(cwd, CONFIG_DIR_NAME, "xmodel.json")) };
}

interface OriginalState {
	model: Model<Api> | undefined;
	thinkingLevel: ThinkingLevel;
	tools: string[];
}

export default function xmodelExtension(pi: ExtensionAPI) {
	let presets: PresetsConfig = {};
	let activeName: string | undefined;
	let activePreset: Preset | undefined;
	let original: OriginalState | undefined;

	// --- auto-vision: transient switch to a vision model when an image appears ---
	let autoVisionActive = false;
	let preAutoVisionModel: Model<Api> | undefined;

	// --- vision config (delegate / switch / off) ---
	let visionCfg: VisionConfig = defaultVision();

	// --- rate-limit fallback: switch to a free variant on 429/503/529 ---
	let lastFallbackAt = 0;
	const FALLBACK_COOLDOWN_MS = 30_000;

	const THINKING_LEVELS: ThinkingLevel[] = ["off", "minimal", "low", "medium", "high", "xhigh"];
	const NEW = "✚  New preset";
	const KEEP = "—  keep current";

	function fmt(m: Model<Api> | undefined): string {
		return m ? `${(m as any).provider ?? "?"}/${(m as any).id ?? "?"}` : "<none>";
	}

	/** Forensic log — append-only, off by default (set XMODEL_DEBUG=1). */
	function debug(tag: string, data: Record<string, unknown>): void {
		if (process.env.XMODEL_DEBUG !== "1") return;
		try {
			const line = `${new Date().toISOString()} [${tag}] ${JSON.stringify(data)}\n`;
			const fs = require("node:fs");
			fs.appendFileSync("/tmp/xmodel-debug.log", line);
		} catch {}
	}

	function describe(p: Preset): string {
		const parts: string[] = [];
		if (p.provider && p.model) parts.push(`${p.provider}/${p.model}`);
		if (p.thinkingLevel) parts.push(`think:${p.thinkingLevel}`);
		if (p.tools?.length) parts.push(`tools:${p.tools.length}`);
		return parts.join(" · ") || "(partial)";
	}

	function updateStatus(ctx: ExtensionContext) {
		ctx.ui.setStatus("xmodel", activeName ? ctx.ui.theme.fg("accent", `⇄ ${activeName}`) : undefined);
	}

	function previewStatus(ctx: ExtensionContext, name: string | undefined, p: Preset) {
		ctx.ui.setStatus("xmodel-edit", ctx.ui.theme.fg("accent", `✎ ${name ?? "new"}: ${describe(p)}`));
	}
	function finishEdit(ctx: ExtensionContext) {
		ctx.ui.setStatus("xmodel-edit", undefined);
	}

	/** provider -> model[] from the live registry (merges built-ins + models.json). */
	function registryByProvider(ctx: ExtensionContext): Map<string, string[]> {
		const avail = (ctx.modelRegistry as any).getAvailable() as Array<{ provider: string; id: string }>;
		const m = new Map<string, string[]>();
		for (const x of avail ?? []) {
			if (!m.has(x.provider)) m.set(x.provider, []);
			m.get(x.provider)!.push(x.id);
		}
		for (const ids of m.values()) ids.sort();
		return m;
	}

	/** Core switcher used by command, hotkey, and the agent tool. */
	async function applyPreset(
		name: string,
		preset: Preset,
		ctx: ExtensionContext,
	): Promise<{ ok: true } | { ok: false; reason: string }> {
		if (activeName === undefined) {
			original = { model: ctx.model, thinkingLevel: pi.getThinkingLevel(), tools: pi.getActiveTools() };
		}
		if (preset.provider && preset.model) {
			const model = ctx.modelRegistry.find(preset.provider, preset.model);
			if (!model) return { ok: false, reason: `model ${preset.provider}/${preset.model} not found` };
			const success = await pi.setModel(model);
			if (!success) ctx.ui.notify(`xmodel: no API key for ${preset.provider}/${preset.model}`, "warning");
		}
		if (preset.thinkingLevel) pi.setThinkingLevel(preset.thinkingLevel);
		if (preset.tools && preset.tools.length > 0) {
			const all = pi.getAllTools().map((t) => t.name);
			const valid = preset.tools.filter((t) => all.includes(t));
			const bad = preset.tools.filter((t) => !all.includes(t));
			if (bad.length) ctx.ui.notify(`xmodel: unknown tools ignored: ${bad.join(", ")}`, "warning");
			if (valid.length) pi.setActiveTools(valid);
		}
		activeName = name;
		activePreset = preset;
		updateStatus(ctx);
		return { ok: true };
	}

	async function clearPreset(ctx: ExtensionContext) {
		activeName = undefined;
		activePreset = undefined;
		if (original) {
			if (original.model) await pi.setModel(original.model);
			pi.setThinkingLevel(original.thinkingLevel);
			pi.setActiveTools(original.tools);
		}
		updateStatus(ctx);
		ctx.ui.notify("xmodel: cleared, defaults restored", "info");
	}

	async function cycle(ctx: ExtensionContext) {
		const names = Object.keys(presets).sort();
		if (!names.length) {
			ctx.ui.notify("xmodel: no presets in xmodel.json", "warning");
			return;
		}
		const list = ["(off)", ...names];
		const cur = activeName ?? "(off)";
		const next = list[(list.indexOf(cur) + 1) % list.length];
		if (next === "(off)") return clearPreset(ctx);
		const r = await applyPreset(next, presets[next], ctx);
		ctx.ui.notify(r.ok ? `xmodel → ${next}` : `xmodel failed: ${r.reason}`, r.ok ? "info" : "error");
	}

	/**
	 * Super-UX preset editor — a single review hub you navigate freely.
	 * Tap any field to edit it, then save (+activate) in one tap. No dead-end
	 * confirms; you can revisit any field before committing.
	 * /xm edit [name]
	 */
	async function wizard(ctx: ExtensionContext, initialName?: string): Promise<void> {
		const byProvider = registryByProvider(ctx);
		if (byProvider.size === 0) {
			ctx.ui.notify("xmodel: no models available in registry", "error");
			return;
		}

		// 1. pick preset
		let name = initialName?.trim();
		if (!name) {
			const items = [NEW, ...Object.keys(presets).sort().map((n) => (activeName === n ? `${n}  (active)` : n))];
			name = (await ctx.ui.select("Edit which preset?", items)) ?? undefined;
			if (!name) return finishEdit(ctx);
		}
		if (name === NEW) {
			name = (await ctx.ui.input("Preset name", "e.g. deep / light-free"))?.trim();
			if (!name) return finishEdit(ctx);
		}

		const draft: Preset = presets[name] ? { ...presets[name] } : {};

		const SEP = "────────────────────────────";
		const SAVE_ACT = "💾   Save & activate";
		const SAVE = "💾   Save";
		const CANCEL = "✖   Cancel";
		const isActive = () => activeName === name;

		const fldProvider = () => `Provider        ${draft.provider ?? "— set —"}`;
		const fldModel = () => `Model           ${draft.model ?? "— set —"}`;
		const fldThink = () => `Thinking        ${draft.thinkingLevel ?? "— set —"}`;
		const fldInstr = () =>
			`Instructions   ${draft.instructions ? `${draft.instructions.length} chars` : "none"}`;

		let activate = false;

		// 2. review hub — loop until save/cancel
		while (true) {
			previewStatus(ctx, name, draft);
			const header = `✎  ${name}      ${describe(draft)}`;
			const items = [
				fldProvider(),
				fldModel(),
				fldThink(),
				fldInstr(),
				SEP,
				...(isActive() ? [] : [SAVE_ACT]),
				SAVE,
				CANCEL,
			];
			const choice = await ctx.ui.select(header, items);

			if (choice === undefined || choice === CANCEL) {
				finishEdit(ctx);
				ctx.ui.notify("xmodel: edit cancelled", "info");
				return;
			}
			if (choice === SEP) continue;
			if (choice === SAVE_ACT) {
				activate = true;
				break;
			}
			if (choice === SAVE) {
				activate = false;
				break;
			}

			// field edits fall back to the hub
			if (choice === fldProvider()) {
				const providers = [...byProvider.keys()].sort();
				const pv = await ctx.ui.select(
					`Provider  ·  ${name}`,
					[draft.provider ? `${KEEP}  (${draft.provider})` : KEEP, ...providers],
				);
				if (pv && !pv.startsWith(KEEP)) {
					draft.provider = pv;
					if (!byProvider.get(pv)?.includes(draft.model ?? "")) draft.model = undefined;
				}
				continue;
			}
			if (choice === fldModel()) {
				if (!draft.provider) {
					ctx.ui.notify("set a provider first", "warning");
					continue;
				}
				const ids = byProvider.get(draft.provider) ?? [];
				if (!ids.length) continue;
				const mp = await ctx.ui.select(
					`Model  ·  ${draft.provider}`,
					[draft.model ? `${KEEP}  (${draft.model})` : KEEP, ...ids],
				);
				if (mp && !mp.startsWith(KEEP)) draft.model = mp;
				continue;
			}
			if (choice === fldThink()) {
				const tp = await ctx.ui.select(
					`Thinking  ·  ${name}`,
					[draft.thinkingLevel ? `${KEEP}  (${draft.thinkingLevel})` : KEEP, ...THINKING_LEVELS],
				);
				if (tp && !tp.startsWith(KEEP)) draft.thinkingLevel = tp as ThinkingLevel;
				continue;
			}
			if (choice === fldInstr()) {
				const edited = await ctx.ui.editor(
					`Instructions for “${name}”  (empty = none)`,
					draft.instructions ?? "",
				);
				draft.instructions = edited?.trim() ? edited.trim() : undefined;
				continue;
			}
		}

		finishEdit(ctx);

		const globalCfg = readRaw(globalPresetsPath());
		globalCfg[name] = draft;
		writeGlobal(globalCfg);
		presets = { ...presets, [name]: draft };
		ctx.ui.notify(`xmodel: saved “${name}” → ${describe(draft)}`, "info");

		if (isActive()) {
			activePreset = draft;
			updateStatus(ctx);
		} else if (activate) {
			const r = await applyPreset(name, draft, ctx);
			ctx.ui.notify(r.ok ? `xmodel → ${name}` : `saved but switch failed: ${r.reason}`, r.ok ? "info" : "warning");
		}
	}

	/** /xm rm [name] */
	async function removePreset(ctx: ExtensionContext, initialName?: string) {
		let name = initialName?.trim();
		if (!name) {
			const existing = Object.keys(readRaw(globalPresetsPath())).sort();
			if (!existing.length) {
				ctx.ui.notify("xmodel: nothing to remove", "info");
				return;
			}
			name = (await ctx.ui.select("Remove which preset?", existing)) ?? undefined;
			if (!name) return;
		}
		const globalCfg = readRaw(globalPresetsPath());
		if (!(name in globalCfg)) {
			ctx.ui.notify(`xmodel: “${name}” not in global xmodel.json`, "warning");
			return;
		}
		if (await ctx.ui.confirm(`Remove “${name}”?`, describe(globalCfg[name]))) {
			delete globalCfg[name];
			writeGlobal(globalCfg);
			delete presets[name];
			if (activeName === name) await clearPreset(ctx);
			ctx.ui.notify(`xmodel: removed “${name}”`, "info");
		}
	}

	/** /xm models [query] — browse provider/model from the registry. */
	async function browseModels(ctx: ExtensionContext, query?: string) {
		const byProvider = registryByProvider(ctx);
		const q = (query ?? "").trim().toLowerCase();
		const keys: string[] = [];
		for (const [pv, ids] of [...byProvider.entries()].sort(([a], [b]) => a.localeCompare(b))) {
			for (const id of ids) {
				const key = `${pv}/${id}`;
				if (!q || key.toLowerCase().includes(q)) keys.push(key);
			}
		}
		if (!keys.length) {
			ctx.ui.notify(q ? `no models match “${q}”` : "no models available", "info");
			return;
		}
		await ctx.ui.select(`Available models (${Math.min(keys.length, 200)} of ${keys.length})`, keys.slice(0, 200));
	}

	// --- 1. Slash command (user): /xm ---
	pi.registerCommand("xm", {
		description: "xmodel v0.1.0 — /xm [name] | /xm edit [name] | /xm rm [name] | /xm models [query] | /xm version | /xm off",
		handler: async (args, ctx) => {
			const raw = (args ?? "").trim();
			const [sub, ...rest] = raw.split(/\s+/);
			const restStr = rest.join(" ");

			if (sub === "edit" || sub === "set") {
				if (!ctx.hasUI) return ctx.ui.notify("xmodel: /xm edit needs interactive mode", "warning");
				return wizard(ctx, restStr || undefined);
			}
			if (sub === "rm" || sub === "remove" || sub === "del") {
				if (!ctx.hasUI) return ctx.ui.notify("xmodel: /xm rm needs interactive mode", "warning");
				return removePreset(ctx, restStr || undefined);
			}
			if (sub === "models" || sub === "list-models" || sub === "ls") {
				if (!ctx.hasUI) return ctx.ui.notify("xmodel: /xm models needs interactive mode", "warning");
				return browseModels(ctx, restStr || undefined);
			}
			if (sub === "version" || sub === "-v" || sub === "--version") {
				return ctx.ui.notify(`xmodel v${VERSION}`, "info");
			}

			const name = raw;
			if (!name) {
				const names = Object.keys(presets).sort();
				if (!names.length) {
					ctx.ui.notify("xmodel: no presets defined", "warning");
					return;
				}
				const choice = await ctx.ui.select(
					"Switch model preset",
					names.map((n) => (activeName === n ? `${n}  (active)` : n)),
				);
				if (!choice) return;
				if (choice === "(off)") return clearPreset(ctx);
				const r = await applyPreset(choice, presets[choice], ctx);
				ctx.ui.notify(r.ok ? `xmodel → ${choice}` : `failed: ${r.reason}`, r.ok ? "info" : "error");
				return;
			}
			if (name === "off" || name === "(off)") return clearPreset(ctx);
			const preset = presets[name];
			if (!preset) {
				ctx.ui.notify(`xmodel: unknown "${name}". Have: ${Object.keys(presets).sort().join(", ")}`, "error");
				return;
			}
			const r = await applyPreset(name, preset, ctx);
			ctx.ui.notify(r.ok ? `xmodel → ${name}` : `failed: ${r.reason}`, r.ok ? "info" : "error");
		},
	});

	// --- 2. Hotkey (user): cycle ---
	pi.registerShortcut("ctrl+shift+f", {
		description: "Cycle xmodel presets",
		handler: (ctx) => cycle(ctx),
	});

	// --- 3. Tool (agent / LLM): switch_model ---
	pi.registerTool({
		name: "switch_model",
		label: "Switch Model",
		description:
			"Switch the active model + thinking-level preset. Use when the user asks to go faster/cheaper, use a vision-capable model, or switch between named modes. Valid names are returned by action='list'.",
		promptSnippet: "Switch model/thinking preset by name",
		promptGuidelines: [
			"Use switch_model with action='list' to discover available presets (deep, light, vision, free variants, etc.), then action='switch' with a name.",
		],
		parameters: Type.Object({
			action: StringEnum(["switch", "list", "off"] as const, {
				description: "'switch' (needs name), 'list', or 'off' to restore defaults",
			}),
			name: Type.Optional(Type.String({ description: "Preset name to switch to (required for action='switch')" })),
		}),
		async execute(_id, params, _signal, _onUpdate, ctx) {
			const action = (params as any).action as "switch" | "list" | "off";

			if (action === "list") {
				const rows = Object.entries(presets)
					.sort(([a], [b]) => a.localeCompare(b))
					.map(([n, p]) => `- ${n}: ${describe(p)}${activeName === n ? "  (active)" : ""}`)
					.join("\n");
				return {
					content: [{ type: "text", text: `Available model presets:\n${rows || "(none)"}` }],
					details: { presets: Object.keys(presets), active: activeName ?? null },
				};
			}
			if (action === "off") {
				await clearPreset(ctx);
				return { content: [{ type: "text", text: "Switched back. Defaults restored." }] };
			}

			const name = (params as any).name as string | undefined;
			if (!name) {
				return { content: [{ type: "text", text: `Missing 'name'. Available: ${Object.keys(presets).sort().join(", ")}` }] };
			}
			const preset = presets[name];
			if (!preset) {
				return { content: [{ type: "text", text: `Unknown preset "${name}". Available: ${Object.keys(presets).sort().join(", ")}` }] };
			}
			const r = await applyPreset(name, preset, ctx);
			if (!r.ok) throw new Error(r.reason);
			return {
				content: [{ type: "text", text: `Switched to "${name}": ${describe(preset)}. Next turn uses the new model.` }],
				details: { preset: name },
			};
		},
	});

	// --- Optional system-prompt instructions for active preset ---
	pi.on("before_agent_start", async (event, ctx) => {
		// auto-vision (switch mode only): user attached images to this prompt
		if (visionCfg.mode === "switch" && event.images && event.images.length > 0) await ensureVision(ctx, "before_agent_start");
		if (activePreset?.instructions) {
			return { systemPrompt: `${event.systemPrompt}\n\n${activePreset.instructions}` };
		}
	});

	// --- vision on tool results containing an image (read *.png, MCP screenshots, …) ---
	pi.on("tool_result", async (event, ctx) => {
		const images = Array.isArray(event.content) ? event.content.filter((p: any) => p && p.type === "image") : [];
		if (images.length === 0) return;
		if (isVisionCapable(ctx.model)) return; // main model sees images natively — nothing to do
		const mode = visionCfg.mode;
		if (mode === "off") return;
		if (mode === "switch") {
			await ensureVision(ctx, "tool_result");
			return;
		}
		// delegate: compress → VLM (own context) → replace image with text analysis
		try {
			return await delegateVision(ctx, event, images);
		} catch (e) {
			debug("delegateVision threw", { err: String(e) });
			ctx.ui.notify(`xmodel: vision delegate failed (${String(e)}) — leaving image as-is`, "warning");
			return undefined;
		}
	});

	// --- restore the pre-auto-vision model when the turn ends ---
	pi.on("agent_end", async (_event, ctx) => {
		debug("agent_end", { autoVisionActive, visionWas: fmt(ctx.model), preAutoVision: fmt(preAutoVisionModel) });
		if (!autoVisionActive) return;
		autoVisionActive = false;
		const target = preAutoVisionModel;
		preAutoVisionModel = undefined;
		ctx.ui.setStatus("xmodel-vision", undefined);
		if (!target) return;
		try {
			const ok = await pi.setModel(target);
			if (!ok) {
				ctx.ui.notify(`xmodel: vision turn done but couldn't restore ${fmt(target)} (no API key) — still on ${fmt(ctx.model)}`, "warning");
			} else {
				ctx.ui.notify(`xmodel: vision turn done → restored ${fmt(target)}`, "info");
			}
		} catch (e) {
			ctx.ui.notify(`xmodel: vision restore failed (${String(e)}) — still on ${fmt(ctx.model)}`, "warning");
		}
		updateStatus(ctx);
	});

	/**
	 * Resolve a fallback preset on rate-limit / overload.
	 * Order: explicit preset.fallback → `${activeName}-free` → any *free* preset
	 * whose model differs from the current one.
	 */
	function resolveFallback(ctx: ExtensionContext): { name: string; preset: Preset } | undefined {
		const curProvider = ctx.model?.provider;
		const curModel = ctx.model?.id;
		const different = (p: Preset) => p.provider && p.model && !(p.provider === curProvider && p.model === curModel);
		if (activeName) {
			const cur = presets[activeName];
			for (const n of [cur?.fallback, `${activeName}-free`]) {
				if (!n) continue;
				const p = presets[n];
				if (p && different(p)) return { name: n, preset: p };
			}
		}
		for (const n of Object.keys(presets).sort()) {
			if (!/free/i.test(n)) continue;
			const p = presets[n];
			if (different(p)) return { name: n, preset: p };
		}
		return undefined;
	}

	const RATE_LIMIT_STATUSES = new Set([429, 503, 529]);

	// --- rate-limit fallback: switch to a free variant automatically ---
	pi.on("after_provider_response", async (event, ctx) => {
		if (!RATE_LIMIT_STATUSES.has(event.status)) return;
		if (Date.now() - lastFallbackAt < FALLBACK_COOLDOWN_MS) return; // avoid flapping

		const was = `${ctx.model?.provider ?? "?"}/${ctx.model?.id ?? "?"}`;
		const fb = resolveFallback(ctx);
		if (!fb || !fb.preset.provider || !fb.preset.model) {
			ctx.ui.notify(
				`xmodel: ${was} rate-limited (${event.status}) — no fallback configured. Add a *free* preset or set "fallback" on this preset.`,
				"warning",
			);
			return;
		}
		const fbModel = ctx.modelRegistry.find(fb.preset.provider, fb.preset.model);
		if (!fbModel) {
			ctx.ui.notify(`xmodel: fallback ${fb.preset.provider}/${fb.preset.model} not in registry`, "warning");
			return;
		}
		if (fbModel.provider === ctx.model?.provider && fbModel.id === ctx.model?.id) {
			ctx.ui.notify(`xmodel: ${was} rate-limited and already on the best fallback — try again later`, "warning");
			return;
		}

		const ok = await pi.setModel(fbModel);
		lastFallbackAt = Date.now();
		if (!ok) {
			ctx.ui.notify(`xmodel: fallback ${fb.preset.provider}/${fb.preset.model} has no API key`, "warning");
			return;
		}
		// adopt the fallback as the active preset (thinking/tools apply)
		activeName = fb.name;
		activePreset = fb.preset;
		if (fb.preset.thinkingLevel) pi.setThinkingLevel(fb.preset.thinkingLevel);
		const ra = event.headers?.["retry-after"] ?? event.headers?.["Retry-After"];
		ctx.ui.setStatus("xmodel-fallback", ctx.ui.theme.fg("warning", `↩ fallback: ${fb.name}`));
		ctx.ui.notify(
			`xmodel: ${was} rate-limited (${event.status}) → fell back to “${fb.name}” (${fb.preset.provider}/${fb.preset.model})${ra ? ` · retry-after ${ra}s` : ""}`,
			"warning",
		);
		updateStatus(ctx);
	});

	/** Reconstruct active preset from session entries. Safe to call from any lifecycle handler. */
	function reconstructActive(ctx: ExtensionContext) {
		const entries = ctx.sessionManager.getEntries();
		const last = entries
			.filter((e: any) => e.type === "custom" && e.customType === "xmodel-state")
			.pop() as { data?: { name: string } } | undefined;
		if (last?.data?.name && presets[last.data.name]) {
			activeName = last.data.name;
			activePreset = presets[last.data.name];
		} else {
			activeName = undefined;
			activePreset = undefined;
		}
		updateStatus(ctx);
	}

	function isStaleCtxError(e: unknown): boolean {
		return /stale after session replacement/i.test(String(e));
	}

	function isVisionCapable(m: Model<Api> | undefined): boolean {
		return !!m && Array.isArray((m as any).input) && (m as any).input.includes("image");
	}

	/** Pick a vision-capable model: prefer a *vision* preset, else any image-capable model. */
	function pickVisionModel(ctx: ExtensionContext): Model<Api> | undefined {
		// 1. a preset whose name contains "vision" and whose model is image-capable
		for (const n of Object.keys(presets)) {
			if (!/vision/i.test(n)) continue;
			const p = presets[n];
			if (!p.provider || !p.model) continue;
			const m = ctx.modelRegistry.find(p.provider, p.model);
			if (m && isVisionCapable(m)) return m;
		}
		// 2. any available model with image input
		const avail = (ctx.modelRegistry as any).getAvailable() as Model<Api>[];
		return avail.find((m) => isVisionCapable(m));
	}

	/** Transiently switch to a vision model if the current one can't see images. */
	async function ensureVision(ctx: ExtensionContext, source: string): Promise<void> {
		debug(`ensureVision(${source})`, { autoVisionActive, cur: fmt(ctx.model), visionCapable: isVisionCapable(ctx.model) });
		if (autoVisionActive) return; // already switched this turn
		if (isVisionCapable(ctx.model)) return; // already vision-capable
		const vision = pickVisionModel(ctx);
		if (!vision) {
			ctx.ui.notify("xmodel: image present but no vision-capable model available", "warning");
			return;
		}
		preAutoVisionModel = ctx.model;
		debug(`ensureVision(${source}) SWITCH`, { from: fmt(ctx.model), to: fmt(vision) });
		const ok = await pi.setModel(vision);
		if (!ok) {
			ctx.ui.notify(`xmodel: couldn't switch to vision (${vision.provider}/${vision.id}) — no API key`, "warning");
			return;
		}
		autoVisionActive = true;
		ctx.ui.setStatus("xmodel-vision", ctx.ui.theme.fg("accent", `👁 auto-vision: ${vision.provider}/${vision.id}`));
		ctx.ui.notify(`xmodel: auto vision → ${vision.provider}/${vision.id}`, "info");
	}

	// =========================================================================
	// Vision delegation pipeline:  compress → VLM (own context) → text feedback
	// =========================================================================
	const COMPRESSOR_TIMEOUT_MS = 30_000;
	const VLM_TIMEOUT_MS = 90_000;
	const VISION_BRIEF_SYS =
		"You write a focused query for a vision model. Given the coding-agent conversation, output ONLY what the vision model should examine/answer about the upcoming image — the task goal plus any specific things to check. No preamble, no code dumps. Respect the char budget.";
	const VISION_VLM_SYS =
		"You are a vision analyst embedded in a coding agent. Given a task brief and one image, report concrete, actionable observations about the image in service of the task (UI state, visible text, errors, layout, discrepancies, colours). Be precise and concise. Output only the analysis.";

	function runChildPi(opts: { model: string; systemPrompt: string; prompt: string; imageFile?: string; timeoutMs?: number }): Promise<string> {
		return new Promise((resolve) => {
			// --mode json -p (NOT bare --print): text mode tries TUI init that hangs on piped stdout.
			// This is the same recipe the official pi-subagents package uses.
			const args = [
				"--mode", "json", "-p",
				"--no-tools", "--no-extensions", "--no-context-files",
				"--no-skills", "--no-prompt-templates", "--no-themes",
				"--model", opts.model,
				"--system-prompt", opts.systemPrompt,
			];
			if (opts.imageFile) args.push(`@${opts.imageFile}`);
			args.push(opts.prompt);
			const timeoutMs = opts.timeoutMs ?? VLM_TIMEOUT_MS;
			debug("runChildPi", { model: opts.model, hasImage: !!opts.imageFile, promptLen: opts.prompt.length, timeoutMs });
			const proc = spawn("pi", args, { stdio: ["ignore", "pipe", "pipe"], env: { ...process.env, NO_COLOR: "1" } });
			let out = "";
			const timer = setTimeout(() => proc.kill("SIGTERM"), timeoutMs);
			proc.stdout.on("data", (d: Buffer) => {
				out += d.toString();
				if (out.length > 8 << 20) proc.kill(); // cap memory
			});
			const finish = (reason: string) => {
				clearTimeout(timer);
				const text = extractFinalAssistantText(out);
				debug("runChildPi done", { model: opts.model, reason, outLen: out.length, textLen: text.length });
				resolve(text);
			};
			proc.on("close", () => finish("close"));
			proc.on("error", () => finish("error"));
		});
	}

	/** Parse JSONL stdout from `pi --mode json -p`; pull the last assistant text from the agent_end event. */
	function extractFinalAssistantText(jsonl: string): string {
		const lines = jsonl.split("\n");
		let agentEnd: any = undefined;
		for (let i = lines.length - 1; i >= 0; i--) {
			const line = lines[i].trim();
			if (!line) continue;
			try {
				const j = JSON.parse(line);
				if (j && j.type === "agent_end") { agentEnd = j; break; }
			} catch {}
		}
		const msgs: any[] = Array.isArray(agentEnd?.messages) ? agentEnd.messages : [];
		for (let i = msgs.length - 1; i >= 0; i--) {
			const m = msgs[i];
			if (m && m.role === "assistant") {
				const c = m.content;
				if (typeof c === "string") return c.trim();
				if (Array.isArray(c)) return c.filter((b: any) => b && b.type === "text").map((b: any) => b.text || "").join(" ").trim();
			}
		}
		return "";
	}

	function textOf(content: unknown): string {
		if (typeof content === "string") return content;
		if (Array.isArray(content)) {
			return content.filter((b: any) => b && b.type === "text").map((b: any) => b.text || "").join(" ");
		}
		return "";
	}

	/** Heuristic gather of recent user/assistant text to feed the compressor. */
	function gatherRecentContext(ctx: ExtensionContext, maxChars = 8000): string {
		const entries: any[] = (ctx.sessionManager as any).getEntries() ?? [];
		const msgs: string[] = [];
		for (const e of entries) {
			if (!e || e.type !== "message") continue;
			const m = e.message;
			if (!m) continue;
			const role = m.role;
			if (role !== "user" && role !== "assistant") continue;
			const t = textOf(m.content);
			if (!t) continue;
			msgs.push(`${role === "user" ? "USER" : "ASSISTANT"}: ${t}`);
		}
		let out = "";
		for (const s of msgs.slice(-6)) {
			const piece = s.length > 700 ? `${s.slice(0, 700)}…` : s;
			if (out.length + piece.length > maxChars) break;
			out += `${piece}\n`;
		}
		return out.trim();
	}

	/** Build a small task brief: the CURRENT main model writes a focused query for the VLM.
	 *  Defaults to the active model (it understands the task best and is reliable);
	 *  _vision.compressor overrides. Returns null if no model or it failed/timed out. */
	async function buildBrief(ctx: ExtensionContext, cfg: VisionConfig): Promise<string | null> {
		const compressor = cfg.compressor ?? (ctx.model ? `${(ctx.model as any).provider}/${(ctx.model as any).id}` : undefined);
		if (!compressor) return null;
		const raw = gatherRecentContext(ctx, cfg.maxBriefChars * 4);
		debug("buildBrief", { compressor, rawLen: raw.length });
		const brief = await runChildPi({
			model: compressor,
			systemPrompt: VISION_BRIEF_SYS,
			prompt: `Char budget: ${cfg.maxBriefChars}. Write the vision query for the conversation below.\n\n---\n${raw}\n---`,
			timeoutMs: COMPRESSOR_TIMEOUT_MS,
		});
		if (!brief) { debug("buildBrief failed/timeout → abort", { compressor }); return null; }
		return brief.slice(0, cfg.maxBriefChars * 2);
	}

	function writeImageTmp(img: any): string {
		const mt = (img.mimeType || "image/png") as string;
		const ext = mt.includes("png") ? "png" : mt.includes("jpeg") || mt.includes("jpg") ? "jpg" : "png";
		const p = join("/tmp", `xmodel-vision-${Date.now()}-${Math.random().toString(36).slice(2, 8)}.${ext}`);
		writeFileSync(p, Buffer.from(img.data, "base64"));
		return p;
	}

	/** Resolve the VLM ref string: explicit config, else auto-pick from registry. */
	function resolveVlm(ctx: ExtensionContext): string | undefined {
		if (visionCfg.vlm) return visionCfg.vlm;
		const m = pickVisionModel(ctx);
		return m ? `${(m as any).provider}/${(m as any).id}` : undefined;
	}

	/**
	 * Delegate vision to a sub-model with a COMPRESSED context:
	 * compress → [brief + image] → VLM → analysis text. Returns replacement tool_result content.
	 * The main model never switches; it only ever sees the VLM's text analysis.
	 */
	async function delegateVision(ctx: ExtensionContext, event: any, images: any[]): Promise<{ content: any[] } | undefined> {
		const vlm = resolveVlm(ctx);
		if (!vlm) {
			ctx.ui.notify("xmodel: image present but no vision model configured (set _vision.vlm)", "warning");
			return undefined;
		}
		ctx.ui.setStatus("xmodel-vision", ctx.ui.theme.fg("accent", `👁 vision delegate → ${vlm}`));
		ctx.ui.notify(`xmodel: vision delegate → compressing context + ${vlm} …`, "info");

		const brief = await buildBrief(ctx, visionCfg);
		if (brief === null) {
			const reason = !visionCfg.compressor ? "no _vision.compressor set" : "compressor timed out / failed";
			ctx.ui.setStatus("xmodel-vision", undefined);
			ctx.ui.notify(`xmodel: vision delegate aborted (${reason}) — leaving image as-is`, "warning");
			return undefined;
		}
		debug("delegateVision", { vlm, compressor: visionCfg.compressor, briefLen: brief.length, images: images.length });

		const analyses: string[] = [];
		for (const img of images) {
			let tmp: string | undefined;
			try {
				tmp = writeImageTmp(img);
				const analysis = await runChildPi({
					model: vlm,
					systemPrompt: VISION_VLM_SYS,
					prompt: `Task brief:\n${brief}\n\nAnalyze the attached image in service of this task and report concrete findings.`,
					imageFile: tmp,
				});
				analyses.push(analysis || "(vision model returned no analysis)");
			} finally {
				if (tmp) {
					try { unlinkSync(tmp); } catch {}
				}
			}
		}

		// replace each image block with its text analysis; keep non-image blocks intact
		const newContent: any[] = [];
		let idx = 0;
		for (const block of event.content as any[]) {
			if (block && block.type === "image") {
				const a = analyses[idx++] ?? "(vision analysis failed)";
				newContent.push({ type: "text", text: `[xmodel vision · ${vlm}]: ${a}` });
			} else {
				newContent.push(block);
			}
		}
		ctx.ui.setStatus("xmodel-vision", undefined);
		ctx.ui.notify(`xmodel: vision delegate done (${images.length} img → ${vlm})`, "info");
		return { content: newContent };
	}

	// --- Load + restore on session start ---
	pi.on("session_start", async (_event, ctx) => {
		presets = loadPresets(ctx.cwd, ctx.isProjectTrusted());
		visionCfg = loadVisionConfig(ctx.cwd, ctx.isProjectTrusted());
		reconstructActive(ctx);
	});

	// --- Reconstruct on tree navigation / compaction (branching) ---
	pi.on("session_tree", async (_event, ctx) => {
		try {
			reconstructActive(ctx);
		} catch (e) {
			if (!isStaleCtxError(e)) throw e;
		}
	});

	pi.on("session_compact", async (_event, ctx) => {
		try {
			reconstructActive(ctx);
		} catch (e) {
			if (!isStaleCtxError(e)) throw e;
		}
	});

	// --- Persist ---
	pi.on("turn_start", async () => {
		if (activeName) pi.appendEntry("xmodel-state", { name: activeName });
	});
}
