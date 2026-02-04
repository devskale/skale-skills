#!/usr/bin/env node

import { chromium } from "playwright";

const DEBUG = process.env.DEBUG === "1";
const log = DEBUG ? (...args) => console.error("[debug]", ...args) : () => {};

const args = process.argv.slice(2);
const urlIndex = args.indexOf("--url");
const url = urlIndex !== -1 ? args[urlIndex + 1] : null;
const code = urlIndex !== -1 ? args.slice(0, urlIndex).concat(args.slice(urlIndex + 2)).join(" ") : args.join(" ");

if (!code) {
  console.log("Usage: eval.js 'code' [--url <url>]");
  console.log("\nExamples:");
  console.log('  eval.js "document.title"');
  console.log("  eval.js \"document.querySelectorAll('a').length\"");
  console.log('  eval.js "document.title" --url https://example.com');
  process.exit(1);
}

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

  log("evaluating...");
  const result = await page.evaluate(code);

  log("formatting result...");
  if (Array.isArray(result)) {
    for (let i = 0; i < result.length; i++) {
      if (i > 0) console.log("");
      for (const [key, value] of Object.entries(result[i])) {
        console.log(`${key}: ${value}`);
      }
    }
  } else if (typeof result === "object" && result !== null) {
    for (const [key, value] of Object.entries(result)) {
      console.log(`${key}: ${value}`);
    }
  } else {
    console.log(result);
  }

  log("closing...");
  await browser.close();
  log("done");
} catch (e) {
  console.error("✗", e.message);
  process.exit(1);
}
