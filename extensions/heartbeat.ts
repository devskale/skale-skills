/**
 * Heartbeat Extension — recurring reminder + agent-controllable timer.
 *
 * A robust, branching-safe recurring reminder that:
 *   - fires a follow-up message every N seconds (s | m | h | d)
 *   - shows a countdown progress bar in the status line
 *   - can be driven by the human (/heartbeat) OR the agent (heartbeat tool)
 *
 * Slash commands (human):
 *   /heartbeat 30s                 start with 30s interval
 *   /heartbeat 5m "Focus on X"     interval + custom message
 *   /heartbeat -f file.md          message from file (--lines N caps it)
 *   /heartbeat 30s --limit 20      stop after 20 heartbeats (0 = forever)
 *   /heartbeat 30s --once          one-shot: fire once after 30s, then stop
 *   /heartbeat pause               pause countdown (keeps state)
 *   /heartbeat resume              resume countdown
 *   /heartbeat message <text>      change message live
 *   /heartbeat time <duration>     change interval live (30s | 5m | 2h | 1d)
 *   /heartbeat status              show status
 *   /heartbeat off                 stop
 *
 *
 * Only one heartbeat can be active at a time. Starting a new one while
 * one is already running OVERRIDES it (restarts with the new settings).
 *
 * Agent tool (LLM): same surface via the `heartbeat` tool — see promptGuidelines.
 *
 * Robustness (per pi extensions best practices):
 *   - Centralized control() logic shared by command + tool (one source of truth)
 *   - Stale-ctx guards on all timer callbacks (§19.1, §19.3)
 *   - try/catch around every ctx.ui call (§8)
 *   - Config persisted via pi.appendEntry() and reconstructed on session lifecycle
 *   - Tool returns full state in `details` for proper branching (§6)
 *
 * Requires pi ≥ 0.79 (registerCommand + registerTool + ctx.ui.setStatus).
 */

