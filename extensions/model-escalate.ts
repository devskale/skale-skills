/**
 * model-escalate — failure detection + model ladder escalation.
 *
 * Small models fail in recognizable patterns (tool-calling skills, MCP-guessing,
 * repeated command failures). This extension watches `tool_result`, counts strikes
 * per failure signature, and escalates UP a configurable model ladder instead of
 * letting the session grind. Known low-value failure classes (skill/tool confusion)
 * get a one-shot hint injected first — switching models for a missing pointer is waste.
 *
 * Ladder source: `ctx.scopedModels` (the same list /scoped-models shows), else
 * `ctx.modelRegistry.getAvailable()`. Escalation = next rung; never auto-downgrades.
 * A manual `/model` change resets strikes (the human took over).
 *
 * Config (settings.json → "modelEscalate"):
 *   enabled        bool (default true)
 *   strikes        strikes needed before escalation (default 3)
 *   windowMinutes  strike window (default 10)
 *   ladder         string[] of "provider/modelId" overrides (default: scoped models)
 *   signatures     extra regex strings treated as failures (default: MCP/tool-not-found)
 *   hint           bool — inject the skill-confusion hint before escalating (default true)
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

interface Strike {
	signature: string;
	at: number;
}

interface EscalateConfig {
	enabled: boolean;
	strikes: number;
	windowMinutes: number;
	ladder: string[];
	signatures: string[];
	hint: boolean;
}

const DEFAULT_SIGNATURES = [
	'Tool ".*" not found',
	'Server ".*" not found',
	"No such tool",
	"Unknown tool",
];

const SKILL_HINT =
	"Hint: skills are NOT tools or MCP servers. If a skill matches the task, read its " +
	"SKILL.md (skill directory / skill command docs) and run the shell command it " +
	"documents via your bash/run tool — e.g. `web-search \"query\"`, `fetch-url \"url\"`.";

const DEFAULT_CONFIG: EscalateConfig = {
	enabled: true,
	strikes: 3,
	windowMinutes: 10,
	ladder: [],
	signatures: [],
	hint: true,
};

/** Failure signatures (lowercased substring/regex) that count as strikes. */
function signatureMatches(text: string, cfg: EscalateConfig): string | null {
	const haystack = text.toLowerCase();
	const patterns = [...DEFAULT_SIGNATURES, ...cfg.signatures];
	for (const pattern of patterns) {
		if (haystack.includes(pattern.toLowerCase())) return pattern;
	}
	return null;
}

function withinWindow(strike: Strike, now: number, cfg: EscalateConfig): boolean {
	return now - strike.at <= cfg.windowMinutes * 60_000;
}

