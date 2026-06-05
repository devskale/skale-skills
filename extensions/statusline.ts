/**
 * Status Line Extension — machine name footer
 *
 * Custom footer showing machine name, cwd, token stats, context usage,
 * model info, and extension statuses.
 */

import { execSync } from "node:child_process";
import { hostname } from "node:os";
import type { AssistantMessage } from "@earendil-works/pi-ai";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

// Cache machine name — never changes during session
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

const formatTokens = (n: number): string => {
	if (n === 0) return "0";
	if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
	if (n >= 1000) return `${(n / 1000).toFixed(1)}k`;
	return `${n}`;
};

const HOME = process.env.HOME || process.env.USERPROFILE || "";

export default function (pi: ExtensionAPI) {
	pi.on("session_start", async (_event, ctx) => {
		if (ctx.mode !== "tui") return;

		ctx.ui.setFooter((tui, theme, footerData) => {
			const unsub = footerData.onBranchChange(() => tui.requestRender());

			return {
				dispose: unsub,
				invalidate() {},
				render(width: number): string[] {
					const cwd = ctx.cwd.replace(HOME, "~");

					// Token stats
					let input = 0;
					let output = 0;
					let cacheRead = 0;
					for (const e of ctx.sessionManager.getBranch()) {
						if (e.type === "message" && e.message.role === "assistant") {
							const u = (e.message as AssistantMessage).usage as Record<string, number>;
							input += u.input;
							output += u.output;
							cacheRead += u.cacheRead ?? 0;
						}
					}

					// Context usage
					const usage = ctx.getContextUsage();
					let ctxStr = "";
					if (usage && usage.limit > 0) {
						ctxStr = `${((usage.tokens / usage.limit) * 100).toFixed(1)}%/${Math.round(usage.limit / 1000)}k (auto)`;
					}

					// Model + thinking
					const thinking = pi.getThinkingLevel();
					const thinkingStr =
						thinking && thinking !== "off" ? ` • ${thinking}` : "";
					const provider = ctx.model?.provider ?? "";
					const modelStr = provider
						? `(${provider}) ${ctx.model?.id || ""}${thinkingStr}`
						: `${ctx.model?.id || ""}${thinkingStr}`;

					// Extension statuses (from other extensions)
					const statuses = footerData.getExtensionStatuses();
					const statusStr = Array.from(statuses.values()).join(" ");

					// Line 1: machine name + cwd
					const l1left =
						theme.fg("accent", machineName) + theme.fg("dim", ` ${cwd}`);

					// Line 2: tokens + context → model
					let l2text = `↑${formatTokens(input)} ↓${formatTokens(output)}`;
					if (cacheRead > 0) l2text += ` R${formatTokens(cacheRead)}`;
					if (ctxStr) l2text += ` ${ctxStr}`;
					const l2left = theme.fg("dim", l2text);
					const l2right = theme.fg("dim", modelStr);
					const p2 = " ".repeat(
						Math.max(1, width - visibleWidth(l2left) - visibleWidth(l2right)),
					);

					const lines = [
						truncateToWidth(l1left, width),
						truncateToWidth(l2left + p2 + l2right, width),
					];
					if (statusStr) {
						lines.push(truncateToWidth(statusStr, width));
					}
					return lines;
				},
			};
		});
	});
}
