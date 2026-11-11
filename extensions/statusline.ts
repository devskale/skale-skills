/**
 * Status Line Extension — machine name + built-in footer parity + Z.ai usage
 *
 * Content parity with the built-in footer (same token/context/model rendering),
 * with intentional changes vs. the built-in:
 *
 *   Line 1: machineName prepended and ALWAYS kept first →
 *             jMacAir ~/code/my-project (main) • session-name
 *           On narrow terminals, progressively drops session → branch,
 *           then truncates cwd, but never the machine name.
 *
 *   Line 2 right: Z.ai usage LEADS the right cluster so it survives truncation:
 *             zai 6% (4h09m) glm-5.1 • low
 *           The redundant "(zai)" provider prefix is dropped when on Z.ai.
 *           % is color-coded: accent < 50% ≤ warning < 80% ≤ error.
 *
 *   Line 2 left: stats ↑↓W $cost | R CH | ctx% — re-grouped to support
 *           progressive skip on narrow terminals: (auto) → CH → R.
 *
 * Mirrors built-in features:
 *   - `xp` marker when PI_EXPERIMENTAL=1 (pi ≥ 0.79.5)
 *   - context % coloring (warning >70%, error >90%)
 *   - cache-hit rate (CH), cache read/write (R/W), cost with (sub) indicator
 *   - extension statuses on line 3
 *
 * "(auto)" is appended after the context % only when auto-compaction is actually
 * enabled. ExtensionContext does not expose `session.autoCompactionEnabled`
 * (ReadonlySessionManager is a 15-method Pick without settings access), so we
 * read the same source of truth the settings manager uses — the merged
 * `compaction.enabled` flag from the user + project settings files — and cache
 * it per session. Default is enabled (pi's own default when the key is absent).
 */

import { execSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { hostname } from "node:os";
import { isAbsolute, relative, resolve, sep } from "node:path";
import type { AssistantMessage } from "@earendil-works/pi-ai";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

// ── Machine name (cached once) ────────────────────────────────────────────────
const machineName = (() => {
	try {
		if (process.platform === "darwin") {
			return execSync("scutil --get ComputerName", { encoding: "utf8" }).trim();
		}
		if (process.platform === "win32") {
			return execSync("hostname", { encoding: "utf8" }).trim();
		}
	} catch {
		// fallback
	}
	return hostname().replace(/\.local$/, "");
})();

// Mirrors pi core's areExperimentalFeaturesEnabled() (not in public exports).
const isExperimental = process.env.PI_EXPERIMENTAL === "1";

// ── Helpers (cloned from built-in footer.js) ──────────────────────────────────

function sanitizeStatusText(text: string): string {
	return text
		.replace(/[\r\n\t]/g, " ")
		.replace(/ +/g, " ")
		.trim();
}

function formatTokens(count: number): string {
	if (count < 1000) return count.toString();
	if (count < 10000) return `${(count / 1000).toFixed(1)}k`;
	if (count < 1_000_000) return `${Math.round(count / 1000)}k`;
	if (count < 10_000_000) return `${(count / 1_000_000).toFixed(1)}M`;
	return `${Math.round(count / 1_000_000)}M`;
}

function formatCwdForFooter(cwd: string, home: string): string {
	if (!home) return cwd;
	const resolvedCwd = resolve(cwd);
	const resolvedHome = resolve(home);
	const relativeToHome = relative(resolvedHome, resolvedCwd);
	const isInsideHome =
		relativeToHome === "" ||
		(relativeToHome !== ".." && !relativeToHome.startsWith(`..${sep}`) && !isAbsolute(relativeToHome));
	if (!isInsideHome) return cwd;
	return relativeToHome === "" ? "~" : `~${sep}${relativeToHome}`;
}

const HOME = process.env.HOME || process.env.USERPROFILE || "";

/** Pick a theme color for a quota usage percentage (shared: Z.ai + uniinfer). */
function quotaColor(pct: number): string {
	if (pct >= 80) return "error";
	if (pct >= 50) return "warning";
	return "accent";
}

// ── Auto-compaction flag (read from the settings files, cached) ───────────────
// pi's own default is `true` when the key is absent (settingsManager:
// `compaction?.enabled ?? true`), so an unreadable file means "enabled".
let autoCompactionCache: { enabled: boolean; at: number } | undefined;
const AUTO_COMPACTION_TTL_MS = 60_000;

function readAutoCompactionEnabled(cwd: string): boolean {
	const now = Date.now();
	if (autoCompactionCache && now - autoCompactionCache.at < AUTO_COMPACTION_TTL_MS) {
		return autoCompactionCache.enabled;
	}
	let enabled = true; // pi's default when the key is missing
	const home = process.env.HOME || process.env.USERPROFILE || "";
	const candidates = [
		home ? join(home, ".pi", "agent", "settings.json") : "",
		cwd ? join(cwd, ".pi", "settings.json") : "",
	];
	for (const file of candidates) {
		if (!file || !existsSync(file)) continue;
		try {
			const parsed = JSON.parse(readFileSync(file, "utf8")) as { compaction?: { enabled?: unknown } };
			if (typeof parsed.compaction?.enabled === "boolean") enabled = parsed.compaction.enabled;
		} catch {
			/* unreadable/invalid settings: keep the previous value */
		}
	}
	autoCompactionCache = { enabled, at: now };
	return enabled;
}

// ── Z.ai usage ────────────────────────────────────────────────────────────────

const ZAI_USAGE_API_URL = "https://api.z.ai/api/monitor/usage/quota/limit";
const ZAI_FETCH_COOLDOWN_MS = 30_000;
const ZAI_FETCH_TIMEOUT_MS = 8_000;
const ZAI_PERIODIC_REFRESH_MS = 3 * 60_000; // keep time-to-window fresh while idle

interface ZaiUsage {
	percentage: number;
	usage: number;
	timeRemaining?: string;
}

function isZaiProvider(provider: string | undefined): boolean {
	return provider?.toLowerCase().startsWith("zai") ?? false;
}

function formatTimeRemainingFromEpochMs(ms: number): string {
	const now = Date.now();
	if (ms < now) return "0m";
	const totalSeconds = Math.round((ms - now) / 1000);
	const hours = Math.floor(totalSeconds / 3600);
	const minutes = Math.floor((totalSeconds % 3600) / 60);
	if (hours > 0) return `${hours}h${String(minutes).padStart(2, "0")}m`;
	if (minutes > 0) return `${minutes}m`;
	return `${totalSeconds}s`;
}

async function fetchZaiUsage(modelRegistry: {
	getApiKeyForProvider(p: string): Promise<string | undefined>;
}): Promise<ZaiUsage | undefined> {
	const apiKey = await modelRegistry.getApiKeyForProvider("zai");
	if (!apiKey) return undefined;
	const response = await fetch(ZAI_USAGE_API_URL, {
		headers: { Authorization: `Bearer ${apiKey}` },
		signal: AbortSignal.timeout(ZAI_FETCH_TIMEOUT_MS),
	});
	if (!response.ok) return undefined;
	const data = (await response.json()) as {
		data: {
			limits: Array<{
				type: string;
				percentage: number;
				usage?: number;
				nextResetTime?: number;
			}>;
		};
	};
	const tokensLimit = data.data.limits.find((l) => l.type === "TOKENS_LIMIT");
	if (!tokensLimit) return undefined;
	const result: ZaiUsage = {
		percentage: tokensLimit.percentage,
		usage: typeof tokensLimit.usage === "number" ? tokensLimit.usage : 0,
	};
	if (tokensLimit.nextResetTime) {
		result.timeRemaining = formatTimeRemainingFromEpochMs(tokensLimit.nextResetTime);
	}
	return result;
}

// ── uniinfer usage (uniinfer.skale.dev/v1/usage — proxy-counted Aqueduct windows) ──

const UNII_USAGE_API_URL = "https://uniinfer.skale.dev/v1/usage";
const UNII_FETCH_COOLDOWN_MS = 30_000;
const UNII_FETCH_TIMEOUT_MS = 8_000;

interface UniUsage {
	pct: number;
	resetIn?: string;
}

function isUniiProvider(provider: string | undefined): boolean {
	return provider?.toLowerCase().startsWith("unii") ?? false;
}

async function fetchUniUsage(
	modelRegistry: {
		getApiKeyForProvider(p: string): Promise<string | undefined>;
	},
	modelId?: string,
): Promise<UniUsage | undefined> {
	const apiKey = await modelRegistry.getApiKeyForProvider("unii");
	if (!apiKey) return undefined;
	const response = await fetch(UNII_USAGE_API_URL, {
		headers: { Authorization: `Bearer ${apiKey}` },
		signal: AbortSignal.timeout(UNII_FETCH_TIMEOUT_MS),
	});
	if (!response.ok) return undefined;
	const data = (await response.json()) as {
		windows?: Record<string, { used?: number; limit?: number; reset_at?: string }>;
		providers?: Record<
			string,
			{ pool?: { used?: Record<string, number>; limits?: Record<string, number | null> } }
		>;
	};
	const windows = data.windows;
	if (!windows) return undefined;
	// Preferred: the CURRENT model's upstream provider pool (e.g. tu@… → "tu"),
	// worst window vs that pool's own limits (each upstream key carries its own
	// quota; the pool sums them — Aqueduct 2×50/1500/15000 with two TU keys).
	// No provider suffix in the label — the model id (tu@…) already shows it.
	const prefix = modelId?.includes("@") ? modelId.split("@")[0] : undefined;
	const pool = prefix ? data.providers?.[prefix]?.pool : undefined;
	if (pool?.used && pool.limits) {
		let bestPct = -1;
		let bestWindow: string | undefined;
		for (const w of Object.keys(pool.limits)) {
			const used = pool.used[w];
			const limit = pool.limits[w];
			if (typeof used !== "number" || typeof limit !== "number" || limit <= 0) continue;
			const pct = (used / limit) * 100;
			if (pct > bestPct) {
				bestPct = pct;
				bestWindow = w;
			}
		}
		if (bestWindow !== undefined && bestPct >= 0) {
			const result: UniUsage = { pct: bestPct };
			// Reset boundaries are calendar-aligned (full minute/hour, midnight UTC
			// for Aqueduct) — the aggregate windows carry the same reset_at.
			const resetAt = windows[bestWindow]?.reset_at;
			if (resetAt) {
				const epoch = Date.parse(resetAt);
				if (!Number.isNaN(epoch)) result.resetIn = formatTimeRemainingFromEpochMs(epoch);
			}
			return result;
		}
	}
	// Fallback: aggregate windows across all providers (proxy total in
	// TU-shaped buckets) — Richtwert, not provider truth.
	let best: { pct: number; resetAt?: string } | undefined;
	for (const w of Object.values(windows)) {
		if (typeof w.used !== "number" || typeof w.limit !== "number" || w.limit <= 0) continue;
		const pct = (w.used / w.limit) * 100;
		if (!best || pct > best.pct) best = { pct, resetAt: w.reset_at };
	}
	if (!best) return undefined;
	const result: UniUsage = { pct: best.pct };
	if (best.resetAt) {
		const epoch = Date.parse(best.resetAt);
		if (!Number.isNaN(epoch)) result.resetIn = formatTimeRemainingFromEpochMs(epoch);
	}
	return result;
}

// ── Extension entry point ─────────────────────────────────────────────────────

interface TuiLike {
	requestRender(): void;
}

export default function (pi: ExtensionAPI) {
	let cachedZaiUsage: ZaiUsage | undefined;
	let lastZaiFetchTime = 0;
	let cachedUniUsage: UniUsage | undefined;
	let lastUniFetchTime = 0;
	let periodicTimer: ReturnType<typeof setInterval> | undefined;
	let tuiRef: TuiLike | undefined;

	async function refreshZaiUsage(
		ctx: {
			model?: { provider: string } | undefined;
			modelRegistry: { getApiKeyForProvider(p: string): Promise<string | undefined> };
		},
		force = false,
	): Promise<ZaiUsage | undefined> {
		if (!isZaiProvider(ctx.model?.provider)) {
			cachedZaiUsage = undefined;
			return undefined;
		}
		const now = Date.now();
		if (!force && cachedZaiUsage && now - lastZaiFetchTime < ZAI_FETCH_COOLDOWN_MS) {
			return cachedZaiUsage;
		}
		try {
			cachedZaiUsage = await fetchZaiUsage(ctx.modelRegistry);
			lastZaiFetchTime = now;
			tuiRef?.requestRender();
		} catch {
			// keep previous cache on error
		}
		return cachedZaiUsage;
	}

	async function refreshUniUsage(
		ctx: {
			model?: { provider: string; id?: string } | undefined;
			modelRegistry: { getApiKeyForProvider(p: string): Promise<string | undefined> };
		},
		force = false,
	): Promise<UniUsage | undefined> {
		if (!isUniiProvider(ctx.model?.provider)) {
			cachedUniUsage = undefined;
			return undefined;
		}
		const now = Date.now();
		if (!force && cachedUniUsage && now - lastUniFetchTime < UNII_FETCH_COOLDOWN_MS) {
			return cachedUniUsage;
		}
		try {
			cachedUniUsage = await fetchUniUsage(ctx.modelRegistry, ctx.model?.id);
			lastUniFetchTime = now;
			tuiRef?.requestRender();
		} catch {
			// keep previous cache on error
		}
		return cachedUniUsage;
	}

	function renderUniUsage(
		usage: UniUsage | undefined,
		theme: { fg(c: string, t: string): string },
	): string {
		if (!usage) return "";
		const pct = Math.round(usage.pct);
		let s = theme.fg(quotaColor(pct), `uni ${pct}%`);
		if (usage.resetIn) {
			s += theme.fg("dim", ` (${usage.resetIn})`);
		}
		return s;
	}

	function renderZaiUsage(
		usage: ZaiUsage | undefined,
		theme: { fg(c: string, t: string): string },
	): string {
		if (!usage) return "";
		const pct = Math.round(usage.percentage * 10) / 10;
		let s = theme.fg(quotaColor(pct), `zai ${pct}%`);
		if (usage.timeRemaining) {
			s += theme.fg("dim", ` (${usage.timeRemaining})`);
		}
		return s;
	}

	function startPeriodicRefresh(ctx: {
		model?: { provider: string } | undefined;
		modelRegistry: { getApiKeyForProvider(p: string): Promise<string | undefined> };
	}): void {
		stopPeriodicRefresh();
		periodicTimer = setInterval(() => {
			if (isZaiProvider(ctx.model?.provider)) {
				void refreshZaiUsage(ctx);
			}
			if (isUniiProvider(ctx.model?.provider)) {
				void refreshUniUsage(ctx);
			}
		}, ZAI_PERIODIC_REFRESH_MS);
		// Don't keep the event loop alive just for quota polling.
		periodicTimer.unref?.();
	}

	function stopPeriodicRefresh(): void {
		if (periodicTimer) {
			clearInterval(periodicTimer);
			periodicTimer = undefined;
		}
	}

	pi.on("session_start", async (_event, ctx) => {
		if (ctx.mode !== "tui") return;

		await refreshZaiUsage(ctx, true);
		await refreshUniUsage(ctx, true);

		ctx.ui.setFooter((tui, theme, footerData) => {
			tuiRef = tui;
			const unsub = footerData.onBranchChange(() => tui.requestRender());

			return {
				dispose: unsub,
				invalidate() {},
				render(width: number): string[] {
					// ── Token stats (cumulative across all session entries) ──
					let totalInput = 0;
					let totalOutput = 0;
					let totalCacheRead = 0;
					let totalCacheWrite = 0;
					let totalCost = 0;
					let latestCacheHitRate: number | undefined;

					for (const entry of ctx.sessionManager.getEntries()) {
						if (entry.type === "message" && entry.message.role === "assistant") {
							const u = (entry.message as AssistantMessage).usage;
							totalInput += u.input;
							totalOutput += u.output;
							totalCacheRead += u.cacheRead ?? 0;
							totalCacheWrite += u.cacheWrite ?? 0;
							totalCost += u.cost?.total ?? 0;
							const latestPromptTokens =
								u.input + (u.cacheRead ?? 0) + (u.cacheWrite ?? 0);
							latestCacheHitRate =
								latestPromptTokens > 0
									? ((u.cacheRead ?? 0) / latestPromptTokens) * 100
									: undefined;
						}
					}

					// ── Context usage ──
					const contextUsage = ctx.getContextUsage();
					const contextWindow =
						contextUsage?.contextWindow ?? ctx.model?.contextWindow ?? 0;
					const contextPercentValue = contextUsage?.percent ?? 0;
					const contextPercent =
						contextUsage?.percent !== null ? contextPercentValue.toFixed(1) : "?";

					// ── Line 1: machineName (always) + cwd (branch) • sessionName ──
					const machinePrefix = theme.fg("accent", machineName);
					const machineWidth = visibleWidth(machinePrefix);
					const cwdStr = formatCwdForFooter(ctx.sessionManager.getCwd(), HOME);
					const branch = footerData.getGitBranch();
					const sessionName = ctx.sessionManager.getSessionName();

					const lines: string[] = [];

					if (machineWidth >= width) {
						// Absurdly narrow: show just the machine name, truncated.
						lines.push(truncateToWidth(machinePrefix, width, theme.fg("dim", "...")));
					} else {
						// Candidate suffixes, longest → shortest. Machine always leads.
						const variants: string[] = [];
						if (branch && sessionName) variants.push(`${cwdStr} (${branch}) • ${sessionName}`);
						if (branch) variants.push(`${cwdStr} (${branch})`);
						variants.push(cwdStr);
						const avail = width - machineWidth - 1; // 1 space gap after machine
						let trailing = "";
						for (const v of variants) {
							if (visibleWidth(v) <= avail) {
								trailing = v;
								break;
							}
						}
						if (!trailing) {
							trailing = truncateToWidth(cwdStr, Math.max(0, avail), "...");
						}
						lines.push(machinePrefix + theme.fg("dim", ` ${trailing}`));
					}

					// ── Right cluster (line 2): Z.ai usage leads so it survives truncation ──
					const isZai = isZaiProvider(ctx.model?.provider);
					const isUni = isUniiProvider(ctx.model?.provider);
					const modelName = ctx.model?.id || "no-model";

					let modelCluster = modelName;
					if (ctx.model?.reasoning) {
						const thinkingLevel = pi.getThinkingLevel() || "off";
						modelCluster =
							thinkingLevel === "off"
								? `${modelName} • thinking off`
								: `${modelName} • ${thinkingLevel}`;
					}
					// Drop the redundant provider prefix when showing its usage.
					let providerPrefix = "";
					if (!isZai && !isUni && footerData.getAvailableProviderCount() > 1 && ctx.model) {
						providerPrefix = `(${ctx.model.provider}) `;
					}
					const modelPart = providerPrefix + modelCluster;

					const zaiPart = renderZaiUsage(cachedZaiUsage, theme);
					const uniPart = renderUniUsage(cachedUniUsage, theme);
					const quotaParts = [zaiPart, uniPart].filter(Boolean).join(" ");
					const rightSide = quotaParts ? `${quotaParts} ${modelPart}` : modelPart;
					const rightSideWidth = visibleWidth(rightSide);

					// ── Left stats (line 2): progressive skip (auto) → CH → R ──
					const usingSubscription = ctx.model
						? ctx.modelRegistry.isUsingOAuth(ctx.model)
						: false;

					const mandatory: string[] = [];
					if (totalInput) mandatory.push(`↑${formatTokens(totalInput)}`);
					if (totalOutput) mandatory.push(`↓${formatTokens(totalOutput)}`);
					if (totalCacheWrite) mandatory.push(`W${formatTokens(totalCacheWrite)}`);
					if (totalCost || usingSubscription) {
						mandatory.push(`$${totalCost.toFixed(3)}${usingSubscription ? " (sub)" : ""}`);
					}

					// Context % (colored), with attached (auto) suffix + xp marker.
					const contextBase =
						contextPercent === "?"
							? `?/${formatTokens(contextWindow)}`
							: `${contextPercent}%/${formatTokens(contextWindow)}`;
					const ctxColor = contextPercentValue > 90
						? "error"
						: contextPercentValue > 70
							? "warning"
							: "";
					const xpSuffix = isExperimental
						? ` ${theme.fg("dim", "•")} ${theme.bold(theme.fg("warning", "xp"))}`
						: "";
					// (auto) only when auto-compaction is actually on — read from the
					// settings files (ExtensionContext exposes no session flag).
					const autoOn = readAutoCompactionEnabled(ctx.sessionManager.getCwd());
					const ctxText = autoOn ? `${contextBase} (auto)` : contextBase;
					const ctxColored = ctxColor ? theme.fg(ctxColor, ctxText) : ctxText;
					const ctxWithAuto = ctxColored + xpSuffix;
					const ctxNoAuto = ctxColored + xpSuffix;
					mandatory.push(ctxWithAuto);

					const rPart = totalCacheRead ? `R${formatTokens(totalCacheRead)}` : null;
					const chPart =
						(totalCacheRead > 0 || totalCacheWrite > 0) &&
						latestCacheHitRate !== undefined
							? `CH${latestCacheHitRate.toFixed(1)}%`
							: null;

					// Droppable, most-expendable first: (auto) → CH → R.
					// Each entry maps to a transform of the mandatory context segment +
					// which optional parts to include.
					const levels: Array<{ ctx: string; r: string | null; ch: string | null }> = [
						{ ctx: ctxWithAuto, r: rPart, ch: chPart },
						{ ctx: ctxNoAuto, r: rPart, ch: chPart },
						{ ctx: ctxNoAuto, r: rPart, ch: null },
						{ ctx: ctxNoAuto, r: null, ch: null },
					];

					// Replace the context placeholder in `mandatory` per level.
					const ctxIdx = mandatory.length - 1; // ctxWithAuto is last mandatory
					const minGap = 2;
					const available = width - rightSideWidth - minGap;

					let statsLeft = "";
					for (const lvl of levels) {
						const optional = [lvl.r, lvl.ch].filter(Boolean) as string[];
						const parts = [...mandatory.slice(0, ctxIdx), lvl.ctx, ...optional];
						statsLeft = parts.join(" ");
						if (visibleWidth(statsLeft) <= available) break;
					}

					// ── Compose line 2 ──
					let statsLeftWidth = visibleWidth(statsLeft);
					if (statsLeftWidth > width) {
						statsLeft = truncateToWidth(statsLeft, width, "...");
						statsLeftWidth = visibleWidth(statsLeft);
					}

					const totalNeeded = statsLeftWidth + minGap + rightSideWidth;
					let statsLine: string;
					if (totalNeeded <= width) {
						const padding = " ".repeat(width - statsLeftWidth - rightSideWidth);
						statsLine = statsLeft + padding + rightSide;
					} else {
						const availableForRight = width - statsLeftWidth - minGap;
						if (availableForRight > 0) {
							const truncatedRight = truncateToWidth(rightSide, availableForRight, "");
							const truncatedRightWidth = visibleWidth(truncatedRight);
							const padding = " ".repeat(
								Math.max(0, width - statsLeftWidth - truncatedRightWidth),
							);
							statsLine = statsLeft + padding + truncatedRight;
						} else {
							statsLine = statsLeft;
						}
					}

					const dimStatsLeft = theme.fg("dim", statsLeft);
					const remainder = statsLine.slice(statsLeft.length);
					const dimRemainder = theme.fg("dim", remainder);
					lines.push(dimStatsLeft + dimRemainder);

					// ── Line 3: extension statuses ──
					const extensionStatuses = footerData.getExtensionStatuses();
					if (extensionStatuses.size > 0) {
						const sortedStatuses = Array.from(extensionStatuses.entries())
							.sort(([a], [b]) => a.localeCompare(b))
							.map(([, text]) => sanitizeStatusText(text));
						const statusLine = sortedStatuses.join(" ");
						lines.push(truncateToWidth(statusLine, width, theme.fg("dim", "...")));
					}

					return lines;
				},
			};
		});

		startPeriodicRefresh(ctx);
	});

	// Refresh quota usage on model switch
	pi.on("model_select", async (event, ctx) => {
		if (isZaiProvider(event.model.provider)) {
			await refreshZaiUsage(ctx, true);
		} else {
			cachedZaiUsage = undefined;
		}
		if (isUniiProvider(event.model.provider)) {
			await refreshUniUsage(ctx, true);
		} else {
			cachedUniUsage = undefined;
		}
	});

	// Refresh quota usage after each turn
	pi.on("turn_end", async (_event, ctx) => {
		if (isZaiProvider(ctx.model?.provider)) {
			await refreshZaiUsage(ctx);
		}
		if (isUniiProvider(ctx.model?.provider)) {
			await refreshUniUsage(ctx);
		}
	});

	// Stop periodic quota polling on shutdown.
	pi.on("session_shutdown", async () => {
		stopPeriodicRefresh();
	});
}
