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
 * Caveat: "(auto)" is always appended after the context %. The built-in footer
 * hides it when auto-compaction is disabled (session.autoCompactionEnabled),
 * but ExtensionContext does not expose that flag, so we cannot replicate it.
 * Compaction is enabled by default, so this is accurate in the common case.
 */

import { execSync } from "node:child_process";
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

/** Pick a theme color for a Z.ai usage percentage. */
function zaiColor(pct: number): string {
	if (pct >= 80) return "error";
	if (pct >= 50) return "warning";
	return "accent";
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

// ── Extension entry point ─────────────────────────────────────────────────────

interface TuiLike {
	requestRender(): void;
}

export default function (pi: ExtensionAPI) {
	let cachedZaiUsage: ZaiUsage | undefined;
	let lastZaiFetchTime = 0;
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

	function renderZaiUsage(
		usage: ZaiUsage | undefined,
		theme: { fg(c: string, t: string): string },
	): string {
		if (!usage) return "";
		const pct = Math.round(usage.percentage * 10) / 10;
		let s = theme.fg(zaiColor(pct), `zai ${pct}%`);
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
					const modelName = ctx.model?.id || "no-model";

					let modelCluster = modelName;
					if (ctx.model?.reasoning) {
						const thinkingLevel = pi.getThinkingLevel() || "off";
						modelCluster =
							thinkingLevel === "off"
								? `${modelName} • thinking off`
								: `${modelName} • ${thinkingLevel}`;
					}
					// Drop the redundant "(zai)" provider prefix when showing Z.ai usage.
					let providerPrefix = "";
					if (!isZai && footerData.getAvailableProviderCount() > 1 && ctx.model) {
						providerPrefix = `(${ctx.model.provider}) `;
					}
					const modelPart = providerPrefix + modelCluster;

					const zaiPart = renderZaiUsage(cachedZaiUsage, theme);
					const rightSide = zaiPart ? `${zaiPart} ${modelPart}` : modelPart;
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
					const ctxAutoText = ctxColor
						? theme.fg(ctxColor, `${contextBase} (auto)`)
						: `${contextBase} (auto)`;
					const ctxBaseText = ctxColor
						? theme.fg(ctxColor, contextBase)
						: contextBase;
					const ctxWithAuto = ctxAutoText + xpSuffix;
					const ctxNoAuto = ctxBaseText + xpSuffix;
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

	// Refresh Z.ai usage on model switch
	pi.on("model_select", async (event, ctx) => {
		if (isZaiProvider(event.model.provider)) {
			await refreshZaiUsage(ctx, true);
		} else {
			cachedZaiUsage = undefined;
		}
	});

	// Refresh Z.ai usage after each turn
	pi.on("turn_end", async (_event, ctx) => {
		if (isZaiProvider(ctx.model?.provider)) {
			await refreshZaiUsage(ctx);
		}
	});

	// Stop periodic quota polling on shutdown.
	pi.on("session_shutdown", async () => {
		stopPeriodicRefresh();
	});
}
