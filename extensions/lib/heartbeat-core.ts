/**
 * heartbeat-core — state, timers and control logic for the heartbeat extension.
 *
 * Import-free of the pi runtime by design (only ./session-state, whose imports
 * are type-only): tests/heartbeat/test.sh drives the FULL control flow
 * (start/override/once/pause/resume/stop/busy-shift) offline with mocked host
 * + ctx objects. Node builtins are allowed.
 *
 * The extension (heartbeat.ts) wires this core to the real pi runtime.
 */
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { isStaleCtxError } from "./session-state";
import { humanDuration, parseDuration } from "./heartbeat-parse";

export const ENTRY_TYPE = "heartbeat:config";
export const DEFAULT_MESSAGE = "Time to check in — what are you working on?";
const STATUS_KEY = "heartbeat";
// When pi is busy (mid-turn) a due beat is SHIFTED by one interval and re-checked —
// it is not consumed (count not bumped), so a long agent run just pushes the beat
// out rather than stacking a burst of reminders. The shift is capped at 5 min max.
const BUSY_SHIFT_MAX_MS = 300_000; // 5 min cap
// If busy outlives this, the turn_end event was lost (crash/reload mid-turn):
// treat pi as idle instead of shifting beats forever.
const BUSY_STUCK_MS = 15 * 60_000; // 15 min

/** The slice of the pi runtime the core needs (structurally satisfied by pi). */
export interface HeartbeatHost {
	sendUserMessage(text: string, opts?: { deliverAs?: string }): void;
	appendEntry(type: string, data: unknown): void;
}

/** The slice of a command/tool context the core needs. */
export interface HeartbeatCtx {
	hasUI?: boolean;
	ui?: {
		setStatus(key: string, value: string | undefined): void;
		notify(message: string, level?: string): void;
	};
}

export interface ControlOpts {
	action: "start" | "status" | "stop" | "message" | "time" | "pause" | "resume" | "help";
	message?: string;
	duration?: string; // "30s" | "5m" | "2h" | "1d"
	maxCount?: number; // 0 = forever
	once?: boolean; // one-shot: fire once after duration, then stop
	file?: string;
	lines?: number;
}

export interface ControlResult {
	text: string; // human-facing summary
	level: "info" | "warning" | "error" | "success";
	state: StateSnapshot;
}

// ── State (module-level singleton; config persisted via appendEntry) ──
interface HBState {
	active: boolean;
	message: string;
	intervalMs: number;
	maxCount: number; // 0 = forever
	startedAt: number;
	lastAt: number;
	nextAt: number;
	count: number;
	paused: boolean;
	once: boolean; // one-shot: stop after the next delivery
	busy: boolean; // true while pi is mid-turn (tracked via turn_start/turn_end)
	busySince: number; // when busy began — escape hatch if turn_end is missed
}

const state: HBState = {
	active: false,
	message: DEFAULT_MESSAGE,
	intervalMs: 60_000,
	maxCount: 0,
	startedAt: 0,
	lastAt: 0,
	nextAt: 0,
	count: 0,
	paused: false,
	once: false,
	busy: false,
	busySince: 0,
};

let timerId: ReturnType<typeof setTimeout> | undefined;
let statusTimerId: ReturnType<typeof setInterval> | undefined;
let oneShotTimerId: ReturnType<typeof setTimeout> | undefined;

/** Snapshot of state for tool `details` and reconstruction (no timers). */
export type StateSnapshot = HBState;

export function snapshot(): StateSnapshot {
	return { ...state };
}

export function setBusy(busy: boolean, since: number = Date.now()) {
	state.busy = busy;
	if (busy) state.busySince = since;
}

/** Stop the running heartbeat and clear all timers. Does not touch message/interval. */
function resetTimers() {
	if (timerId) clearTimeout(timerId);
	if (statusTimerId) clearInterval(statusTimerId);
	if (oneShotTimerId) clearTimeout(oneShotTimerId);
	timerId = undefined;
	statusTimerId = undefined;
	oneShotTimerId = undefined;
	state.active = false;
	state.paused = false;
}

