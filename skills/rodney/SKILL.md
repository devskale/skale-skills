---
name: rodney
description: "Drive headless Chrome from the CLI for web scraping, screenshots, form filling, PDF export, accessibility audits, and browser smoke tests. Use when the user wants to automate browser interactions, scrape dynamic pages (JS-rendered content), take page screenshots or element screenshots, fill and submit web forms, export pages as PDF, run accessibility checks, or assert page state in CI/CD pipelines. Triggers on mentions of: browser automation, headless Chrome, web scraping, page screenshots, form automation, accessibility testing, browser testing, rodney."
---

# Rodney — Chrome Automation

Rodney drives a persistent headless Chrome instance from the terminal. All commands share one long-running Chrome process — cookies, localStorage, and navigation state persist across invocations.

## Install

```bash
uv tool install rodney
```

Requires Chrome or Chromium. Set `ROD_CHROME_BIN` if not at default location.

## Quick Start

```bash
rodney start                          # Launch headless Chrome
rodney start --show                   # Launch visible Chrome (for debugging)
rodney open https://example.com       # Navigate
rodney text "h1"                      # Extract text
rodney screenshot page.png            # Screenshot
rodney stop                           # Shut down
```

## Commands

### Navigation & Waiting

```bash
rodney open <url>           # Navigate (auto-adds http://)
rodney back                 # Go back
rodney forward              # Go forward
rodney reload [--hard]      # Reload (bypass cache with --hard)
rodney wait <selector>      # Wait for element to appear
rodney waitload             # Wait for page load event
rodney waitstable           # Wait until DOM stops changing
rodney waitidle             # Wait for network idle
rodney sleep <seconds>      # Fixed delay
```

### Content Extraction

```bash
rodney title                        # Page title
rodney url                          # Current URL
rodney text <selector>              # Text content (one per match)
rodney html [selector]              # HTML (full page or element)
rodney attr <selector> <name>       # Attribute value
rodney js <expression>              # Evaluate JS, return result
```

### Screenshots & PDFs

```bash
rodney screenshot [-w N -h N] [file]         # Viewport screenshot
rodney screenshot-el <selector> [file]        # Element screenshot
rodney pdf [file]                             # Export as PDF
```

### Interaction

```bash
rodney click <selector>            # Click element
rodney input <selector> <text>     # Type into input
rodney clear <selector>            # Clear input
rodney select <selector> <value>   # Select dropdown option
rodney submit <selector>           # Submit form
rodney hover <selector>            # Hover
rodney file <selector> <path>      # Set file on file input
rodney download <selector> [file]  # Download href/src target
```

### Tabs

```bash
rodney pages                # List tabs (* marks active)
rodney page <index>         # Switch tab
rodney newpage [url]        # Open new tab
rodney closepage [index]    # Close tab
```

### Assertions (exit 1 on failure)

```bash
rodney exists <selector>                        # Element exists?
rodney visible <selector>                       # Element visible?
rodney count <selector>                         # Count matches
rodney assert <expr> [expected] [-m msg]        # JS truthy or equality check
```

### Accessibility

```bash
rodney ax-tree [--depth N] [--json]             # Dump accessibility tree
rodney ax-find [--name N] [--role R] [--json]   # Find accessible nodes
rodney ax-node <selector> [--json]              # Element accessibility info
```

## Sessions

| Type | State | Flag |
|------|-------|------|
| Global | `~/.rodney/` | default |
| Local | `./.rodney/` | `--local` |

Use `--local` for per-project isolation. Auto-detects local if `./.rodney/state.json` exists.

## Environment

| Variable | Default | Purpose |
|----------|---------|---------|
| `ROD_CHROME_BIN` | auto | Chrome binary path |
| `ROD_TIMEOUT` | `30` | Element query timeout (seconds) |
| `RODNEY_HOME` | `~/.rodney` | Data directory |

## Gotchas

- **Always `rodney stop`** when done — otherwise a Chrome process lingers indefinitely.
- **`waitstable` is preferred** over `waitload` for SPAs and dynamic pages — `waitload` only fires on initial navigation, not on client-side renders.
- **`js` results are stringified** — arrays and objects come back as JSON strings. Pipe through `python3 -m json.tool` or use `--json` flags where available.
- **Selectors are CSS only** — no XPath. Use `rodney js` for complex queries.
- **One Chrome process per session** — calling `rodney start` while already running is a no-op, not an error.
- **`open` auto-adds `http://`** — for `https://` URLs, include the scheme explicitly.
- **Exit codes**: 0 = success, 1 = assertion failed, 2 = error (bad args, timeout, no browser).

## References

- **[references/commands.md](references/commands.md)** — Full command reference with all flags and options. Read when you need details on a specific command.
- **[references/examples.md](references/examples.md)** — Ready-to-use workflow scripts for scraping, form filling, smoke tests, and accessibility audits.
- **[references/debugging.md](references/debugging.md)** — Non-obvious debugging patterns: screenshot time-series, form validation checks, exit code chaining, and visible-mode debugging.
- **[references/dev-workflow.md](references/dev-workflow.md)** — Dev loop: reload-assess-iterate, page inspection without screenshots, DOM structure, accessibility tree, layout queries.
