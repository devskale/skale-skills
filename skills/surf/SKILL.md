---
name: surf
description: "Drive the user's REAL, logged-in Google Chrome from the CLI on macOS for web scraping, form filling, screenshots, and tab-aware automation — with no daemon, no debug port, no extension, and no per-connection permission dialog. Uses macOS AppleScript + Chrome's 'Allow JavaScript from Apple Events'. Use when the user wants to automate, scrape, click, fill, read, or screenshot in the browser they are already logged into (cookies/logins/tabs intact). Triggers on: control my Chrome, drive my browser, automate my logged-in browser, scrape this page, fill this form, click this, read the page, take a browser screenshot, surf."
---

# Surf — Drive Your Real Chrome (macOS, AppleScript)

`surf` controls the browser you're already logged into — cookies, tabs, and sessions stay intact. It uses macOS AppleScript + Chrome's "Allow JavaScript from Apple Events". **No daemon, no port 9222, no extension, no CDP, no "Allow remote debugging?" dialog.** Rodney-style fire-and-forget CLI.

## ⚠️ Usage: CLI Only — NOT an MCP Tool

Surf is a **CLI tool**. Call each command as a **separate bash invocation**. It targets the **active tab of the front window** unless you `surf select` a tab.

```bash
surf tabs                       # list windows → tabs (refs like w1.t3)
surf here                       # what's on the active/target tab
surf open <url>                 # navigate
surf text "h1"                  # read text
surf click "a.signin"           # click
surf fill "input[name=q]" "x"   # fill a field
surf eval "<js>"                # run arbitrary JS
```

## Install

```bash
cd skills/surf && ./install.sh
surf setup        # one-time: enable Chrome JS-from-AppleScript (or do it manually)
```

**Requirements:** macOS + Google Chrome. (There is no Linux/Windows support — it's AppleScript-based.)

**One-time Chrome toggle** (only needed for `text`/`click`/`fill`/`eval`/`title` — navigation works without it):
> Chrome menu bar → **View → Developer ▸ → Allow JavaScript from Apple Events** (a ✓ appears).

`surf setup` will try to flip this for you via GUI scripting, but **Chromium menus don't respond to scripted clicks** — if it can't, click it manually once. After that it's permanent.

## Why surf (not rodney / chrome-devtools-mcp / mcp-chrome)?

| | surf | rodney | chrome-devtools-mcp | mcp-chrome |
|---|---|---|---|---|
| Your real, logged-in Chrome | ✅ | ❌ own browser | ✅ | ✅ |
| No per-connection dialog | ✅ | ✅ | ❌ ack every connect | ✅ |
| macOS-only | ✅ | cross-platform | cross-platform | cross-platform |
| Install weight | ~5 KB, zero deps | Go binary | npx | extension+bridge |
| Maintained | (yours) | ✅ | ✅ official | ❌ stale |

**Pick surf** when you want to drive the browser you're already in, on macOS, with zero setup weight and no ack. **Pick rodney** for CI / headless / cross-platform. **Pick chrome-devtools-mcp** for perf traces / Lighthouse / console debugging.

## Commands

### Navigation & tabs
```bash
surf tabs                       # list windows → tabs (wN.tN refs)
surf here                       # URL | title of target tab
surf select [wN.tN | reset]     # target a specific tab (operate background tabs w/o focus)
surf open <url>                 # navigate target tab
surf new [<url>]                # new tab (front window)
surf reload | back | fwd        # target-tab controls
surf close                      # close target/active tab
surf shot [<path>]              # screenshot the window → PNG
```

### Read
```bash
surf title                      # document.title
surf url                        # location.href
surf text  "<selector>"         # textContent of first match
surf html  "<selector>"         # outerHTML of first match
surf attr  "<selector>" <name>  # attribute value
surf count "<selector>"         # number of matches
surf eval  "<js>"               # run JS, print result
```

### Interact
```bash
surf click "<selector>"         # click first match (scrolls into view)
surf fill  "<selector>" "<val>" # set value + fire input/change
```

### Meta
```bash
surf setup                      # one-time Chrome JS toggle (GUI attempt + instructions)
surf --version | --selfcheck    # version / install info
surf help                       # full usage
```

Selectors are **CSS** (`document.querySelector` / `querySelectorAll`). `eval` JS runs in the page context and its return value is stringified.

## Gotchas

- **Targets the active tab of the front window by default.** Use `surf select w1.t3` to pin a tab (works on background tabs without stealing focus); `surf select reset` to clear.
- **JS commands need the one-time toggle** (View → Developer → Allow JavaScript from Apple Events). Pure navigation (`tabs`, `here`, `open`, `new`, `reload`) works without it.
- **`surf setup` can't reliably flip the Chromium menu** via GUI scripting — if it reports JS still off, click the menu item manually once.
- **Accessibility** (System Settings → Privacy & Security → Accessibility) must be granted to your terminal for `surf setup`'s GUI attempt; the manual click needs no special permission.
- **macOS-only.** AppleScript + Google Chrome. No Brave/Edge/Safari/Firefox, no Linux/Windows.
- **`shot` captures the window rectangle** via `screencapture -R`. For a background-tab target it first activates that tab.
- **Multi-window** tabs are listed as `wN.tN`; `select` pins window+tab indices, which shift if you reorder. Re-run `surf tabs` if a ref goes stale.
- **`eval` returns one stringified value.** For complex shapes return JSON: `surf eval 'JSON.stringify({...})'`.
- **Exit codes:** 0 = success, 1 = error (bad args, missing toggle, element not found returns a JSON string, not an error).

## References

- **[references/commands.md](references/commands.md)** — Full command reference with flags, selectors, and examples.
