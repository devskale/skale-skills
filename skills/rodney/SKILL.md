---
name: rodney
version: "1.0.0"
description: "Drive a persistent headless Chrome from the CLI for web scraping, screenshots, form filling, PDF export, and accessibility audits — one long-running Chrome process keeps cookies, localStorage, and navigation state across calls. Use when the user wants to automate browser interactions, scrape JS-rendered pages, take screenshots, fill forms, export PDFs, or run browser smoke tests in CI. Triggers on: headless Chrome, browser automation, web scraping, page screenshot, form automation, accessibility audit, browser smoke test, rodney."
---

# Rodney — Chrome Automation

Rodney drives a persistent headless Chrome instance from the terminal. All commands share one long-running Chrome process — cookies, localStorage, and navigation state persist across invocations.

## ⚠️ Usage: CLI Only — NOT an MCP Tool

Rodney is a **CLI tool**, not an MCP server. Use it via the **bash** tool only. Never call `mcp("rodney")`.

Every rodney session follows this pattern via bash:

```bash
rodney start                              # 1. Launch Chrome
rodney open <url>                         # 2. Navigate
rodney waitstable                         # 3. Wait for page to settle
# ... interact, scrape, screenshot ...     # 4. Do your work
rodney stop                               # 5. ALWAYS stop when done
```

**Important:**
- Call each command as a separate bash invocation (e.g. `rodney start`, then `rodney open <url>`, etc.)
- **Always `rodney stop`** when finished — otherwise Chrome runs forever
- Combine start → open → waitstable → work → stop in every workflow
- Other lifecycle commands: `rodney connect <host:port>` (attach to an already-running Chrome on a debug port), `rodney status` (browser info + active page)

> **`rodney --help` is the source of truth — use it to self-discover.** Rodney is an
> external dep whose feature set evolves. The command list below is only a **curated
> snapshot** and may be stale. **Always run `rodney --help` first** to see the actual
> installed commands, flags, and env vars, and drive your session from that output rather
> than trusting these docs. If a command errors or you suspect a newer flag exists,
> re-check `rodney --help`.

## Use the Latest Rodney

Rodney ships as a source-built Go binary (not on PyPI). **Before relying on it, make sure
you're on the latest version** — new commands and flags land upstream all the time and
`--help` only reflects what's installed. The working branch is `skale`; install from there.

```bash
rodney --version          # what's installed now
```

To refresh from source (no built-in `--update` on the `skale` branch):

```bash
cd ~/src/rodney 2>/dev/null || git clone -b skale git@github.com:devskale/rodney.git ~/src/rodney
cd ~/src/rodney && git pull --ff-only && go build -o ~/.local/bin/rodney .
rodney --version          # confirm the refresh
```

Then run `rodney --help` to discover the current command set.

## Install

rodney is not published to PyPI — build the Go binary from source (from the `skale` branch):

```bash
# Requires Go 1.21+ and Chrome or Chromium installed
# (set ROD_CHROME_BIN if Chrome isn't at the default location)
git clone -b skale git@github.com:devskale/rodney.git
cd rodney
go build -o ~/.local/bin/rodney .   # put it on your PATH
```

Or, if you already have the repo checked out:

```bash
go build -o rodney .
sudo mv rodney /usr/local/bin/   # or cp to a dir on your PATH
```

Verify with `rodney --version` (expect a recent release, e.g. `0.6.0` or newer — don't
rely on a hardcoded version).

## Project Setup

To add rodney to a project, add this to the project's AGENTS.md:

```markdown
## Browser Automation

Use rodney for headless Chrome automation (scraping, screenshots, forms, PDFs, a11y, smoke tests).

### Setup
1. Install: `go build -o ~/.local/bin/rodney .` (from a clone of devskale/rodney)
2. Verify: `rodney start && rodney stop`
3. Link skill: `ln -s /path/to/skale-skills/skills/rodney .pi/skills/rodney`

### Usage
```bash
rodney start
rodney open https://example.com
rodney waitstable
rodney screenshot page.png
rodney stop
```
```

## Quick Start

```bash
rodney start                          # Launch headless Chrome
rodney start --show                   # Launch visible Chrome (for debugging)
rodney open https://example.com       # Navigate
rodney text "h1"                      # Extract text
rodney screenshot page.png            # Screenshot
rodney stop                           # Shut down
```

## When to Use: `surf` vs `rodney` vs `chrome-devtools-mcp`

These three overlap; pick by whether you need the user's **real session** or a **clean
isolated browser**:

- **Real session on macOS, zero setup** → **`surf`** (AppleScript into their visible Chrome).
- **Real session on any OS, or deep debug (console/network/perf)** → **`chrome-devtools-mcp`**.
- **Fresh isolated headless browser for scraping/forms/PDFs/a11y/CI** → **`rodney`** (this skill).

They compose — use `surf`/`chrome-devtools-mcp` on the user's real session, `rodney` for
isolated/headless jobs and CI. For the full agent-readable decision tree and feature
matrix, see **[docs/browser-use/which-browser-tool.md](../../docs/browser-use/which-browser-tool.md)**
(single source of truth).

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

### Cookies