export default function modelEscalateExtension(pi: ExtensionAPI) {
	const cfg: EscalateConfig = { ...DEFAULT_CONFIG };
	let strikes: Strike[] = [];
	let hintInjected = false;
	let escalatedTo: string | null = null;

	// Load config from settings.json (global settings object is exposed via ctx at
	// event time; we read lazily in handlers via ctx.config fallback).
	function mergeConfig(settings: Record<string, unknown> | undefined): void {
		const section = (settings?.modelEscalate ?? {}) as Partial<EscalateConfig>;
		if (typeof section.enabled === "boolean") cfg.enabled = section.enabled;
		if (typeof section.strikes === "number") cfg.strikes = section.strikes;
		if (typeof section.windowMinutes === "number") cfg.windowMinutes = section.windowMinutes;
		if (Array.isArray(section.ladder)) cfg.ladder = section.ladder;
		if (Array.isArray(section.signatures)) cfg.signatures = section.signatures;
		if (typeof section.hint === "boolean") cfg.hint = section.hint;
	}

	/** The escalation ladder: scoped models (session contract) or explicit override. */
	function ladderOf(ctx: any): Array<{ provider: string; id: string; label: string }> {
		const scoped = (ctx.scopedModels ?? []) as Array<{ model: any; thinkingLevel?: string }>;
		if (cfg.ladder.length > 0) {
			return cfg.ladder
				.map((raw) => {
					const [provider, id] = raw.includes("/") ? raw.split("/", 2) : ["", raw];
					const found = ctx.modelRegistry?.find(provider || undefined, id) ?? null;
					return found ? { provider: found.provider, id: found.id, label: `${found.provider}/${found.id}` } : null;
				})
				.filter((x): x is { provider: string; id: string; label: string } => x !== null);
		}
		return scoped.map((s) => ({
			provider: s.model.provider,
			id: s.model.id,
			label: `${s.model.provider}/${s.model.id}`,
		}));
	}

	function currentLabel(ctx: any): string {
		const m = ctx.model as { provider?: string; id?: string } | undefined;
		return m ? `${m.provider ?? ""}/${m.id ?? ""}` : "";
	}

	async function escalate(ctx: any, reason: string): Promise<void> {
		const ladder = ladderOf(ctx).filter((r) => r.label !== currentLabel(ctx));
		const rung = ladder.find((r) => !isAtOrAbove(r.label));
		if (!rung) {
			pi.appendEntry("model-escalate", { type: "exhausted", reason, at: currentLabel(ctx) });
			ctx.ui?.setStatus?.("model-escalate", "ladder exhausted");
			return;
		}
		const model = ctx.modelRegistry?.find(rung.provider, rung.id);
		if (!model) return;
		const ok = await pi.setModel(model);
		if (!ok) {
			ctx.ui?.notify?.(`escalate: no auth for ${rung.label}`, "error");
			return;
		}
		escalatedTo = rung.label;
		strikes = []; // fresh start on the bigger model
		pi.appendEntry("model-escalate", { type: "escalated", to: rung.label, reason });
		ctx.ui?.setStatus?.(
			"model-escalate",
			ctx.ui?.theme?.fg?.("accent", `⇧ escalated → ${rung.label}`) ?? `⇧ escalated → ${rung.label}`,
		);
		pi.sendMessage({ customType: "model-escalate", content: `[model-escalate] Switched to ${rung.label} after repeated failures (${reason}). Retry the current task here.`, display: true });
	}

	function isAtOrAbove(label: string): boolean {
		// A rung is "at or above" current if it already appears in the escalated trail.
		return label === escalatedTo;
	}

	pi.on("session_start", async (_event, ctx) => {
		mergeConfig((ctx as any).settings as Record<string, unknown> | undefined);
	});

	pi.on("tool_result", async (event, ctx) => {
		if (!cfg.enabled) return;
		const text = [
			typeof event.content === "string" ? event.content : JSON.stringify(event.content ?? ""),
			event.isError ? "isError" : "",
		]
			.join(" ")
			.slice(0, 4000);
		const signature = signatureMatches(text, cfg);
		const bashFailed = event.toolName === "bash" && event.isError === true;
		if (!signature && !bashFailed) return;

		const now = Date.now();
		const sig = signature ?? (event.toolName === "bash" ? "bash-error" : "unknown");
		strikes = strikes.filter((s) => withinWindow(s, now, cfg));
		strikes.push({ signature: sig, at: now });

		// Known cheap fix first: skill/tool confusion gets a hint once, not a switch.
		if (cfg.hint && !hintInjected && /not found|no such tool|unknown tool/i.test(sig)) {
			hintInjected = true;
			pi.sendMessage({ customType: "model-escalate", content: `[model-escalate] ${SKILL_HINT}`, display: true });
			ctx.ui?.setStatus?.("model-escalate", "hint injected (skill/tool confusion)");
			return;
		}

		if (strikes.length >= cfg.strikes) {
			const reason = strikes.map((s) => s.signature).join(", ");
			await escalate(ctx, reason);
		} else {
			ctx.ui?.setStatus?.("model-escalate", `strike ${strikes.length}/${cfg.strikes}: ${sig}`);
		}
	});

	// Human took over via /model → reset strikes.
	pi.on("model_select", async (_event, ctx) => {
		strikes = [];
		hintInjected = false;
		ctx.ui?.setStatus?.("model-escalate", undefined);
	});

	pi.registerCommand("escalate", {
		description: "Show model-escalate strikes/level; --reset clears",
		handler: async (args: string, ctx: any) => {
			const now = Date.now();
			strikes = strikes.filter((s) => withinWindow(s, now, cfg));
			if (args.includes("--reset")) {
				strikes = [];
				hintInjected = false;
				escalatedTo = null;
				ctx.ui?.notify?.("model-escalate: reset", "info");
				return;
			}
			ctx.ui?.notify?.(
				`model-escalate: ${strikes.length}/${cfg.strikes} strikes` +
					(escalatedTo ? ` · escalated → ${escalatedTo}` : "") +
					` · ladder: ${ladderOf(ctx).map((r) => r.label).join(" → ") || "(scoped models)"}`,
				"info",
			);
		},
	});
}
