#!/usr/bin/env node

import { tmpdir } from "node:os";
import { join } from "node:path";
import { writeFileSync } from "node:fs";
import { chromium } from "playwright";

const DEBUG = process.env.DEBUG === "1";
const log = DEBUG ? (...args) => console.error("[debug]", ...args) : () => {};

const args = process.argv.slice(2);
const urlIndex = args.indexOf("--url");
const url = urlIndex !== -1 ? args[urlIndex + 1] : null;
const fullPage = args.includes("--full");

try {
  log("launching browser...");
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    viewport: { width: 1920, height: 1080 },
  });

  const pages = context.pages();
  const page = pages[0] || await context.newPage();

  if ((!page.url() || page.url() === "about:blank") && !url) {
    console.error("✗ No page loaded. Provide a URL with --url or navigate first with nav.js");
    await browser.close();
    process.exit(1);
  }

  if (url) {
    log("navigating...");
    await page.goto(url, { waitUntil: "networkidle", timeout: 30000 });
  }

  log("taking screenshot...");
  const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
  const filename = `screenshot-${timestamp}.png`;
  const filepath = join(tmpdir(), filename);

  await page.screenshot({ path: filepath, fullPage });
  console.log(filepath);

  log("closing...");
  await browser.close();
  log("done");
} catch (e) {
  console.error("✗", e.message);
  process.exit(1);
}
