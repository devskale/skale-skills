#!/usr/bin/env node

import { chromium, firefox, webkit } from "playwright";
import { existsSync, mkdirSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const args = process.argv.slice(2);
const headless = !args.includes("--headful");
const useProfile = args.includes("--profile");
const browserType = args.includes("--firefox") ? "firefox" : args.includes("--webkit") ? "webkit" : "chromium";

if (args.length > 0 && !["--headful", "--profile", "--firefox", "--webkit"].includes(args[0])) {
  console.log("Usage: start.js [--headful] [--profile] [--firefox] [--webkit]");
  console.log("\nOptions:");
  console.log("  --headful  Show browser window (default: headless)");
  console.log("  --profile  Use persistent context (cookies, logins)");
  console.log("  --firefox  Use Firefox instead of Chrome");
  console.log("  --webkit   Use WebKit (Safari) instead of Chrome");
  console.log("\nExamples:");
  console.log("  start.js               # Headless Chrome");
  console.log("  start.js --headful     # Visible Chrome");
  console.log("  start.js --profile     # Chrome with persistent context");
  console.log("  start.js --firefox     # Firefox");
  process.exit(1);
}

const CACHE_DIR = join(homedir(), ".cache", "play-browser");
const PID_FILE = join(CACHE_DIR, ".pid");
const PROFILE_DIR = join(CACHE_DIR, "profile");

mkdirSync(CACHE_DIR, { recursive: true });

async function main() {
  const browser = browserType === "firefox" ? await firefox.launch({ headless }) :
                  browserType === "webkit" ? await webkit.launch({ headless }) :
                  await chromium.launch({ headless });

  const contextOptions = {
    viewport: { width: 1920, height: 1080 },
    userAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
  };

  if (useProfile) {
    contextOptions.storageState = join(PROFILE_DIR, "state.json");
    mkdirSync(PROFILE_DIR, { recursive: true });
  }

  const context = await browser.newContext(contextOptions);
  const page = await context.newPage();

  writeFileSync(PID_FILE, String(process.pid));

  console.log(`✓ ${browserType} started (${headless ? "headless" : "headful"})${useProfile ? " with persistent context" : ""}`);

  process.on("SIGINT", async () => {
    console.log("\nShutting down...");
    await context.close();
    await browser.close();
    process.exit(0);
  });

  process.on("SIGTERM", async () => {
    await context.close();
    await browser.close();
    process.exit(0);
  });
}

main().catch((e) => {
  console.error("✗ Failed to start browser:", e.message);
  process.exit(1);
});