```bash
rodney cookie-set <name> <value> [opts]   # Set a cookie (defaults to current page)
rodney cookie-get [name] [--json]         # Get cookie value by name, or all as JSON
rodney cookie-delete <name> [opts]        # Delete cookies by name
rodney cookie-clear [--domain <dom>]      # Clear all cookies (or one domain)
```

`cookie-set` options: `--domain <dom>`, `--url <url>`, `--path <path>`, `--secure`, `--httponly`, `--samesite <Strict|Lax|None>`, `--expires <unix>`.
`cookie-delete` options: `--domain <dom>`, `--url <url>`, `--path <path>`.

### Emulation

```bash
rodney ua <user-agent>              # Override browser user agent string
rodney timezone <timezone-id>       # Override timezone (e.g. "Asia/Tokyo")
rodney locale <locale>              # Override locale (e.g. "de-DE")
rodney geo --lat N --lon N          # Spoof geolocation coordinates
rodney media [--type T] [--feature name=value ...]  # Emulate media type/features
```

`media` examples: `rodney media --type print` (print media), `rodney media --feature prefers-color-scheme=dark`.

### Network Interception

```bash
rodney mock <pattern> <response> [--status N] [--type MIME] [--method M]  # Serve canned response for matching requests
rodney block <pattern> [--method M]                                        # Fail matching requests client-side
```

Both run as **persistent foreground commands** (until Ctrl+C) — other rodney commands in
separate shells drive the browser while the interception is active. `mock` serves a body
(or `-file=<path>`), `block` fails with `BlockedByClient`. See
[references/commands.md](references/commands.md) → *Network Interception* for the full
flag tables and examples.

### Video Recording

```bash
rodney start-video              # Start recording video of the active page
rodney stop-video [file]        # Stop and save (.gif default, .mp4 needs ffmpeg)
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

### Network interception (mock / block)

Intercept the browser's network to **mock** API responses or **block** requests — for
error-state testing, offline simulation, and deterministic scraping. These run as
**persistent foreground processes** (own shell, stop with Ctrl+C).

```bash
rodney mock "*api.example.com/users*" '{"id":1}' --type application/json   # canned response
rodney block "*.jpg" "*.gif"                                                # fail requests
```

**Full guide with patterns, flags, and use cases:**
**[references/network-interception.md](references/network-interception.md)**.

## Sessions

| Type | State | Flag |
|------|-------|------|
| Global | `~/.rodney/` | default |
| Local | `./.rodney/` | `--local` |

Use `--local` for per-project isolation. Auto-detects local if `./.rodney/state.json` exists.

## Environment

| Variable | Default | Purpose |
|----------|---------|---------|
| `ROD_CHROME_BIN` | auto | Chrome binary path (go-rod standard) |
| `ROD_TIMEOUT` | `30` | Element query timeout (seconds, go-rod standard) |
| `RODNEY_HOME` | `~/.rodney` | Data directory |

## Gotchas

- **Always `rodney stop`** when done — otherwise a Chrome process lingers indefinitely.
- **`waitstable` is preferred** over `waitload` for SPAs and dynamic pages — `waitload` only fires on initial navigation, not on client-side renders.
- **`js` results are stringified** — arrays and objects come back as JSON strings. Pipe through `python3 -m json.tool` or use `--json` flags where available.
- **`js` takes a single string argument** — pass the whole expression as ONE quoted argument, including newlines: `rodney js '1 +\n2'` works. What fails is passing multiple separate args (`rodney js '1' '2'` → SyntaxError, only the first is wrapped). For complex logic, use an IIFE: `rodney js "(function(){ var els = document.querySelectorAll('.item'); return els[0].innerText; })()"`
- **Selectors are CSS only** — no XPath. Use `rodney js` for complex queries.
- **`start` while already running is NOT a no-op** — it launches a *second* Chrome process (new PID, new debug URL) and overwrites `state.json`, orphaning the old Chrome (which keeps running). Check first with `rodney status`, or `rodney stop` before re-`start`. In scripts, guard with `rodney status || rodney start`.
- **`open` auto-adds `http://`** — for `https://` URLs, include the scheme explicitly.
- **Exit codes**: 0 = success, 1 = assertion failed, 2 = error (bad args, timeout, no browser).
- **Heavy React apps** (booking sites, SPAs with autocomplete dropdowns) may timeout on `click`/`input`. Workaround: use the site's public API directly (most airlines, travel sites have one), or use `rodney js` to set values programmatically.

## References

- **`rodney --help`** — **canonical and primary** command/flag/env list. Run it first to self-discover the installed feature set; it may be newer than the docs below.
- **[references/commands.md](references/commands.md)** — curated full command reference with all flags and options. Read when you need details on a specific command.
- **[references/examples.md](references/examples.md)** — Ready-to-use workflow scripts for scraping, form filling, smoke tests, and accessibility audits.
- **[references/debugging.md](references/debugging.md)** — Non-obvious debugging patterns: screenshot time-series, form validation checks, exit code chaining, and visible-mode debugging.
- **[references/network-interception.md](references/network-interception.md)** — Network mocking and blocking (`mock`/`block`): patterns, flags, and use cases for error-state/offline/deterministic testing.
- **[references/dev-workflow.md](references/dev-workflow.md)** — Dev loop: reload-assess-iterate, page inspection without screenshots, DOM structure, accessibility tree, layout queries.
