---
name: jodney
version: "1.0.0"
description: "Drive a persistent headless Chrome from the CLI for web scraping, screenshots, form filling, PDF export, and accessibility audits — one long-running Chrome process keeps cookies, localStorage, and navigation state across calls. Use when the user wants to automate browser interactions, scrape JS-rendered pages, take screenshots, fill forms, export PDFs, or run browser smoke tests in CI. Triggers on: headless Chrome, browser automation, web scraping, page screenshot, form automation, accessibility audit, browser smoke test, jodney."
---

# Jodney — Chrome Automation

Jodney drives a persistent headless Chrome instance from the terminal. All commands share one long-running Chrome process — cookies, localStorage, and navigation state persist across invocations.

## ⚠️ Usage: CLI Only — NOT an MCP Tool

Jodney is a **CLI tool**, not an MCP server. Use it via the **bash** tool only. Never call `mcp("jodney")`.

Every jodney session follows this pattern via bash:

```bash
jodney start                              # 1. Launch Chrome
jodney open <url>                         # 2. Navigate
jodney waitstable                         # 3. Wait for page to settle
# ... interact, scrape, screenshot ...     # 4. Do your work
jodney stop                               # 5. ALWAYS stop when done
```

**Important:**
- Call each command as a separate bash invocation (e.g. `jodney start`, then `jodney open <url>`, etc.)
- **Always `jodney stop`** when finished — otherwise Chrome runs forever
- Combine start → open → waitstable → work → stop in every workflow
- Other lifecycle commands: `jodney connect <host:port>` (attach to an already-running Chrome on a debug port), `jodney status` (browser info + active page)

> **Command list is a curated snapshot — run `jodney --help` for the source of truth.** Jodney is an external dep that self-updates via `uv`, so the installed binary can be newer than these docs. If a command below seems missing, prints an error, or you suspect a newer flag exists, check `jodney --help` first.

## Install

```bash
uv tool install jodney
```

Requires Chrome or Chromium. Set `ROD_CHROME_BIN` if not at default location.

## Project Setup

To add jodney to a project, add this to the project's AGENTS.md:

```markdown
## Browser Automation

Use jodney for headless Chrome automation (scraping, screenshots, forms, PDFs, a11y, smoke tests).

### Setup
1. Install: `uv tool install jodney`
2. Verify: `jodney start && jodney stop`
3. Link skill: `ln -s /path/to/skale-skills/skills/jodney .pi/skills/jodney`

### Usage
```bash
jodney start
jodney open https://example.com
jodney waitstable
jodney screenshot page.png
jodney stop
```
```

## Quick Start

```bash
jodney start                          # Launch headless Chrome
jodney start --show                   # Launch visible Chrome (for debugging)
jodney open https://example.com       # Navigate
jodney text "h1"                      # Extract text
jodney screenshot page.png            # Screenshot
jodney stop                           # Shut down
```

## Commands

### Navigation & Waiting

```bash
jodney open <url>           # Navigate (auto-adds http://)
jodney back                 # Go back
jodney forward              # Go forward
jodney reload [--hard]      # Reload (bypass cache with --hard)
jodney wait <selector>      # Wait for element to appear
jodney waitload             # Wait for page load event
jodney waitstable           # Wait until DOM stops changing
jodney waitidle             # Wait for network idle
jodney sleep <seconds>      # Fixed delay
```

### Content Extraction

```bash
jodney title                        # Page title
jodney url                          # Current URL
jodney text <selector>              # Text content (one per match)
jodney html [selector]              # HTML (full page or element)
jodney attr <selector> <name>       # Attribute value
jodney js <expression>              # Evaluate JS, return result
```

### Screenshots & PDFs

```bash
jodney screenshot [-w N -h N] [file]         # Viewport screenshot
jodney screenshot-el <selector> [file]        # Element screenshot
jodney pdf [file]                             # Export as PDF
```

### Interaction

```bash
jodney click <selector>            # Click element
jodney input <selector> <text>     # Type into input
jodney clear <selector>            # Clear input
jodney select <selector> <value>   # Select dropdown option
jodney submit <selector>           # Submit form
jodney hover <selector>            # Hover
jodney file <selector> <path>      # Set file on file input
jodney download <selector> [file]  # Download href/src target
```

### Cookies

```bash
jodney cookie-set <name> <value> [opts]   # Set a cookie (defaults to current page)
jodney cookie-get [name] [--json]         # Get cookie value by name, or all as JSON
jodney cookie-delete <name> [opts]        # Delete cookies by name
jodney cookie-clear [--domain <dom>]      # Clear all cookies (or one domain)
```

