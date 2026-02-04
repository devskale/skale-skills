---
name: play-browser
description: "Allows to interact with web pages by performing actions such as clicking buttons, filling out forms, and navigating links. It works by using Playwright, a modern browser automation framework that supports Chrome, Firefox, and Safari. When Claude needs to browse the web, it can use this skill to do so."
---

# Playwright Browser Skill

Modern browser automation using Playwright - supports Chrome, Firefox, and Safari.

## Installation

First, install dependencies and Playwright browsers:

```bash
cd scripts
npm install
./install.sh  # Downloads browser binaries (Chrome, Firefox, WebKit)
```

## Start Browser

```bash
./scripts/start.js              # Headless mode (default)
./scripts/start.js --headful     # Visible browser window
./scripts/start.js --profile     # Use persistent context (cookies, logins)
./scripts/start.js --firefox     # Use Firefox instead of Chrome
./scripts/start.js --webkit      # Use WebKit (Safari)
```

Starts browser and keeps it running for subsequent commands.

## Navigate

```bash
./scripts/nav.js https://example.com
./scripts/nav.js https://example.com --new
```

Navigate current page or open new tab.

## Evaluate JavaScript

```bash
./scripts/eval.js 'document.title'
./scripts/eval.js 'document.querySelectorAll("a").length'
./scripts/eval.js 'Array.from(document.querySelectorAll("a")).map(a => ({ text: a.textContent.trim(), href: a.href }))[0]'
./scripts/eval.js 'document.title' --url https://example.com
```

Execute JavaScript in active page. Use `--url` to navigate before evaluating.

## Screenshot

```bash
./scripts/screenshot.js
./scripts/screenshot.js --full   # Full page screenshot
./scripts/screenshot.js --url https://example.com
```

Screenshot current viewport or full page, returns temp file path. Use `--url` to navigate before screenshotting.

## Pick Elements

```bash
./scripts/pick.js "Click the submit button"
```

Interactive element picker. Click to select, Cmd/Ctrl+Click for multi-select, Enter to finish.

## Dismiss Cookie Dialogs

```bash
./scripts/dismiss-cookies.js          # Accept cookies
./scripts/dismiss-cookies.js --reject # Reject cookies (where possible)
./scripts/dismiss-cookies.js --url https://example.com  # Navigate then dismiss
```

Automatically dismisses EU cookie consent dialogs. Supports common CMPs: OneTrust, Cookiebot, Didomi, Quantcast, Google, BBC, Amazon, etc.

## Background Monitoring (Console + Errors + Network)

Logs are automatically written to:

```
~/.cache/agent-web/logs/YYYY-MM-DD/<targetId>.jsonl
```

View logs:
```bash
./scripts/logs-tail.js           # dump current log and exit
./scripts/logs-tail.js --follow  # keep following
```

Summarize network responses:
```bash
./scripts/net-summary.js
```