/** Full reset to defaults (used on lifecycle events). */
export function resetAll() {
	resetTimers();
	state.message = DEFAULT_MESSAGE;
	state.intervalMs = 60_000;
	state.maxCount = 0;
	state.startedAt = 0;
	state.lastAt = 0;
	state.nextAt = 0;
	state.count = 0;
	state.once = false;
	state.busy = false;
	state.busySince = 0;
}

// ── Safe ctx.ui wrappers (guard stale proxy + missing ui) ─────
/** Returns false when the context went stale (callers may stop their timers). */
function safeSetStatus(ctx: HeartbeatCtx, value: string | undefined): boolean {
	try {
		ctx.ui?.setStatus(STATUS_KEY, value);
		return true;
	} catch (e) {
		if (!isStaleCtxError(e)) throw e;
		return false;
	}
}
function safeNotify(ctx: HeartbeatCtx, msg: string, level: "info" | "warning" | "error" | "success" = "info") {
	try { ctx.ui?.notify(msg, level); } catch (e) { if (!isStaleCtxError(e)) throw e; }
}

function statusLine(): string {
	const rem = Math.max(0, Math.floor((state.nextAt - Date.now()) / 1000));
	const tot = Math.floor(state.intervalMs / 1000);
	if (state.paused) return `⏰ PAUSED ${rem}s`;
	// Clamp the fill bar to 0..10. After a busy-shift nextAt can be far out (e.g. a
	// 5s interval shifted 2min), which would otherwise drive pct/f negative and make
	// String.repeat throw RangeError.
	const pct = tot > 0 ? Math.round(((tot - rem) / tot) * 100) : 0;
	const f = Math.max(0, Math.min(10, Math.round(pct / 10)));
	return `⏰ ${rem}s [${"█".repeat(f)}${"░".repeat(10 - f)}] #${state.count}`;
}

// ── Timer scheduling (stale-ctx safe) ─────────────────────────
/** Start the status-bar ticker. Assumes state is already set. Does NOT touch state.active. */
function startStatusBar(ctx: HeartbeatCtx) {
	if (statusTimerId) clearInterval(statusTimerId);
	statusTimerId = setInterval(() => {
		if (!state.active) {
			safeSetStatus(ctx, undefined);
			if (statusTimerId) clearInterval(statusTimerId);
			statusTimerId = undefined;
			return;
		}
		// ctx went stale (branch/switch) → stop ticking against a dead context
		if (!safeSetStatus(ctx, statusLine())) {
			if (statusTimerId) clearInterval(statusTimerId);
			statusTimerId = undefined;
		}
	}, 500);
}

function scheduleNext(pi: HeartbeatHost, ctx: HeartbeatCtx) {
	if (!state.active || state.paused) return;
	const d = Math.max(0, state.intervalMs - (Date.now() - state.lastAt));
	state.nextAt = Date.now() + d;
	timerId = setTimeout(() => onBeatDue(pi, ctx), d);
}

/**
 * A beat came due. If pi is busy (mid-turn) we SHIFT it by one interval (capped
 * at 5 min) and re-check later — we do NOT consume it (count is not bumped), so
 * a long agent run keeps pushing the beat out instead of stacking a burst of
 * reminders mid-work. Only when pi is idle do we actually fire.
 */
export function onBeatDue(pi: HeartbeatHost, ctx: HeartbeatCtx) {
	if (!state.active || state.paused) return;
	if (state.busy && Date.now() - state.busySince < BUSY_STUCK_MS) {
		// Shift by one interval (capped at 5 min) — do NOT consume the beat.
		const shift = Math.min(state.intervalMs, BUSY_SHIFT_MAX_MS);
		state.nextAt = Date.now() + shift;
		timerId = setTimeout(() => onBeatDue(pi, ctx), shift);
		return;
	}
	// busy longer than BUSY_STUCK_MS → turn_end was missed (crash/reload);
	// treat as idle rather than shifting forever.
	state.busy = false;
	fireReminder(pi, ctx);
}

