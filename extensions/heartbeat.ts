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
 *   /heartbeat message <text>      change message live
 *   /heartbeat time <duration>     change interval live (30s | 5m | 2h | 1d)
 *   /heartbeat status              show status
 *   /heartbeat off                 stop
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

const DEFAULT_MESSAGE = "Time to check in — what are you working on?";
const STATUS_KEY = "heartbeat";
const ENTRY_TYPE = "heartbeat:config";

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
};

let timerId: ReturnType<typeof setTimeout> | undefined;
let statusTimerId: ReturnType<typeof setInterval> | undefined;

/** Snapshot of state for tool `details` and reconstruction (no timers). */
type StateSnapshot = Omit<HBState, never>;

function snapshot(): StateSnapshot {
  return { ...state };
}

/** Stop the running heartbeat and clear all timers. Does not touch message/interval. */
function resetTimers() {
  if (timerId) clearTimeout(timerId);
  if (statusTimerId) clearInterval(statusTimerId);
  timerId = undefined;
  statusTimerId = undefined;
  state.active = false;
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
}

function isStaleError(e: unknown): boolean {
  return /stale after session replacement/i.test(String(e));
}

// ── Formatting helpers ────────────────────────────────────────
function statusLine(): string {
  const rem = Math.max(0, Math.floor((state.nextAt - Date.now()) / 1000));
  const tot = Math.floor(state.intervalMs / 1000);
  const pct = tot > 0 ? Math.round(((tot - rem) / tot) * 100) : 0;
  const f = Math.round(pct / 10);
  return `⏰ ${rem}s [${"█".repeat(f)}${"░".repeat(10 - f)}] #${state.count}`;
}

/** Parse a human duration into ms. Units: s, m, h, d (bare = seconds). null if invalid. */
function parseDuration(str: string): number | null {
  const m = str.match(/^(\d+)\s*([smhd])?$/i);
  if (!m) return null;
  const num = parseInt(m[1], 10);
  if (!Number.isFinite(num) || num <= 0) return null;
  const unit = (m[2] ?? "s").toLowerCase();
  const mult =
    unit === "d" ? 86_400_000
    : unit === "h" ? 3_600_000
    : unit === "m" ? 60_000
    : 1_000;
  return num * mult;
}

/** Human-readable duration, e.g. 90s → "1m 30s", 90061s → "1d 1h". */
function humanDuration(ms: number): string {
  const s = Math.floor(ms / 1000);
  const d = Math.floor(s / 86400);
  const h = Math.floor((s % 86400) / 3600);
  const m = Math.floor((s % 3600) / 60);
  const sec = s % 60;
  const parts: string[] = [];
  if (d) parts.push(`${d}d`);
  if (h) parts.push(`${h}h`);
  if (m) parts.push(`${m}m`);
  if (sec || parts.length === 0) parts.push(`${sec}s`);
  return parts.join(" ");
}

// ── Timer scheduling (stale-ctx safe) ─────────────────────────
/** Start the status-bar ticker. Assumes state is already set. Does NOT touch state.active. */
function startStatusBar(ctx: any) {
  if (statusTimerId) clearInterval(statusTimerId);
  statusTimerId = setInterval(() => {
    if (!state.active) {
      safeSetStatus(ctx, undefined);
      if (statusTimerId) clearInterval(statusTimerId);
      return;
    }
    safeSetStatus(ctx, statusLine());
  }, 500);
}

function scheduleNext(pi: ExtensionAPI, ctx: any) {
  if (!state.active) return;
  const d = Math.max(0, state.intervalMs - (Date.now() - state.lastAt));
  state.nextAt = Date.now() + d;
  timerId = setTimeout(() => {
    if (!state.active) return;
    state.count++;
    state.lastAt = Date.now();
    state.nextAt = Date.now() + state.intervalMs;
    try {
      pi.sendUserMessage(`⏰ **Heartbeat #${state.count}**\n\n${state.message}`, { deliverAs: "followUp" });
    } catch (e) {
      if (isStaleError(e)) { resetTimers(); return; }
      throw e;
    }

    // Auto-stop after maxCount heartbeats (0 = never)
    if (state.maxCount > 0 && state.count >= state.maxCount) {
      const total = state.count;
      resetTimers();
      safeSetStatus(ctx, undefined);
      safeNotify(ctx, `⏹ Heartbeat finished after ${total} reminder${total === 1 ? "" : "s"}.`, "success");
      persist(pi);
      return;
    }
    scheduleNext(pi, ctx);
  }, d);
}

// ── Safe ctx.ui wrappers (guard stale proxy + missing ui) ─────
function safeSetStatus(ctx: any, value: string | undefined) {
  try { ctx.ui.setStatus(STATUS_KEY, value); } catch (e) { if (!isStaleError(e)) throw e; }
}
function safeNotify(ctx: any, msg: string, level: "info" | "warning" | "error" | "success" = "info") {
  try { ctx.ui.notify(msg, level); } catch (e) { if (!isStaleError(e)) throw e; }
}

// ── Config persistence (survives reload / branch switch) ──────
function persist(pi: ExtensionAPI) {
  try {
    pi.appendEntry(ENTRY_TYPE, {
      active: state.active,
      message: state.message,
      intervalMs: state.intervalMs,
      maxCount: state.maxCount,
    });
  } catch { /* appendEntry best-effort */ }
}

function reconstruct(ctx: any): { active: boolean; message: string; intervalMs: number; maxCount: number } | null {
  try {
    let last: any = null;
    for (const entry of ctx?.sessionManager?.getEntries?.() ?? []) {
      if (entry?.type === "custom" && entry?.customType === ENTRY_TYPE) last = entry.data;
    }
    return last;
  } catch {
    return null;
  }
}

