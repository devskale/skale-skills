# Surf — Command Reference

Full reference for `surf`, the macOS AppleScript CLI for your real Google Chrome.

## Global

| Flag | Effect |
|---|---|
| `--version` | print version |
| `--selfcheck` | version + skill dir + last update |
| `--update` | `git pull` the skill repo + refresh stamp |
| `help` / `-h` / `--help` | usage |

## Targets

By default every command targets the **active tab of the front window**. Pin a tab to operate it (even in the background, without focus):

```bash
surf select w1.t3      # target window 1, tab 3
surf select            # show current target
surf select reset      # back to active tab of front window
```

The target is stored in `~/.config/surf/target` (override with `SURF_TARGET_FILE`). List refs anytime with `surf tabs`.

## Navigation & tabs

| Command | Notes |
|---|---|
| `surf tabs` | list every window → tab as `wN.tN  URL  \|  title` |
| `surf here` | `URL \| title` of the target tab |
| `surf open <url>` | navigate the target tab |
| `surf new [<url>]` | open a new tab in the front window (default `about:blank`) |
| `surf reload` | reload target tab |
| `surf back` / `surf fwd` | history via JS (`history.back()` / `forward()`) |
| `surf close` | close the target (or active) tab; clears a pinned target |

## Read

All reads run in the target tab's page context.

| Command | Returns |
|---|---|
| `surf title` | `document.title` |
| `surf url` | `location.href` |
| `surf text "<sel>"` | trimmed `textContent` of first match (max 10000 chars); `NOT_FOUND` if none |
| `surf html "<sel>"` | `outerHTML` of first match; `NOT_FOUND` if none |
| `surf attr "<sel>" <name>` | `getAttribute(name)`; `NOT_FOUND` if no element |
| `surf count "<sel>"` | `String(document.querySelectorAll(sel).length)` |
| `surf eval "<js>"` | result of running `<js>` (stringified) |

Selectors are CSS, passed to `document.querySelector` / `querySelectorAll`.

## Interact

| Command | Returns |
|---|---|
| `surf click "<sel>"` | scrolls into view, clicks first match → `{"ok":true,"tag":"..."}` or `{"ok":false,"err":"not_found"}` |
| `surf fill "<sel>" "<val>"` | focuses, sets `.value`, fires `input` + `change` → `{"ok":true,...}` / `{"ok":false,"err":"not_found"}` |

`fill` is React/Vue-friendly because it dispatches `input` and `change` events.

## Screenshot

```bash
surf shot              # → ./surf-shot.png
surf shot ~/Desktop/x.png
```

Brings the target window to the front (and activates the target tab if pinned), reads its `bounds`, and runs `screencapture -R x,y,w,h -o -x <path>`. Shadow omitted.

## Setup

```bash
surf setup
```

Attempts to GUI-click **View → Developer → Allow JavaScript from Apple Events**, then verifies with a real JS call. Chromium menus don't respond to scripted clicks, so if it can't, follow the printed manual instruction. Needs Accessibility for your terminal for the GUI attempt; the manual click needs none.

## Environment

| Variable | Default | Purpose |
|---|---|---|
| `SURF_APP` | `Google Chrome` | Chrome app name (e.g. `Chromium`) |
| `SURF_TARGET_FILE` | `~/.config/surf/target` | where the pinned tab is stored |

## Recipes

```bash
# Scrape the H1 of the page you're reading
surf text "h1"

# Count links, then click the first "Sign in"
surf count "a"
surf click "a[href*='login']"

# Fill + submit a search
surf fill "input[name=q]" "skyvern"
surf click "button[type=submit]"

# Pull structured data
surf eval 'JSON.stringify({title:document.title, h1:document.querySelector("h1")?.innerText, links:document.querySelectorAll("a").length})'

# Drive a background tab without leaving the one you're on
surf tabs
surf select w1.t5
surf text "h1"
surf select reset

# Screenshot
surf shot ~/Desktop/before.png
```

## How it works

`surf` is pure bash + `osascript`. JS is written to a temp file and read by AppleScript (`read POSIX file … as «class utf8»`) to avoid quoting hell, then `execute … javascript` runs it in the target tab. No browser process is launched; it talks to the Chrome you already have open.