/** Send the next reminder (only ever called when not busy). */
function fireReminder(pi: HeartbeatHost, ctx: HeartbeatCtx) {
	state.count++;
	state.lastAt = Date.now();
	state.nextAt = Date.now() + state.intervalMs;
	try {
		pi.sendUserMessage(`⏰ **Heartbeat #${state.count}**\n\n${state.message}`, { deliverAs: "followUp" });
	} catch (e) {
		if (isStaleCtxError(e)) { resetTimers(); return; }
		throw e;
	}

	const finished = state.once
		|| (state.maxCount > 0 && state.count >= state.maxCount);
	if (finished) {
		const total = state.count;
		const why = state.once ? "One-shot delivered." : `finished after ${total} reminder${total === 1 ? "" : "s"}.`;
		resetTimers();
		safeSetStatus(ctx, undefined);
		safeNotify(ctx, `⏹ Heartbeat ${why}`, "success");
		persist(pi);
		return;
	}
	scheduleNext(pi, ctx);
}

function scheduleOneShot(pi: HeartbeatHost, ctx: HeartbeatCtx, delayMs: number) {
	state.nextAt = Date.now() + delayMs;
	oneShotTimerId = setTimeout(() => {
		if (!state.active || state.paused) return;
		// Same idle-only rule as recurring: shift while busy, fire when idle.
		onBeatDue(pi, ctx);
	}, delayMs);
}

// ── Config persistence (survives reload / branch switch) ──────
export function persist(pi: HeartbeatHost) {
	try {
		pi.appendEntry(ENTRY_TYPE, {
			active: state.active,
			message: state.message,
			intervalMs: state.intervalMs,
			maxCount: state.maxCount,
			paused: state.paused,
			once: state.once,
		});
	} catch { /* appendEntry best-effort */ }
}

/**
 * Apply a reconstructed config entry (call right after resetAll).
 * Timers never survive a restart: an entry with active=true is restored as
 * inactive (message/interval/maxCount/once are KEPT for the next start) and
 * `true` is returned so the wiring can inform the user once.
 */
export function restoreFrom(saved: Record<string, unknown>, pi: HeartbeatHost): boolean {
	const wasActive = saved.active === true;
	if (typeof saved.message === "string") state.message = saved.message;
	if (typeof saved.intervalMs === "number" && saved.intervalMs > 0) state.intervalMs = saved.intervalMs;
	if (typeof saved.maxCount === "number") state.maxCount = saved.maxCount;
	if (typeof saved.once === "boolean") state.once = saved.once;
	state.paused = false; // a paused timer is dead too — resumed state makes no sense
	state.active = false;
	if (wasActive) persist(pi);
	return wasActive;
}

/**
 * ESC handling: toggle pause/resume when a heartbeat is active and pi is
 * idle. Everything else (no heartbeat, mid-turn) is NOT consumed so pi's
 * native escape behavior (abort) keeps working. Returns true when consumed.
 */
export function onEscape(pi: HeartbeatHost, ctx: HeartbeatCtx): boolean {
	if (!state.active || state.busy) return false;
	const action = state.paused ? "resume" : "pause";
	const res = control(pi, ctx, { action });
	safeNotify(ctx, res.text, res.level);
	return true;
}

