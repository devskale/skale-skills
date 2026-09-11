/**
 * Heartbeat Extension — recurring reminder + agent-controllable timer.
 *
 * State, timers and the control surface live in ./lib/heartbeat-core.ts
 * (dependency-free, fully unit-tested by tests/heartbeat/test.sh).
 * This file is only the pi wiring: slash command, agent tool, lifecycle
 * events, busy/idle tracking.
 *
 * Slash commands (human):
 *   /heartbeat 30s                 start with 30s interval
 *   /heartbeat 5m "Focus on X"     interval + custom message
 *   /heartbeat -f file.md          message from file (--lines N caps it)
 *   /heartbeat 30s --limit 20      stop after 20 heartbeats (0 = forever)
 *   /heartbeat 30s --once          one-shot: fire once after 30s, then stop
 *   /heartbeat pause | resume | status | off
 *   /heartbeat message <text>      change message live
 *   /heartbeat time <duration>     change interval live
 *
 * Starting a heartbeat while one is active OVERRIDES it. Only one heartbeat
 * can be active at a time (per pi process).
 *
 * Requires pi ≥ 0.79 (registerCommand + registerTool + ctx.ui.setStatus).
 */

import { Type } from "typebox";
import { StringEnum } from "@earendil-works/pi-ai";
import { defineTool, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { isStaleCtxError, reconstructLastCustomEntry } from "./lib/session-state";
import { parseCommand } from "./lib/heartbeat-parse";
import {
	control,
	ENTRY_TYPE,
	onEscape,
	resetAll,
	restoreFrom,
	setBusy,
	type ControlOpts,
} from "./lib/heartbeat-core";

function safeNotify(ctx: any, msg: string, level: "info" | "warning" | "error" | "success") {
	try { ctx.ui?.notify(msg, level); } catch (e) { if (!isStaleCtxError(e)) throw e; }
}

// ESC: pause on the first press (side effect — the press still reaches pi),
// stop on a slow second press (0.5–1.5s later, the only consumed press).
// pi's native fast double-ESC (chat tree) is never consumed — see onEscape
// in the core. Wired lazily on the first heartbeat interaction (needs a ctx
// with a UI).
let escWired = false;
function wireEscape(pi: ExtensionAPI, ctx: any) {
	if (escWired || typeof ctx?.ui?.onTerminalInput !== "function") return;
	try {
		ctx.ui.onTerminalInput((data: string) => {
			if (data !== "\x1b") return undefined; // only the bare ESC key
			return onEscape(pi, ctx) ? { consume: true } : undefined;
		});
		escWired = true;
	} catch { /* non-interactive context */ }
}

// ── Extension entry point ────────────────────────────────────
export default function (pi: ExtensionAPI) {
	// Reconstruct config from session entries on each lifecycle event (§6, §19.3).
	// Timers are NOT auto-restarted — they are process-global and a resumed/
	// branched session re-starts on demand via command/tool.
	const restore = (ctx: any) => {
		resetAll();
		try {
			const saved = reconstructLastCustomEntry(ctx, ENTRY_TYPE) as Record<string, unknown> | undefined;
			if (saved && restoreFrom(saved, pi)) {
				// A heartbeat was active when the previous session ended — timers
				// cannot survive a process/reload. Tell the user once, then clear
				// the active flag so the notice doesn't repeat on every session.
				safeNotify(
					ctx,
					"⏰ The previous heartbeat does not survive restarts — start it again with /heartbeat <duration> (message/interval were kept).",
					"warning",
				);
			}
		} catch { /* best-effort */ }
	};

	pi.on("session_start", (_e, ctx) => restore(ctx));
	pi.on("session_tree", (_e, ctx) => restore(ctx));
	pi.on("session_compact", (_e, ctx) => restore(ctx));
	pi.on("session_shutdown", () => resetAll());

	// ── Busy/idle tracking: only fire heartbeats when pi is idle ──
	// turn_start → busy (pi is mid-turn). turn_end → idle. A beat due while
	// busy is SHIFTED (capped at 5 min, not consumed) and re-checked later;
	// if turn_end never arrives, the core's stuck-busy escape treats pi as idle.
	pi.on("turn_start", (_e) => setBusy(true));
	pi.on("turn_end", (_e) => setBusy(false));

	// ── Human slash command: /heartbeat … ─────────────────────
	pi.registerCommand("heartbeat", {
		description: "Recurring reminder. /heartbeat 30s | \"msg\" | -f file.md | message <txt> | time <dur> | status | off",
		handler: async (args: unknown, ctx: any) => {
			const raw = typeof args === "string" ? args.trim() : "";
			const opts = parseCommand(raw);
			try {
				const res = control(pi, ctx, opts);
				safeNotify(ctx, res.text, res.level);
				wireEscape(pi, ctx);
			} catch (e) {
				safeNotify(ctx, `Error: ${(e as Error).message}`, "error");
			}
		},
	});

	// ── Agent tool: heartbeat (same control surface) ──────────
	const heartbeatTool = defineTool({
		name: "heartbeat",
		label: "Heartbeat",
		description:
			"Control a recurring reminder timer. Starts, stops, pauses, resumes, or queries a " +
			"heartbeat that sends a follow-up message every N seconds (default 60s) with a " +
			"custom message, and shows a countdown in the status line. Supports one-shot mode " +
			"(once: true) and pause/resume. The agent can use this to set up periodic check-ins, " +
			"nudges, or to adjust an existing heartbeat the user started.",
		promptSnippet: "Start/stop/pause/resume/adjust a recurring reminder timer (heartbeat)",
		promptGuidelines: [
			"Use the heartbeat tool when the user wants a recurring reminder, nudge, or periodic check-in " +
				"(e.g. 'remind me every 5 minutes', 'ping me every 30s while I wait').",
			"Use action 'start' with duration like '30s', '5m', '2h', '1d' and an optional message; " +
				"maxCount stops after N pings (0 = forever). Use 'once: true' for a single reminder after a delay.",
			"Use action 'pause' to freeze the countdown and 'resume' to continue. State is preserved across pauses.",
			"Use action 'time' or 'message' to change an already-running heartbeat live, 'status' to " +
				"inspect it, and 'stop' to end it.",
		],
		parameters: Type.Object({
			action: StringEnum(["start", "status", "stop", "message", "time", "pause", "resume", "help"] as const),
			message: Type.Optional(Type.String({ description: "Reminder text (for action 'start' or 'message')" })),
			duration: Type.Optional(Type.String({
				description: "Interval, e.g. '30s', '5m', '2h', '1d' (bare number = seconds). For actions 'start' and 'time'.",
			})),
			maxCount: Type.Optional(Type.Number({
				description: "Auto-stop after this many reminders. 0 (default) = run forever. For action 'start'.",
			})),
			once: Type.Optional(Type.Boolean({
				description: "One-shot mode: send a single reminder after 'duration', then stop. Cannot combine with maxCount. For action 'start'.",
			})),
			file: Type.Optional(Type.String({ description: "Read message from a file. For action 'start'." })),
			lines: Type.Optional(Type.Number({ description: "Cap lines read from file. For action 'start'." })),
		}),
		async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
			const res = control(pi, ctx, params as ControlOpts);
			// Also surface result to the human via the status line / notify.
			safeNotify(ctx, res.text, res.level);
			wireEscape(pi, ctx);
			return {
				content: [{ type: "text", text: res.text }],
				// Full state in details → correct on fork/branch (§6).
				details: { heartbeat: res.state },
			};
		},
	});

	pi.registerTool(heartbeatTool);
}
