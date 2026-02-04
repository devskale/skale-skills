#!/usr/bin/env node

import { chromium } from "playwright";

const DEBUG = process.env.DEBUG === "1";
const log = DEBUG ? (...args) => console.error("[debug]", ...args) : () => {};

const url = process.argv[2];
const newTab = process.argv.includes("--new");

if (!url) {
  console.log("Usage: nav.js <url> [--new]");
  console.log("\nExamples:");
  console.log("  nav.js https://example.com       # Navigate in current browser");
  console.log("  nav.js https://example.com --new # Open in new tab");
  process.exit(1);
}

try {
  log("launching browser...");
  const browser = await chromium.launch({
    headless: true,
  });
  const context = await browser.newContext({
    viewport: { width: 1920, height: 1080 },
  });

  log("navigating...");
  const page = await context.newPage();
  
  await page.goto(url, { waitUntil: "load", timeout: 30000 });
  await page.waitForTimeout(2000);

  console.log("✓ Navigated to:", url);

  log("closing...");
  await browser.close();
  log("done");
} catch (e) {
  console.error("✗", e.message);
  process.exit(1);
}
