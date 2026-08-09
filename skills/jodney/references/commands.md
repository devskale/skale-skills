# Jodney Command Reference

## Browser Lifecycle

| Command | Description |
|---------|-------------|
| `jodney start [--show] [--insecure\|-k]` | Launch Chrome (headless by default, `--show` for visible, `--insecure` ignores TLS errors) |
| `jodney connect <host:port>` | Connect to existing Chrome on remote debug port |
| `jodney stop` | Shut down Chrome |
| `jodney status` | Show browser status and active page |

## Navigation

| Command | Description |
|---------|-------------|
| `jodney open <url>` | Navigate to URL (auto-adds `http://`) |
| `jodney back` | Go back in history |
| `jodney forward` | Go forward in history |
| `jodney reload [--hard]` | Reload page (`--hard` bypasses cache) |
| `jodney clear-cache` | Clear browser cache |

## Page Info

| Command | Description |
|---------|-------------|
| `jodney url` | Print current URL |
| `jodney title` | Print page title |
| `jodney html [selector]` | Print HTML (full page or element) |
| `jodney text <selector>` | Print text content of element |
| `jodney attr <selector> <name>` | Print attribute value |
| `jodney pdf [file]` | Save page as PDF |

## JavaScript

| Command | Description |
|---------|-------------|
| `jodney js <expression>` | Evaluate JavaScript (wrapped in `() => { return (expr); }`) |

Examples:
```bash
jodney js document.title
jodney js '[1,2,3].map(x => x * 2)'
jodney js 'document.querySelectorAll("a").length'
```

## Interaction

| Command | Description |
|---------|-------------|
| `jodney click <selector>` | Click element |
| `jodney input <selector> <text>` | Type text into input field |
| `jodney clear <selector>` | Clear input field |
| `jodney file <selector> <path\|->` | Set file on file input (`-` for stdin) |
| `jodney download <sel> [file\|-]` | Download href/src target (`-` for stdout) |
| `jodney select <selector> <value>` | Select dropdown option by value |
| `jodney submit <selector>` | Submit form |
| `jodney hover <selector>` | Hover over element |
| `jodney focus <selector>` | Focus element |

## Cookies

| Command | Description |
|---------|-------------|
| `jodney cookie-set <name> <value> [opts]` | Set a cookie (defaults to current page) |
| `jodney cookie-get [name] [--json]` | Get cookie value by name, or all as JSON |
| `jodney cookie-delete <name> [opts]` | Delete cookies by name |
| `jodney cookie-clear [--domain <dom>]` | Clear all cookies (or one domain) |

`cookie-set` options: `--domain <dom>`, `--url <url>`, `--path <path>`, `--secure`, `--httponly`, `--samesite <Strict|Lax|None>`, `--expires <unix>`.
`cookie-delete` options: `--domain <dom>`, `--url <url>`, `--path <path>`.

## Emulation

| Command | Description |
|---------|-------------|
| `jodney ua <user-agent>` | Override browser user agent string |
| `jodney timezone <timezone-id>` | Override timezone (e.g. "Asia/Tokyo") |
| `jodney locale <locale>` | Override locale (e.g. "de-DE") |
| `jodney geo --lat N --lon N` | Spoof geolocation coordinates |
| `jodney media [--type T] [--feature name=value ...]` | Emulate media type/features |

## Video Recording

| Command | Description |
|---------|-------------|
| `jodney start-video` | Start recording video of the active page |
| `jodney stop-video [file]` | Stop and save (.gif default, .mp4 needs ffmpeg) |

## Waiting

| Command | Description |
|---------|-------------|
| `jodney wait <selector>` | Wait for element to appear and be visible |
| `jodney waitload` | Wait for page load event |
| `jodney waitstable` | Wait for DOM to stop changing |
| `jodney waitidle` | Wait for network to be idle |
| `jodney sleep <seconds>` | Sleep for N seconds |

## Screenshots

| Command | Description |
|---------|-------------|
| `jodney screenshot [-w N] [-h N] [file]` | Page screenshot (optional viewport size) |
| `jodney screenshot-el <selector> [file]` | Screenshot specific element |

## Tabs

| Command | Description |
|---------|-------------|
| `jodney pages` | List all tabs (* marks active) |
| `jodney page <index>` | Switch to tab by index |
| `jodney newpage [url]` | Open new tab |
| `jodney closepage [index]` | Close tab (active if no index) |

## Element Checks (exit 1 on failure)

| Command | Description |
|---------|-------------|
| `jodney exists <selector>` | Check if element exists (prints true/false) |
| `jodney count <selector>` | Count matching elements |
| `jodney visible <selector>` | Check if element visible (prints true/false) |
| `jodney assert <expr> [expected] [-m msg]` | Assert JS expression is truthy or equals expected |

Assert examples:
```bash
# Truthy check
jodney assert 'document.querySelector(".logged-in") !== null'

# Equality check
jodney assert 'document.title' 'Dashboard'

# With custom message
jodney assert 'document.title' 'Dashboard' -m "Wrong page loaded"
```

## Accessibility

| Command | Description |
|---------|-------------|
| `jodney ax-tree [--depth N] [--json]` | Dump accessibility tree |
| `jodney ax-find [--name N] [--role R] [--json]` | Find accessible nodes |
| `jodney ax-node <selector> [--json]` | Show element accessibility info |

Accessibility examples:
```bash
jodney ax-tree --depth 3 --json
jodney ax-find --role button
jodney ax-find --role link --name "Home" --json
jodney ax-node "#submit-btn" --json
```

## Global Flags

| Flag | Description |
|------|-------------|
| `--local` | Use directory-scoped session (`./.jodney/`) |
| `--global` | Use global session (`~/.jodney/`) |
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

jodney start
jodney open "https://example.com"
jodney waitstable

# Extract data
title=$(jodney title)
content=$(jodney text "article")

# Conditional checks
if jodney exists ".error"; then
    echo "Error found: $(jodney text '.error')"
fi

# Loop through pages
for i in 1 2 3; do
    jodney open "https://example.com/page/$i"
    jodney screenshot "page-$i.png"
done

jodney stop
```