// ── Centralized control (used by command AND tool) ────────────
export interface ControlOpts {
  action: "start" | "status" | "stop" | "message" | "time";
  message?: string;
  duration?: string;       // "30s" | "5m" | "2h" | "1d"
  maxCount?: number;       // 0 = forever
  file?: string;
  lines?: number;
}

export interface ControlResult {
  text: string;            // human-facing summary
  level: "info" | "warning" | "error" | "success";
  state: StateSnapshot;
}

function control(pi: ExtensionAPI, ctx: any, o: ControlOpts): ControlResult {
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
      `  ${statusLine()}`,
    ].join("\n");
    return { text, level: "info", state: snapshot() };
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
  state.startedAt = Date.now();
  state.lastAt = Date.now();
  state.nextAt = Date.now() + intervalMs;
  state.count = 0;

  startStatusBar(ctx);
  scheduleNext(pi, ctx);
  persist(pi);

  return {
    text: [
      "✅ Heartbeat Started",
      `  message: ${msg}`,
      `  interval: ${humanDuration(intervalMs)}`,
      `  limit: ${state.maxCount > 0 ? `${state.maxCount} reminder${state.maxCount === 1 ? "" : "s"}` : "forever"}`,
      "  run /heartbeat off to stop",
    ].join("\n"),
    level: "success",
    state: snapshot(),
  };
}

// ── Raw-string parser for the slash command ──────────────────
function parseCommand(raw: string): ControlOpts {
  const first = raw.match(/^\s*(\S+)/)?.[1] ?? "";

  if (first === "status") return { action: "status" };
  if (first === "off" || first === "stop") return { action: "stop" };

  if (first === "message") {
    const rest = raw.slice("message".length).trim();
    return rest ? { action: "message", message: rest.replace(/^["']|["']$/g, "") } : { action: "message" };
  }

  if (first === "time") {
    const rest = raw.slice("time".length).trim();
    const dur = rest.match(/^(\S+)/)?.[1] ?? "";
    return dur ? { action: "time", duration: dur } : { action: "time" };
  }

  // start: optional duration, optional "message", optional -f, optional --limit
  const opts: ControlOpts = { action: "start" };
  const durTok = parseDuration(first);
  if (durTok) opts.duration = first;

  const quoteMatch = raw.match(/["'](.+?)["']/);
  if (quoteMatch) opts.message = quoteMatch[1];

  const fileMatch = raw.match(/(?:^|\s)-f\s+(\S+)/);
  if (fileMatch) opts.file = fileMatch[1];
  const linesMatch = raw.match(/--lines\s+(\d+)/);
  if (linesMatch) opts.lines = parseInt(linesMatch[1], 10);

  const limitMatch = raw.match(/--limit\s+(\d+)/);
  if (limitMatch) opts.maxCount = parseInt(limitMatch[1], 10);

  return opts;
}

// ── Extension entry point ────────────────────────────────────
export default function (pi: ExtensionAPI) {
  // Kill stale timers from any previous load of this module
  resetTimers();

  // Reconstruct config from session entries on each lifecycle event (§6, §19.3).
  // Timers are NOT auto-restarted — they are process-global and a resumed/
  // branched session re-starts on demand via command/tool.
  const restore = (ctx: any) => {
    resetAll();
    try {
      const saved = reconstruct(ctx);
      if (saved) {
        if (typeof saved.message === "string") state.message = saved.message;
        if (typeof saved.intervalMs === "number" && saved.intervalMs > 0) state.intervalMs = saved.intervalMs;
        if (typeof saved.maxCount === "number") state.maxCount = saved.maxCount;
      }
    } catch { /* best-effort */ }
  };

  pi.on("session_start", (_e, ctx) => restore(ctx));
  pi.on("session_tree", (_e, ctx) => restore(ctx));
  pi.on("session_compact", (_e, ctx) => restore(ctx));
  pi.on("session_shutdown", () => resetAll());

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
      "Control a recurring reminder timer. Starts, stops, reconfigures, or queries a " +
      "heartbeat that sends a follow-up message every N seconds (default 60s) with a " +
      "custom message, and shows a countdown in the status line. The agent can use this " +
      "to set up periodic check-ins, nudges, or to adjust an existing heartbeat the user started.",
    promptSnippet: "Start/stop/adjust a recurring reminder timer (heartbeat)",
    promptGuidelines: [
      "Use the heartbeat tool when the user wants a recurring reminder, nudge, or periodic check-in " +
        "(e.g. 'remind me every 5 minutes', 'ping me every 30s while I wait').",
      "Use action 'start' with duration like '30s', '5m', '2h', '1d' and an optional message; " +
        "maxCount stops after N pings (0 = forever).",
      "Use action 'time' or 'message' to change an already-running heartbeat live, 'status' to " +
        "inspect it, and 'stop' to end it.",
    ],
    parameters: Type.Object({
      action: StringEnum(["start", "status", "stop", "message", "time"] as const),
      message: Type.Optional(Type.String({ description: "Reminder text (for action 'start' or 'message')" })),
      duration: Type.Optional(Type.String({
        description: "Interval, e.g. '30s', '5m', '2h', '1d' (bare number = seconds). For actions 'start' and 'time'.",
      })),
      maxCount: Type.Optional(Type.Number({
        description: "Auto-stop after this many reminders. 0 (default) = run forever. For action 'start'.",
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