// ── Centralized control (used by command AND tool) ────────────
export function control(pi: HeartbeatHost, ctx: HeartbeatCtx, o: ControlOpts): ControlResult {
	// ── help (bare /heartbeat with no args) ──────────────────
	if (o.action === "help") {
		return {
			text: [
				"⏰ Heartbeat — recurring reminder (fires only when pi is idle)",
				"",
				"USAGE",
				"  /heartbeat <duration> [\"message\"]   start (30s | 5m | 2h | 1d; bare = seconds)",
				"  /heartbeat \"message\"                start with default 60s",
				"  /heartbeat -f file.md [--lines N]   start, message from file",
				"  /heartbeat <dur> --limit N           stop after N beats (0 = forever)",
				"  /heartbeat <dur> --once              one-shot: fire once, then stop",
				"  /heartbeat message <text>            change message live",
				"  /heartbeat time <duration>           change interval live",
				"  /heartbeat pause | resume | status | off",
				"",
				"WHILE BUSY",
				"  A beat due while pi is mid-turn is SHIFTED by one interval (capped at 5 min),",
				"  not consumed — it fires only when pi is idle.",
			].join("\n"),
			level: "info",
			state: snapshot(),
		};
	}

	// ── status ───────────────────────────────────────────────
	if (o.action === "status") {
		if (!state.active) return { text: "No heartbeat active.", level: "info", state: snapshot() };
		const elapsed = Math.floor((Date.now() - state.startedAt) / 1000);
		const text = [
			"✅ Heartbeat Active",
			`  message: ${state.message}`,
			`  interval: ${humanDuration(state.intervalMs)}`,
			`  sent: ${state.maxCount > 0 ? `${state.count}/${state.maxCount}` : `${state.count} (∞)`}`,
			`  running: ${elapsed}s`,
			`  paused: ${state.paused ? "yes" : "no"}`,
			`  ${statusLine()}`,
		].join("\n");
		return { text, level: "info", state: snapshot() };
	}

	// ── pause ────────────────────────────────────────────────
	if (o.action === "pause") {
		if (!state.active) return { text: "No heartbeat active.", level: "warning", state: snapshot() };
		if (state.paused) return { text: "Heartbeat is already paused.", level: "info", state: snapshot() };
		if (timerId) clearTimeout(timerId);
		if (statusTimerId) clearInterval(statusTimerId);
		if (oneShotTimerId) clearTimeout(oneShotTimerId);
		timerId = undefined;
		statusTimerId = undefined;
		oneShotTimerId = undefined;
		state.paused = true;
		const rem = Math.max(0, Math.floor((state.nextAt - Date.now()) / 1000));
		safeSetStatus(ctx, statusLine());
		persist(pi);
		return { text: `⏸ Heartbeat paused (${rem}s remaining).`, level: "info", state: snapshot() };
	}

	// ── resume ──────────────────────────────────────────────
	if (o.action === "resume") {
		if (!state.active) return { text: "No heartbeat active.", level: "warning", state: snapshot() };
		if (!state.paused) return { text: "Heartbeat is not paused.", level: "info", state: snapshot() };
		state.paused = false;
		if (state.once) {
			// One-shot: re-arm against the frozen nextAt deadline (was cleared on pause).
			const remaining = Math.max(0, state.nextAt - Date.now());
			scheduleOneShot(pi, ctx, remaining);
			persist(pi);
			return { text: `▶ One-shot resumed (${humanDuration(remaining)} until delivery).`, level: "success", state: snapshot() };
		}
		const elapsed = Date.now() - state.lastAt;
		const remaining = Math.max(0, state.intervalMs - elapsed);
		state.lastAt = Date.now();
		state.nextAt = Date.now() + remaining;
		startStatusBar(ctx);
		scheduleNext(pi, ctx);
		persist(pi);
		return { text: `▶ Heartbeat resumed (${humanDuration(remaining)} until next ping).`, level: "success", state: snapshot() };
	}

	// ── stop / off ───────────────────────────────────────────
	if (o.action === "stop") {
		if (!state.active) return { text: "No heartbeat active.", level: "warning", state: snapshot() };
		resetTimers();
		safeSetStatus(ctx, undefined);
		persist(pi);
		return { text: "⏹ Heartbeat stopped.", level: "success", state: snapshot() };
	}

	// ── change message (live) ────────────────────────────────
	if (o.action === "message") {
		if (o.message === undefined) return { text: `Current message: ${state.message}`, level: "info", state: snapshot() };
		state.message = String(o.message).trim();
		persist(pi);
		return { text: `Message updated: ${state.message}`, level: "success", state: snapshot() };
	}

	// ── change interval (live) ───────────────────────────────
	if (o.action === "time") {
		if (o.duration === undefined) return { text: `Current interval: ${humanDuration(state.intervalMs)}`, level: "info", state: snapshot() };
		const ms = parseDuration(o.duration);
		if (!ms) {
			throw new Error(`Invalid duration: "${o.duration}". Use e.g. 30s, 5m, 2h, 1d (bare = seconds).`);
		}
		state.intervalMs = ms;
		if (state.active) {
			if (timerId) clearTimeout(timerId);
			if (oneShotTimerId) clearTimeout(oneShotTimerId);
			oneShotTimerId = undefined;
			state.lastAt = Date.now();
			state.nextAt = Date.now() + ms;
			if (state.once) scheduleOneShot(pi, ctx, ms); // pending one-shot follows the new interval
			else scheduleNext(pi, ctx);
		}
		persist(pi);
		return {
			text: `Interval updated: ${humanDuration(ms)}${state.active ? "" : " (applies on start)"}`,
			level: "success",
			state: snapshot(),
		};
	}

	// ── start ────────────────────────────────────────────────
	if (!ctx.hasUI) {
		return { text: "Heartbeat requires interactive mode.", level: "warning", state: snapshot() };
	}

	// Starting while one is already active OVERRIDES it (restart with the new
	// settings) instead of returning a warning — no need to /heartbeat off first.
	const restarting = state.active;

	let msg = state.message;
	let intervalMs = state.intervalMs;

	if (o.duration) {
		const ms = parseDuration(o.duration);
		if (!ms) throw new Error(`Invalid duration: "${o.duration}". Use 30s, 5m, 2h, 1d.`);
		intervalMs = ms;
	}
	if (o.message !== undefined && o.message !== "") msg = String(o.message).trim();
	if (o.file) {
		const fp = o.file.startsWith("/") ? o.file : join(process.cwd(), o.file);
		if (!existsSync(fp)) {
			throw new Error(`File not found: ${o.file} (resolved: ${fp}) — note: relative paths resolve against pi's start directory`);
		}
		const fileLines = readFileSync(fp, "utf-8").split("\n");
		const cap = typeof o.lines === "number" && o.lines > 0 ? o.lines : fileLines.length;
		msg = fileLines.slice(0, cap).join("\n").trim();
	}

	resetTimers();
	state.active = true;
	state.message = msg;
	state.intervalMs = intervalMs;
	state.maxCount = typeof o.maxCount === "number" && o.maxCount >= 0 ? o.maxCount : 0;
	state.once = !!o.once;
	state.startedAt = Date.now();
	state.lastAt = Date.now();
	state.nextAt = Date.now() + intervalMs;
	state.count = 0;

	if (o.once) {
		startStatusBar(ctx);
		scheduleOneShot(pi, ctx, intervalMs);
	} else {
		startStatusBar(ctx);
		scheduleNext(pi, ctx);
	}
		const modeLabel = o.once ? "one-shot" : "recurring";
		const freqLabel = o.once ? "" : ` (every ${humanDuration(intervalMs)})`;
		const limitLabel = state.maxCount > 0 ? `${state.maxCount} reminder${state.maxCount === 1 ? "" : "s"}` : "forever";
		const title = restarting ? "🔄 Heartbeat Restarted" : "✅ Heartbeat Started";
		const restartHint = restarting ? "  (previous heartbeat overridden)" : "";
		persist(pi);
		return {
			text: [
				title,
				`  message: ${msg}`,
				`  mode: ${modeLabel}${freqLabel}`,
				`  limit: ${limitLabel}`,
				restartHint,
				`  run /heartbeat off to stop`,
			].filter(Boolean).join("\n"),
			level: "success",
			state: snapshot(),
		};
}

