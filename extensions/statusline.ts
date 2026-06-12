/**
 * Status Line Extension — cloned built-in footer + machine name + Z.ai usage
 *
 * Exact parity with the built-in footer, with two additions:
 *   Line 1: machineName cwd (branch) • sessionName
 *   Line 2 right side: Z.ai:XX% (XhXm) when using Z.ai provider
 *
 * Progressive skip when line 2 is tight: (auto) → CH → R
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

// ── Z.ai usage ────────────────────────────────────────────────────────────────

const ZAI_USAGE_API_URL = "https://api.z.ai/api/monitor/usage/quota/limit";
const ZAI_FETCH_COOLDOWN_MS = 30_000;

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
	if (ms < now) return "0h0m";
	const totalSeconds = Math.round((ms - now) / 1000);
	const hours = Math.floor(totalSeconds / 3600);
	const minutes = Math.floor((totalSeconds % 3600) / 60);
	if (hours > 0) return `${hours}h${minutes}m`;
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

export default function (pi: ExtensionAPI) {
	let cachedZaiUsage: ZaiUsage | undefined;
	let lastZaiFetchTime = 0;

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
		let s = theme.fg("accent", `${pct}%`);
		if (usage.timeRemaining) {
			s += theme.fg("dim", ` (${usage.timeRemaining})`);
		}
		return s;
	}

	pi.on("session_start", async (_event, ctx) => {
		if (ctx.mode !== "tui") return;

		await refreshZaiUsage(ctx, true);

		ctx.ui.setFooter((tui, theme, footerData) => {
			const unsub = footerData.onBranchChange(() => tui.requestRender());

			return {
				dispose: unsub,
				invalidate() {},
				render(width: number): string[] {
					// ── Token stats ──
					let totalInput = 0;
					let totalOutput = 0;
					let totalCacheRead = 0;
					let totalCacheWrite = 0;
					let totalCost = 0;
					let latestCacheHitRate: number | undefined;

					for (const entry of ctx.sessionManager.getEntries()) {
						if (entry.type === "message" && entry.message.role === "assistant") {
							const u = (entry.message as AssistantMessage).usage as Record<string, number>;
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

					// ── Line 1: machineName + cwd (branch) • sessionName ──
					let pwd = formatCwdForFooter(ctx.sessionManager.getCwd(), HOME);
					const branch = footerData.getGitBranch();
					if (branch) pwd = `${pwd} (${branch})`;
					const sessionName = ctx.sessionManager.getSessionName();
					if (sessionName) pwd = `${pwd} • ${sessionName}`;
					const l1left =
						theme.fg("accent", machineName) + theme.fg("dim", ` ${pwd}`);

					// ── Build right side first (to know available space) ──
					const modelName = ctx.model?.id || "no-model";
					let rightSideWithoutProvider = modelName;
					if (ctx.model?.reasoning) {
						const thinkingLevel = pi.getThinkingLevel() || "off";
						rightSideWithoutProvider =
							thinkingLevel === "off"
								? `${modelName} • thinking off`
								: `${modelName} • ${thinkingLevel}`;
					}

					let rightSide = rightSideWithoutProvider;
					if (footerData.getAvailableProviderCount() > 1 && ctx.model) {
						rightSide = `(${ctx.model.provider}) ${rightSideWithoutProvider}`;
					}

					const zaiStr = renderZaiUsage(cachedZaiUsage, theme);
					if (zaiStr) rightSide = `${rightSide} ${zaiStr}`;

					const rightSideWidth = visibleWidth(rightSide);
					const available = width - rightSideWidth - 2; // 2 = min padding

					// ── Build stats left side with progressive skip ──
					// Skip order when tight: (auto) → CH → R
					const coreParts: string[] = [];
					if (totalInput) coreParts.push(`↑${formatTokens(totalInput)}`);
					if (totalOutput) coreParts.push(`↓${formatTokens(totalOutput)}`);
					if (totalCacheWrite)
						coreParts.push(`W${formatTokens(totalCacheWrite)}`);

					const usingSubscription = ctx.model
						? ctx.modelRegistry.isUsingOAuth(ctx.model)
						: false;
					if (totalCost || usingSubscription) {
						coreParts.push(
							`$${totalCost.toFixed(3)}${usingSubscription ? " (sub)" : ""}`,
						);
					}

					// Context % (colored)
					const contextBase =
						contextPercent === "?"
							? `?/${formatTokens(contextWindow)}`
							: `${contextPercent}%/${formatTokens(contextWindow)}`;
					let contextPercentStr: string;
					if (contextPercentValue > 90) {
						contextPercentStr = theme.fg("error", contextBase + " (auto)");
					} else if (contextPercentValue > 70) {
						contextPercentStr = theme.fg("warning", contextBase + " (auto)");
					} else {
						contextPercentStr = contextBase + " (auto)";
					}

					const rPart = totalCacheRead
						? `R${formatTokens(totalCacheRead)}`
						: null;
					const chPart =
						(totalCacheRead > 0 || totalCacheWrite > 0) &&
						latestCacheHitRate !== undefined
							? `CH${latestCacheHitRate.toFixed(1)}%`
							: null;

					// Build full left, then strip if needed
					let statsLeft = [
						...coreParts,
						rPart,
						chPart,
						contextPercentStr,
					]
						.filter(Boolean)
						.join(" ");

					// Progressive skip: (auto) → CH → R
					if (visibleWidth(statsLeft) > available) {
						// Drop (auto)
						const noAuto =
							contextPercentValue > 90
								? theme.fg("error", contextBase)
								: contextPercentValue > 70
									? theme.fg("warning", contextBase)
									: contextBase;
						statsLeft = [...coreParts, rPart, chPart, noAuto]
							.filter(Boolean)
							.join(" ");

						if (visibleWidth(statsLeft) > available) {
							// Drop CH
							statsLeft = [...coreParts, rPart, noAuto]
								.filter(Boolean)
								.join(" ");

							if (visibleWidth(statsLeft) > available) {
								// Drop R
								statsLeft = [...coreParts, noAuto]
									.filter(Boolean)
									.join(" ");
							}
						}
					}

					// ── Compose line 2 ──
					let statsLeftWidth = visibleWidth(statsLeft);
					if (statsLeftWidth > width) {
						statsLeft = truncateToWidth(statsLeft, width, "...");
						statsLeftWidth = visibleWidth(statsLeft);
					}

					const totalNeeded = statsLeftWidth + 2 + rightSideWidth;
					let statsLine: string;
					if (totalNeeded <= width) {
						const padding = " ".repeat(
							width - statsLeftWidth - rightSideWidth,
						);
						statsLine = statsLeft + padding + rightSide;
					} else {
						const availableForRight = width - statsLeftWidth - 2;
						if (availableForRight > 0) {
							const truncatedRight = truncateToWidth(
								rightSide,
								availableForRight,
								"",
							);
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

					const lines = [
						truncateToWidth(l1left, width, theme.fg("dim", "...")),
						dimStatsLeft + dimRemainder,
					];

					// ── Line 3: extension statuses ──
					const extensionStatuses = footerData.getExtensionStatuses();
					if (extensionStatuses.size > 0) {
						const sortedStatuses = Array.from(extensionStatuses.entries())
							.sort(([a], [b]) => a.localeCompare(b))
							.map(([, text]) => sanitizeStatusText(text));
						const statusLine = sortedStatuses.join(" ");
						lines.push(
							truncateToWidth(statusLine, width, theme.fg("dim", "...")),
						);
					}

					return lines;
				},
			};
		});
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
}
