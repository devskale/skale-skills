/**
 * Heartbeat Extension — recurring reminder that fires every N seconds.
 *
 * Sends a follow-up message to the agent on each tick, and shows a
 * countdown progress bar in the status line.
 *
 * Usage:
 *   /heartbeat 30s              → start with 30s interval (default message)
 *   /heartbeat "Focus on X"     → start with custom message (60s)
 *   /heartbeat 30s "msg"        → both
 *   /heartbeat -f file.md       → start, message read from file
 *   /heartbeat -f file.md --limit 100  → limit lines read from file
 *   /heartbeat status           → show status
 *   /heartbeat off              → stop
 *
 * Requires pi ≥ 0.79 (uses ExtensionAPI.registerCommand + ctx.ui.setStatus).
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { join } from "node:path";
import { existsSync, readFileSync } from "node:fs";

// ── State (module-level, reset on session events) ─────────────
let active = false;
let message = "Time to check in — what are you working on?";
let intervalMs = 60000;
let timerId: ReturnType<typeof setTimeout> | undefined;
let statusTimerId: ReturnType<typeof setInterval> | undefined;
let startedAt = 0;
let lastAt = 0;
let nextAt = 0;
let count = 0;

function reset() {
  if (timerId) clearTimeout(timerId);
  if (statusTimerId) clearInterval(statusTimerId);
  active = false;
  timerId = undefined;
  statusTimerId = undefined;
}

/** One-line status for the footer: "⏰ 42s [██████░░░░] #3" */
function statusLine(): string {
  const rem = Math.max(0, Math.floor((nextAt - Date.now()) / 1000));
  const tot = Math.floor(intervalMs / 1000);
  const pct = tot > 0 ? Math.round(((tot - rem) / tot) * 100) : 0;
  const f = Math.round(pct / 10);
  return `⏰ ${rem}s [${"█".repeat(f)}${"░".repeat(10 - f)}] #${count}`;
}

export default function (pi: ExtensionAPI) {
  // Kill stale timers from previous extension loads
  reset();

  pi.on("session_start", () => reset());
  pi.on("session_tree", () => reset());
  pi.on("session_shutdown", () => reset());

  // Reminder loop — started by the command, reschedules itself
  function scheduleNext(ctx: any) {
    if (!active) return;
    const d = Math.max(0, intervalMs - (Date.now() - lastAt));
    nextAt = Date.now() + d;
    timerId = setTimeout(() => {
      if (!active) return;
      count++;
      lastAt = Date.now();
      nextAt = Date.now() + intervalMs;
      pi.sendUserMessage(`⏰ **Heartbeat #${count}**\n\n${message}`, { deliverAs: "followUp" });
      scheduleNext(ctx);
    }, d);
  }

  // ── /heartbeat command ──────────────────────────────────────
  // `args` is the raw string after "/heartbeat " (per pi docs)
  pi.registerCommand("heartbeat", {
    description: "Recurring reminder. /heartbeat 30s | \"msg\" | -f file.md | status | off",
    handler: async (args: unknown, ctx: any) => {
      const raw = typeof args === "string" ? args.trim() : "";
      const first = raw.match(/^\s*(\S+)/)?.[1] ?? "";

      // /heartbeat status
      if (first === "status") {
        if (!active) {
          ctx.ui.notify("No heartbeat active", "info");
          return;
        }
        const elapsed = Math.floor((Date.now() - startedAt) / 1000);
        ctx.ui.notify(
          [
            "✅ Heartbeat Active",
            `  message: ${message}`,
            `  interval: ${intervalMs / 1000}s`,
            `  running: ${elapsed}s | sent: ${count}`,
            `  ${statusLine()}`,
          ].join("\n"),
          "info",
        );
        return;
      }

      // /heartbeat off | stop
      if (first === "off" || first === "stop") {
        if (!active) {
          ctx.ui.notify("No heartbeat active", "warning");
          return;
        }
        reset();
        try { ctx.ui.setStatus("heartbeat", undefined); } catch {}
        ctx.ui.notify("⏹ Heartbeat stopped", "success");
        return;
      }

      // ── start ────────────────────────────────────────────────
      if (!ctx.hasUI) {
        ctx.ui.notify("Heartbeat requires interactive mode", "warning");
        return;
      }

      let sec = 60;
      let msg = message;

      // /heartbeat 30s or /heartbeat 30
      const numMatch = raw.match(/(\d+)\s*s?\b/);
      if (numMatch) {
        const n = parseInt(numMatch[1], 10);
        if (n > 0) sec = n;
      }

      // /heartbeat "quoted message"
      const quoteMatch = raw.match(/["'](.+?)["']/);
      if (quoteMatch) {
        msg = quoteMatch[1];
      }

      // /heartbeat -f file.md [--limit N]
      const fileMatch = raw.match(/(?:^|\s)-f\s+(\S+)/);
      if (fileMatch) {
        const fp = fileMatch[1].startsWith("/") ? fileMatch[1] : join(process.cwd(), fileMatch[1]);
        if (!existsSync(fp)) {
          ctx.ui.notify(`Error: File not found: ${fileMatch[1]}`, "error");
          return;
        }
        const lines = readFileSync(fp, "utf-8").split("\n");
        const limitMatch = raw.match(/--limit\s+(\d+)/);
        const limit = limitMatch ? parseInt(limitMatch[1], 10) : lines.length;
        msg = lines.slice(0, limit).join("\n").trim();
      }

      reset();
      message = msg;
      intervalMs = sec * 1000;
      startedAt = Date.now();
      lastAt = Date.now();
      nextAt = Date.now() + sec * 1000;
      count = 0;
      active = true;

      // Status bar (updates every 500ms via ctx.ui)
      statusTimerId = setInterval(() => {
        if (!active) {
          try { ctx.ui.setStatus("heartbeat", undefined); } catch {}
          if (statusTimerId) clearInterval(statusTimerId);
          return;
        }
        try { ctx.ui.setStatus("heartbeat", statusLine()); } catch {}
      }, 500);

      scheduleNext(ctx);

      ctx.ui.notify(
        [
          "✅ Heartbeat Started",
          `  message: ${msg}`,
          `  interval: ${sec}s`,
          "  run /heartbeat off to stop",
        ].join("\n"),
        "success",
      );
    },
  });
}
