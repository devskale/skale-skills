# Rodney Command Reference

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
| `rodney input <selector> <text>` | Type text into input field |
| `rodney clear <selector>` | Clear input field |
| `rodney file <selector> <path\|->` | Set file on file input (`-` for stdin) |
| `rodney download <sel> [file\|-]` | Download href/src target (`-` for stdout) |
| `rodney select <selector> <value>` | Select dropdown option by value |
| `rodney submit <selector>` | Submit form |
| `rodney hover <selector>` | Hover over element |
| `rodney focus <selector>` | Focus element |

## Waiting

| Command | Description |
|---------|-------------|
| `rodney wait <selector>` | Wait for element to appear and be visible |
| `rodney waitload` | Wait for page load event |
| `rodney waitstable` | Wait for DOM to stop changing |
| `rodney waitidle` | Wait for network to be idle |
| `rodney sleep <seconds>` | Sleep for N seconds |

## Screenshots

| Command | Description |
|---------|-------------|
| `rodney screenshot [-w N] [-h N] [file]` | Page screenshot (optional viewport size) |
| `rodney screenshot-el <selector> [file]` | Screenshot specific element |

## Tabs

| Command | Description |
|---------|-------------|
| `rodney pages` | List all tabs (* marks active) |
| `rodney page <index>` | Switch to tab by index |
| `rodney newpage [url]` | Open new tab |
| `rodney closepage [index]` | Close tab (active if no index) |

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