import { Type } from "typebox";
import { StringEnum } from "@earendil-works/pi-ai";
import { defineTool, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { join } from "node:path";
import { existsSync, readFileSync } from "node:fs";
import { isStaleCtxError, reconstructLastCustomEntry } from "./lib/session-state";
import { humanDuration, parseCommand, parseDuration } from "./lib/heartbeat-parse";

const DEFAULT_MESSAGE = "Time to check in — what are you working on?";
const STATUS_KEY = "heartbeat";
const ENTRY_TYPE = "heartbeat:config";
// When pi is busy (mid-turn) a due beat is SHIFTED by one interval and re-checked —
// it is not consumed (count not bumped), so a long agent run just pushes the beat
// out rather than stacking a burst of reminders. The shift is capped at 5 min max.
const BUSY_SHIFT_MAX_MS = 300_000; // 5 min cap
// If busy outlives this, the turn_end event was lost (crash/reload mid-turn):
// treat pi as idle instead of shifting beats forever.
const BUSY_STUCK_MS = 15 * 60_000; // 15 min

// ── State (module-level; config persisted via appendEntry) ────
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
  once: boolean;    // one-shot: stop after the next delivery
  busy: boolean;    // true while pi is mid-turn (tracked via turn_start/turn_end)
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
type StateSnapshot = Omit<HBState, never>;

function snapshot(): StateSnapshot {
  return { ...state };
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
function resetAll() {
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

// ── Formatting helpers ────────────────────────────────────────
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
function startStatusBar(ctx: any) {
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

function scheduleNext(pi: ExtensionAPI, ctx: any) {
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
function onBeatDue(pi: ExtensionAPI, ctx: any) {
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
function fireReminder(pi: ExtensionAPI, ctx: any) {
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

function scheduleOneShot(pi: ExtensionAPI, ctx: any, delayMs: number) {
  state.nextAt = Date.now() + delayMs;
  oneShotTimerId = setTimeout(() => {
    if (!state.active || state.paused) return;
    // Same idle-only rule as recurring: shift while busy, fire when idle.
    onBeatDue(pi, ctx);
  }, delayMs);
}

// ── Safe ctx.ui wrappers (guard stale proxy + missing ui) ─────
/** Returns false when the context went stale (callers may stop their timers). */
function safeSetStatus(ctx: any, value: string | undefined): boolean {
  try { ctx.ui.setStatus(STATUS_KEY, value); return true; } catch (e) { if (!isStaleCtxError(e)) throw e; return false; }
}
function safeNotify(ctx: any, msg: string, level: "info" | "warning" | "error" | "success" = "info") {
  try { ctx.ui.notify(msg, level); } catch (e) { if (!isStaleCtxError(e)) throw e; }
}

// ── Config persistence (survives reload / branch switch) ──────
function persist(pi: ExtensionAPI) {
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

// ── Centralized control (used by command AND tool) ────────────
export interface ControlOpts {
  action: "start" | "status" | "stop" | "message" | "time" | "pause" | "resume" | "help";
  message?: string;
  duration?: string;       // "30s" | "5m" | "2h" | "1d"
  maxCount?: number;       // 0 = forever
  once?: boolean;          // one-shot: fire once after duration, then stop
  file?: string;
  lines?: number;
}

export interface ControlResult {
  text: string;            // human-facing summary
  level: "info" | "warning" | "error" | "success";
  state: StateSnapshot;
}

function control(pi: ExtensionAPI, ctx: any, o: ControlOpts): ControlResult {
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
      state.lastAt = Date.now();
      state.nextAt = Date.now() + ms;
      scheduleNext(pi, ctx);
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
    if (!existsSync(fp)) throw new Error(`File not found: ${o.file}`);
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
    if (state.maxCount > 0) {
      throw new Error("Cannot use --once with --limit. Use one or the other.");
    }
    startStatusBar(ctx);
    scheduleOneShot(pi, ctx, intervalMs);
  } else {
    startStatusBar(ctx);
    scheduleNext(pi, ctx);
  }
  persist(pi);

  const modeLabel = o.once ? "one-shot" : "recurring";
  const freqLabel = o.once ? "" : ` (every ${humanDuration(intervalMs)})`;
  const limitLabel = state.maxCount > 0 ? `${state.maxCount} reminder${state.maxCount === 1 ? "" : "s"}` : "forever";
  const title = restarting ? "🔄 Heartbeat Restarted" : "✅ Heartbeat Started";
  const restartHint = restarting ? "  (previous heartbeat overridden)" : "";
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

// ── Raw-string parser for the slash command ──────────────────
// (moved to ./lib/heartbeat-parse.ts — pure functions, unit-tested
//  by tests/heartbeat/test.sh without the pi runtime)

// ── Extension entry point ────────────────────────────────────
export default function (pi: ExtensionAPI) {
  // Fresh module state. Timers of a previous module instance live in a
  // different scope and cannot be reached from here — pi loads extensions
  // once per process, so this only matters for hot-reload setups.
  resetTimers();

  // Reconstruct config from session entries on each lifecycle event (§6, §19.3).
  // Timers are NOT auto-restarted — they are process-global and a resumed/
  // branched session re-starts on demand via command/tool.
  const restore = (ctx: any) => {
    resetAll();
    try {
      const saved = reconstructLastCustomEntry(ctx, ENTRY_TYPE);
      if (saved) {
        if (typeof saved.message === "string") state.message = saved.message;
        if (typeof saved.intervalMs === "number" && saved.intervalMs > 0) state.intervalMs = saved.intervalMs;
        if (typeof saved.maxCount === "number") state.maxCount = saved.maxCount;
        if (typeof saved.paused === "boolean") state.paused = saved.paused;
        if (typeof saved.once === "boolean") state.once = saved.once;
      }
    } catch { /* best-effort */ }
  };

  pi.on("session_start", (_e, ctx) => restore(ctx));
  pi.on("session_tree", (_e, ctx) => restore(ctx));
  pi.on("session_compact", (_e, ctx) => restore(ctx));
  pi.on("session_shutdown", () => resetAll());

  // ── Busy/idle tracking: only fire heartbeats when pi is idle ──
  // turn_start → busy (pi is mid-turn: LLM response + tool calls). turn_end → idle.
  // A beat due while busy is SHIFTED by one interval (capped at 5 min, not consumed) and re-checked,
  // so long agent runs push the beat out instead of stacking a burst mid-work.
  // Safety: if no turn_end arrives within BUSY_STUCK_MS (crash/reload ate the
  // turn_end event), busy is treated as idle instead of shifting forever.
  pi.on("turn_start", (_e) => {
    state.busy = true;
    state.busySince = Date.now();
  });
  pi.on("turn_end", (_e) => {
    state.busy = false;
  });

  // ── Human slash command: /heartbeat … ─────────────────────
  pi.registerCommand("heartbeat", {
    description: "Recurring reminder. /heartbeat 30s | \"msg\" | -f file.md | message <txt> | time <dur> | status | off",
    handler: async (args: unknown, ctx: any) => {
      const raw = typeof args === "string" ? args.trim() : "";
      const opts = parseCommand(raw);
      try {
        const res = control(pi, ctx, opts);
        safeNotify(ctx, res.text, res.level);
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
      "(--once) and pause/resume. The agent can use this to set up periodic check-ins, " +
      "nudges, or to adjust an existing heartbeat the user started.",
    promptSnippet: "Start/stop/pause/resume/adjust a recurring reminder timer (heartbeat)",
    promptGuidelines: [
      "Use the heartbeat tool when the user wants a recurring reminder, nudge, or periodic check-in " +
        "(e.g. 'remind me every 5 minutes', 'ping me every 30s while I wait').",
      "Use action 'start' with duration like '30s', '5m', '2h', '1d' and an optional message; " +
        "maxCount stops after N pings (0 = forever). Use 'once:true' for a single reminder after a delay.",
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
      lines: Type.Optional(Type.Number({ description: "Cap lines read from --file. For action 'start'." })),
    }),
    async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
      const res = control(pi, ctx, params as ControlOpts);
      // Also surface result to the human via the status line / notify.
      safeNotify(ctx, res.text, res.level);
      return {
        content: [{ type: "text", text: res.text }],
        // Full state in details → correct on fork/branch (§6).
        details: { heartbeat: res.state },
      };
    },
  });

  pi.registerTool(heartbeatTool);
}
