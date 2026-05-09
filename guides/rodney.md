# Rodney — Chrome Automation from the CLI

Rodney drives a persistent headless Chrome instance from your terminal. Chain commands for multi-step browser workflows: navigate, scrape, fill forms, take screenshots, run JS, export PDFs, and test accessibility — all from bash.

## Install

```bash
uv tool install rodney
```

Requires **Chrome** or Chromium installed.

## Quick Start

```bash
rodney start                          # Launch headless Chrome (persists across commands)
rodney open https://example.com       # Navigate
rodney text "h1"                      # Extract text from element
rodney screenshot page.png            # Take a screenshot
rodney stop                           # Shut down Chrome
```

## Core Commands

### Navigation & Waiting

```bash
rodney open https://example.com       # Go to URL
rodney waitstable                     # Wait until DOM stops changing
rodney waitload                       # Wait for page load event
rodney waitidle                       # Wait for network idle
rodney wait "h1"                      # Wait for selector to appear
rodney sleep 2                        # Fixed delay (seconds)
```

### Content Extraction

```bash
rodney title                          # Page title
rodney text "h1"                      # Text content of first match
rodney text "a"                       # All matching elements (one per line)
rodney js 'document.title'            # Run arbitrary JS, get result back
```

Extract structured data with JS:

```bash
rodney js 'Array.from(document.querySelectorAll("a")).map(a => ({text: a.textContent, href: a.href}))'
```

### Screenshots & PDFs

```bash
rodney screenshot page.png            # Viewport screenshot
rodney screenshot -w 1920 -h 1080 full.png   # Custom dimensions
rodney screenshot-el ".chart" chart.png      # Single element
rodney pdf output.pdf                # Export page as PDF
```

### Form Interaction

```bash
rodney input "#email" "user@example.com"
rodney input "#password" "secret123"
rodney click "button[type='submit']"
```

### Accessibility Testing

```bash
rodney ax-tree --depth 3             # Dump accessibility tree
rodney ax-find --role button         # Find all buttons
rodney ax-find --role button --json  # JSON output for scripted checks
```

### Assertions (CI/CD)

Exit code `0` = pass, `1` = fail:

```bash
rodney exists "h1"                   # Element exists?
rodney visible "#main-content"       # Element visible?
rodney assert 'document.title' 'My App'    # Value matches?
```

Use in scripts with `set -euo pipefail`.

## Session Types

| Type | State Location | Flag |
|------|---------------|------|
| Global | `~/.rodney/` | default |
| Local | `./.rodney/` | `--local` |

Local sessions isolate state per project:

```bash
rodney start --local
```

Auto-detects local if `./.rodney/state.json` exists.

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `RODNEY_HOME` | `~/.rodney` | Data directory |
| `ROD_CHROME_BIN` | auto-detected | Path to Chrome binary |
| `ROD_TIMEOUT` | `30` | Element query timeout (seconds) |

Set Chrome path if not at default:

```bash
export ROD_CHROME_BIN="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
```

## Example Workflows

### Web Scraping

```bash
#!/usr/bin/env bash
set -euo pipefail

rodney start
rodney open https://news.ycombinator.com
rodney waitstable

titles=$(rodney js 'Array.from(document.querySelectorAll(".titleline > a")).map(a => a.textContent.trim()).join("\n")')
echo "$titles" | head -10

rodney stop
```

### Form Fill + Screenshot

```bash
#!/usr/bin/env bash
set -euo pipefail

rodney start
rodney open https://httpbin.org/forms/post

rodney input "input[name='custname']" "Johann Waldherr"
rodney input "input[name='custtel']" "+1-555-0123"
rodney input "input[name='custemail']" "johann@example.com"

rodney screenshot form-filled.png
rodney pdf form.pdf

rodney stop
```

### Smoke Test

```bash
#!/usr/bin/env bash
set -euo pipefail

rodney start
rodney open "https://myapp.com"
rodney waitstable

rodney exists "h1"
rodney visible "#main-content"
rodney assert 'document.title' 'My App'

rodney stop
echo "✅ All checks passed"
```

## Tips

- **Always `stop`** when done — leaves a Chrome process running otherwise.
- **One session** = one Chrome process. All commands share cookies, localStorage, navigation state.
- **`--headless`** is the default. For visible Chrome, check docs for headful mode options.
- **Timeouts** are configurable via `ROD_TIMEOUT` for slow pages.
- Works great in CI pipelines alongside existing shell scripts — no Node.js needed.
