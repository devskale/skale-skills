#!/usr/bin/env node

/**
 * Background Monitoring Script for Playwright
 *
 * This script monitors console, errors, and network events from browser pages.
 * Logs are written to JSONL files in ~/.cache/agent-web/logs/YYYY-MM-DD/
 */

import { chromium } from "playwright";
import { existsSync, mkdirSync, writeFileSync, readFileSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const LOG_ROOT = join(homedir(), ".cache/agent-web/logs");
const PID_FILE = join(LOG_ROOT, ".pid");

function ensureDir(dir) {
  if (!existsSync(dir)) {
    mkdirSync(dir, { recursive: true });
  }
}

function isProcessAlive(pid) {
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
}

function getDateDir() {
  const now = new Date();
  const yyyy = String(now.getFullYear());
  const mm = String(now.getMonth() + 1).padStart(2, "0");
  const dd = String(now.getDate()).padStart(2, "0");
  return join(LOG_ROOT, `${yyyy}-${mm}-${dd}`);
}

function safeFileName(value) {
  return value.replace(/[^a-zA-Z0-9._-]/g, "_");
}

function compactStack(stackTrace) {
  if (!stackTrace || !Array.isArray(stackTrace)) return null;
  return stackTrace.slice(0, 8).map((frame) => ({
    functionName: frame.functionName || null,
    url: frame.url || null,
    lineNumber: frame.lineNumber,
    columnNumber: frame.columnNumber,
  }));
}

ensureDir(LOG_ROOT);

if (existsSync(PID_FILE)) {
  try {
    const existing = Number(readFileSync(PID_FILE, "utf8").trim());
    if (existing && isProcessAlive(existing)) {
      console.log("✓ watch already running");
      process.exit(0);
    }
  } catch {
  }
}

writeFileSync(PID_FILE, String(process.pid));

const dateDir = getDateDir();
ensureDir(dateDir);

function getLogPath(targetId) {
  const filename = `${safeFileName(targetId)}.jsonl`;
  return join(dateDir, filename);
}

function writeLog(targetId, payload) {
  const filepath = getLogPath(targetId);
  const record = {
    ts: new Date().toISOString(),
    targetId,
    ...payload,
  };
  writeFileSync(filepath, JSON.stringify(record) + "\n", { flag: "a" });
}

async function main() {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    viewport: { width: 1920, height: 1080 },
  });

  context.on("page", async (page) => {
    const targetId = `page-${Date.now()}`;
    writeLog(targetId, {
      type: "target.attached",
      url: page.url(),
    });

    page.on("console", (msg) => {
      writeLog(targetId, {
        type: "console",
        level: msg.type(),
        text: msg.text(),
      });
    });

    page.on("pageerror", (error) => {
      writeLog(targetId, {
        type: "exception",
        text: error.message,
        stack: error.stack,
      });
    });

    page.on("request", (request) => {
      writeLog(targetId, {
        type: "network.request",
        method: request.method(),
        url: request.url(),
        resourceType: request.resourceType(),
      });
    });

    page.on("response", async (response) => {
      writeLog(targetId, {
        type: "network.response",
        url: response.url(),
        status: response.status(),
        statusText: response.statusText(),
      });
    });

    page.on("requestfailed", (request) => {
      writeLog(targetId, {
        type: "network.failure",
        url: request.url(),
        error: request.failure()?.errorText,
      });
    });
  });

  const page = await context.newPage();
  writeLog(`page-${Date.now()}`, { type: "target.info", url: page.url() });

  console.log("✓ watch started");

  process.on("SIGINT", async () => {
    await browser.close();
    process.exit(0);
  });
}

main().catch((e) => {
  console.error("✗ watch failed:", e.message);
  process.exit(1);
});