`cookie-set` options: `--domain <dom>`, `--url <url>`, `--path <path>`, `--secure`, `--httponly`, `--samesite <Strict|Lax|None>`, `--expires <unix>`.
`cookie-delete` options: `--domain <dom>`, `--url <url>`, `--path <path>`.

### Emulation

```bash
jodney ua <user-agent>              # Override browser user agent string
jodney timezone <timezone-id>       # Override timezone (e.g. "Asia/Tokyo")
jodney locale <locale>              # Override locale (e.g. "de-DE")
jodney geo --lat N --lon N          # Spoof geolocation coordinates
jodney media [--type T] [--feature name=value ...]  # Emulate media type/features
```

`media` examples: `jodney media --type print` (print media), `jodney media --feature prefers-color-scheme=dark`.

### Video Recording

```bash
jodney start-video              # Start recording video of the active page
jodney stop-video [file]        # Stop and save (.gif default, .mp4 needs ffmpeg)
```

### Tabs

```bash
jodney pages                # List tabs (* marks active)
jodney page <index>         # Switch tab
jodney newpage [url]        # Open new tab
jodney closepage [index]    # Close tab
```

### Assertions (exit 1 on failure)

```bash
jodney exists <selector>                        # Element exists?
jodney visible <selector>                       # Element visible?
jodney count <selector>                         # Count matches
jodney assert <expr> [expected] [-m msg]        # JS truthy or equality check
```

### Accessibility

```bash
jodney ax-tree [--depth N] [--json]             # Dump accessibility tree
jodney ax-find [--name N] [--role R] [--json]   # Find accessible nodes
jodney ax-node <selector> [--json]              # Element accessibility info
```

## Sessions

| Type | State | Flag |
|------|-------|------|
| Global | `~/.jodney/` | default |
| Local | `./.jodney/` | `--local` |

Use `--local` for per-project isolation. Auto-detects local if `./.jodney/state.json` exists.

## Environment

| Variable | Default | Purpose |
|----------|---------|---------|
| `ROD_CHROME_BIN` | auto | Chrome binary path |
| `ROD_TIMEOUT` | `30` | Element query timeout (seconds) |
| `JODNEY_HOME` | `~/.jodney` | Data directory |

## Gotchas

- **Always `jodney stop`** when done — otherwise a Chrome process lingers indefinitely.
- **`waitstable` is preferred** over `waitload` for SPAs and dynamic pages — `waitload` only fires on initial navigation, not on client-side renders.
- **`js` results are stringified** — arrays and objects come back as JSON strings. Pipe through `python3 -m json.tool` or use `--json` flags where available.
- **`js` takes a single string argument** — pass the whole expression as ONE quoted argument, including newlines: `jodney js '1 +\n2'` works. What fails is passing multiple separate args (`jodney js '1' '2'` → SyntaxError, only the first is wrapped). For complex logic, use an IIFE: `jodney js "(function(){ var els = document.querySelectorAll('.item'); return els[0].innerText; })()"`
- **Selectors are CSS only** — no XPath. Use `jodney js` for complex queries.
- **`start` while already running is NOT a no-op** — it launches a *second* Chrome process (new PID, new debug URL) and overwrites `state.json`, orphaning the old Chrome (which keeps running). Check first with `jodney status`, or `jodney stop` before re-`start`. In scripts, guard with `jodney status || jodney start`.
- **`open` auto-adds `http://`** — for `https://` URLs, include the scheme explicitly.
- **Exit codes**: 0 = success, 1 = assertion failed, 2 = error (bad args, timeout, no browser).
- **Heavy React apps** (booking sites, SPAs with autocomplete dropdowns) may timeout on `click`/`input`. Workaround: use the site's public API directly (most airlines, travel sites have one), or use `jodney js` to set values programmatically.

## References

- **`jodney --help`** — canonical command/flag/env list (source of truth; may be newer than the docs below).
- **[references/commands.md](references/commands.md)** — curated full command reference with all flags and options. Read when you need details on a specific command.
- **[references/examples.md](references/examples.md)** — Ready-to-use workflow scripts for scraping, form filling, smoke tests, and accessibility audits.
- **[references/debugging.md](references/debugging.md)** — Non-obvious debugging patterns: screenshot time-series, form validation checks, exit code chaining, and visible-mode debugging.
- **[references/dev-workflow.md](references/dev-workflow.md)** — Dev loop: reload-assess-iterate, page inspection without screenshots, DOM structure, accessibility tree, layout queries.
