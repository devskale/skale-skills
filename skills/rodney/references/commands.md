# Rodney Command Reference

> **Self-discover the real command set with `rodney --help` + `rodney help <command>`.** This
> reference is a curated
> snapshot and may lag the installed binary — features evolve upstream. Always treat
> `rodney --help` as the source of truth before relying on a command or flag listed here.

## Browser Lifecycle

| Command | Description |
|---------|-------------|
| `rodney start [--show] [--insecure\|-k]` | Launch Chrome (headless by default, `--show` for visible, `--insecure` ignores TLS errors) |
| `rodney connect <host:port>` | Connect to existing Chrome on remote debug port |
| `rodney stop` | Shut down Chrome |
| `rodney status` | Show browser status and active page |

## Navigation

| Command | Description |
|---------|-------------|
| `rodney open <url>` | Navigate to URL (auto-adds `http://`) |
| `rodney back` | Go back in history |
| `rodney forward` | Go forward in history |
| `rodney reload [--hard]` | Reload page (`--hard` bypasses cache) |
| `rodney clear-cache` | Clear browser cache |

## Page Info

| Command | Description |
|---------|-------------|
| `rodney url` | Print current URL |
| `rodney title` | Print page title |
| `rodney html [selector]` | Print HTML (full page or element) |
| `rodney text <selector>` | Print text content of element |
| `rodney attr <selector> <name>` | Print attribute value |
| `rodney xpath-of <selector>` | Print the computed XPath of an element — helps building XPath queries |
| `rodney pdf [file]` | Save page as PDF |

## JavaScript

| Command | Description |
|---------|-------------|
| `rodney js <expression>` | Evaluate JavaScript (wrapped in `() => { return (expr); }`) |

Examples:
```bash
rodney js document.title
rodney js '[1,2,3].map(x => x * 2)'
rodney js 'document.querySelectorAll("a").length'
```

## Interaction

| Command | Description |
|---------|-------------|
| `rodney click <selector>` | Click element |
| `rodney input <selector> <text>` | Type text into input field (sets `.value` directly) |
| `rodney type <text>` | Type text as **real keyboard input** into the focused element — fires key/input events, so SPA validation, autocomplete, and search-as-you-type react to it (unlike `input`) |
| `rodney press <key> [key ...]` | Press keys as **real keydown/keyup events** — combos like `ctrl+a`, `shift+tab`; friendly names (`enter`, `tab`, `escape`, arrows, `f1`–`f12`) or single characters |
| `rodney scroll <x> <y> [--steps N]` | Scroll page by pixels (negative y = up); `--steps N` for smooth scrolling (lazy-loading feeds) |
| `rodney scroll-el <selector>` | Scroll an element into view |
| `rodney clear <selector>` | Clear input field |
| `rodney file <selector> <path\|->` | Set file on file input (`-` for stdin) |
| `rodney download <sel> [file\|-]` | Download href/src target (`-` for stdout) |
| `rodney select <selector> <value>` | Select dropdown option by value |
| `rodney submit <selector>` | Submit form |
| `rodney hover <selector>` | Hover over element |
| `rodney focus <selector>` | Focus element |

## Cookies

| Command | Description |
|---------|-------------|
| `rodney cookie-set <name> <value> [opts]` | Set a cookie (defaults to current page) |
| `rodney cookie-get [name] [--json]` | Get cookie value by name, or all as JSON |
| `rodney cookie-delete <name> [opts]` | Delete cookies by name |
| `rodney cookie-clear [--domain <dom>]` | Clear all cookies (or one domain) |

`cookie-set` options: `--domain <dom>`, `--url <url>`, `--path <path>`, `--secure`, `--httponly`, `--samesite <Strict|Lax|None>`, `--expires <unix>`.
`cookie-delete` options: `--domain <dom>`, `--url <url>`, `--path <path>`.

## Emulation

| Command | Description |
|---------|-------------|
| `rodney ua <user-agent>` | Override browser user agent string |
| `rodney timezone <timezone-id>` | Override timezone (e.g. "Asia/Tokyo") — **known bug [#2](https://github.com/devskale/rodney/issues/2): override doesn't reach the page** |
| `rodney locale <locale>` | Override locale (e.g. "de-DE") |
| `rodney geo --lat N --lon N` | Spoof geolocation coordinates |
| `rodney media [--type T] [--feature name=value ...]` | Emulate media type/features |
| `rodney device <name>` | Emulate a device: viewport, pixel ratio, touch, and user agent in one step |
| `rodney viewport <WxH>` | Set page viewport size (affects layout, screenshots, innerWidth); persists until cleared/browser stop |

## Session Persistence

| Command | Description |
|---------|-------------|
| `rodney headers [<k:v> ...]` | Extra HTTP headers on every request of the session (auth tokens, API versioning); no args: list. Persists in session state |
| `rodney onload [<js>]` | Register JS that runs on EVERY navigation of the session (hide cookie banners, inject hooks, stub globals); no args: list. Persists |

## History & Resources

| Command | Description |
|---------|-------------|
| `rodney history` | Print the active page's navigation history (* marks current) |
| `rodney resource <url-substr>` | Print the cached body of an already-loaded resource (script, XHR, image) — no new request |
| `rodney stopload` | Stop pending navigation + fetches — proceed with a half-loaded page (scraping speed) |

## Foreground Helpers

Persistent foreground processes (Ctrl+C stops), like `mock`/`block`/`dialog`:

| Command | Description |
|---------|-------------|
| `rodney filechooser <path>` | Intercept file choosers: every chooser the page opens gets the given file |
| `rodney monitor` | Serve rod's live monitor web UI (pages, eval console, request log) |

## Advanced Interaction

| Command | Description |
|---------|-------------|
| `rodney drag <from-sel> <to-sel>` | Drag via real mouse events (down/move/up) — sliders, sortables, kanban |
| `rodney tap <selector>` | Tap with touch semantics (pairs with `device` emulation) |

## Debugging

| Command | Description |
|---------|-------------|
| `rodney doctor` | Self-diagnostics: version, Chrome detection, ffmpeg, session state, connectivity. Exit 2 if any check fails |

## Network Interception

Intercept requests matching a URL pattern — serve a canned response (`mock`) or fail
them client-side (`block`). Both run as **persistent foreground commands**: the
interception router stays alive until Ctrl+C / SIGTERM, so other rodney commands in
separate shells can drive the browser while it's active.

### mock — serve a canned response

`rodney mock <pattern> <response> [--status N] [--type MIME] [--method M]`

| Flag | Default | Description |
|------|---------|-------------|
| `<pattern>` | — | Glob-style URL pattern (e.g. `*api.example.com/users*`) |
| `<response>` | — | Body text to serve, or `-file=<path>` to serve a file's contents |
| `--status N` | `200` | HTTP status code to return |
| `--type MIME` | `text/plain` | Content-Type header |
| `--method M` | (all) | Only mock requests with this HTTP method |

Examples:
```bash
# Stub an API endpoint with a fixed JSON body
rodney mock "*api.example.com/users*" '{"users":[]}' --type application/json

# Return a 404 for a specific path
rodney mock "*example.com/missing*" "Not found" --status 404

# Serve a response body from a file, only for POST requests
rodney mock "*api.example.com/submit*" -file=./fixtures/submit.json --method POST --type application/json
```

### block — fail matching requests client-side

`rodney block <pattern> [--method M]`

| Flag | Default | Description |
|------|---------|-------------|
| `<pattern>` | — | Glob-style URL pattern |
| `--method M` | (all) | Only block requests with this HTTP method |

Failures use `BlockedByClient` — the browser never reaches the real server.

Examples:
```bash
# Block all analytics/telemetry calls
rodney block "*google-analytics.com*"

# Block only POST requests to a specific endpoint
rodney block "*api.example.com/expensive*" --method POST
```

## Video Recording

| Command | Description |
|---------|-------------|
| `rodney start-video` | Start recording video of the active page |
| `rodney stop-video [file]` | Stop and save (.gif default, .mp4 needs ffmpeg) |

## Waiting

| Command | Description |
|---------|-------------|
| `rodney wait <selector>` | Wait for element to appear and be visible |
| `rodney waitnav` | Wait until the page navigates to a different URL (redirects, submits, SPA route changes) |
| `rodney waitpage` | Wait until a NEW page/tab opens (window.open, target=_blank, OAuth popups) and switch active page to it |
| `rodney waitload` | Wait for page load event |
| `rodney waitstable` | Wait for DOM to stop changing |
| `rodney waitidle` | Wait for network to be idle |
| `rodney sleep <seconds>` | Sleep for N seconds |

## Screenshots

| Command | Description |
|---------|-------------|
| `rodney screenshot [-w N] [-h N] [--full] [file]` | Page screenshot (optional viewport size; `--full` forces full-page capture) |
| `rodney screenshot-el <selector> [file]` | Screenshot specific element |

## Tabs

| Command | Description |
|---------|-------------|
| `rodney pages [--json]` | List all tabs (* marks active, `t:<id>` = stable target ID); `--json` → machine-readable rows (index, targetId, title, url, active) |
| `rodney page <index\|t:id>` | Switch tab — `t:<id>` is drift-proof when parallel sessions shift the indices |
| `rodney newpage [url]` | Open new tab |
| `rodney closepage [index\|t:id]` | Close tab (active if no arg; `t:<id>` closes by stable ID) |

## Console Logs

| Command | Description |
|---------|-------------|
| `rodney console [--level L] [--json] [--browser] [--follow] [--clear]` | Read console output. No collector running: live stream (Ctrl+C stops). Collector running: print buffered messages. `--level` log\|info\|warn\|error\|debug · `--json` JSON lines · `--browser` also browser log entries · `--follow` tail mode · `--clear` print and empty buffer |
| `rodney console-start` | Start background console collector (captures logs between commands into `console.jsonl`) |
| `rodney console-stop` | Stop collector and remove the buffer |

## Network Requests

| Command | Description |
|---------|-------------|
| `rodney requests [--json] [--follow] [--clear]` | Read network requests. No collector: live view (Ctrl+C stops). Collector: print buffered requests. `--json` JSON lines · `--follow` tail mode · `--clear` print and empty buffer |
| `rodney requests-start` | Start background request collector (captures into `requests.jsonl`) |
| `rodney requests-stop` | Stop collector and remove the buffer |

## Dialogs

| Command | Description |
|---------|-------------|
| `rodney dialog [--dismiss] [--text MSG] [--json]` | Handle JS dialogs (alert/confirm/prompt/beforeunload) as a persistent foreground process — arms BEFORE the dialog opens (an already-open dialog is unreachable; start this first, then trigger). Default accepts; `--dismiss` cancels; `--text MSG` answers prompts; `--json` JSON lines |

## Element Checks (exit 1 on failure)

| Command | Description |
|---------|-------------|
| `rodney exists <selector>` | Check if element exists (prints true/false) |
| `rodney count <selector>` | Count matching elements |
| `rodney visible <selector>` | Check if element visible (prints true/false) |
| `rodney assert <expr> [expected] [-m msg]` | Assert JS expression is truthy or equals expected |

Assert examples:
```bash
# Truthy check
rodney assert 'document.querySelector(".logged-in") !== null'

# Equality check
rodney assert 'document.title' 'Dashboard'

# With custom message
rodney assert 'document.title' 'Dashboard' -m "Wrong page loaded"
```

## Accessibility

| Command | Description |
|---------|-------------|
| `rodney ax-tree [--depth N] [--json]` | Dump accessibility tree |
| `rodney ax-find [--name N] [--role R] [--json]` | Find accessible nodes |
| `rodney ax-node <selector> [--json]` | Show element accessibility info |

Accessibility examples:
```bash
rodney ax-tree --depth 3 --json
rodney ax-find --role button
rodney ax-find --role link --name "Home" --json
rodney ax-node "#submit-btn" --json
```

## Global Flags

| Flag | Description |
|------|-------------|
| `--local` | Use directory-scoped session (`./.rodney/`) |
| `--global` | Use global session (`~/.rodney/`) |
| `--version` | Print version |
| `--help`, `-h`, `help` | Show help |

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Check failed (exists, visible, assert returned false) |
| 2 | Error (bad arguments, no browser, timeout, etc.) |

## Selector Syntax

Uses standard CSS selectors:
- `#id` - Element by ID
- `.class` - Elements by class
- `tag` - Elements by tag
- `[attr=value]` - By attribute
- `parent > child` - Direct child
- `ancestor descendant` - Any descendant

## Scripting Pattern

```bash
#!/bin/bash
set -euo pipefail

rodney start
rodney open "https://example.com"
rodney waitstable

# Extract data
title=$(rodney title)
content=$(rodney text "article")

# Conditional checks
if rodney exists ".error"; then
    echo "Error found: $(rodney text '.error')"
fi

# Loop through pages
for i in 1 2 3; do
    rodney open "https://example.com/page/$i"
    rodney screenshot "page-$i.png"
done

rodney stop
```
