# Surf — Command Reference

Complete reference for `surf`, the macOS AppleScript CLI for your real Google Chrome. v1.3.1.

`surf` targets the **active tab of the front window** unless you `surf select` a tab. Selectors are CSS (`document.querySelector` / `querySelectorAll`). `--json` is supported on `tabs`, `here`, `text`, `count`.

## Global

| Flag | Effect |
|---|---|
| `--version` | print version |
| `--selfcheck` | version + skill dir + last update |
| `--update` | `git pull` the skill repo + refresh stamp |
| `help` / `-h` / `--help` | usage |

## Targets

| Command | Notes |
|---|---|
| `surf select [wN.tN\|reset]` | pin a tab to operate it (even in the background, without focus); blank shows the current target |
| `surf select reset` | back to active tab of front window |

The target is stored in `~/.config/surf/target` as `W T URL` (override with `SURF_TARGET_FILE`). The stored URL makes `select` **drift-resilient**: if window/tab indices shift (reorder/close), the next op verifies the URL and re-pins to the tab's new index (note on stderr); if the pinned tab navigated in place it follows the new URL silently; if the tab is gone it falls back to the active tab. List refs with `surf tabs`.

## Navigation & tabs

| Command | Notes |
|---|---|
| `surf tabs` | every window → tab as `wN.tN  URL  \|  title`. `--json` → `[{window,tab,url,title}]` |
| `surf here` | `URL \| title` of the target tab. `--json` → `{window,tab,url,title}` |
| `surf open <url>` | navigate the target tab |
| `surf new [<url>]` | new tab in a normal (non-incognito, JS-capable) window (default `about:blank`) |
| `surf reload` | reload target tab |
| `surf back` / `surf fwd` | `history.back()` / `history.forward()` |
| `surf close` | close the target (or active) tab; clears a pinned target |

## Waiting (async-ready)

All accept `--timeout N` (seconds; default `SURF_WAIT_TIMEOUT=15`). Poll interval `SURF_WAIT_INTERVAL` (0.3–0.4s).

| Command | Returns |
|---|---|
| `surf wait "<sel>" [--timeout N]` | `found: <sel>` (exit 0) when element exists; `surf: wait timeout (Ns): <sel>` (exit 1) |
| `surf wait-url "<sub>" [--timeout N]` | `ok: <url>` (exit 0) when `location.href` contains substring; timeout exit 1 |
| `surf wait-stable [--timeout N]` | `stable: <N>ms` (exit 0) when no DOM mutation for `SURF_STABLE_QUIET_MS` (default 700) — via a `MutationObserver` quiet-window; timeout exit 1 |

## Read

| Command | Returns |
|---|---|
| `surf title` | `document.title` |
| `surf url` | `location.href` |
| `surf text "<sel>"` | trimmed `textContent` of first match (max 10000 chars); `NOT_FOUND` if none. `--json` → `{selector,found,text}` |
| `surf html "<sel>"` | `outerHTML` of first match; `NOT_FOUND` if none |
| `surf attr "<sel>" <name>` | `getAttribute(name)`; `NOT_FOUND` if no element |
| `surf count "<sel>"` | `String(querySelectorAll(sel).length)`. `--json` → `{selector,count}` |
| `surf list "<sel>"` | `JSON` array of all matches' text (cap 1000 items, 500 chars each); `[]` if none |
| `surf eval "<js>"` | result of running `<js>` in the page (stringified) |

## Batch — many ops, one browser call

Run a JSON array of steps in **one** `execute javascript` call; get back a JSON array of `{"op":..,"v":..}`. Cuts per-command `osascript` launch overhead for agent loops. Steps run sequentially in the target tab; each is `try/catch`-wrapped so one bad selector returns `{err}` instead of aborting the batch. `v` is exactly what the standalone op would print.

```bash
surf batch <<'EOF'
[{"op":"title"},{"op":"count","sel":"a"},{"op":"text","sel":"h1"},{"op":"attr","sel":"a","name":"href"},{"op":"list","sel":".item"}]
EOF
```

Supported ops: `title`, `url`, `text`(sel), `html`(sel), `attr`(sel,name), `count`(sel), `list`(sel), `exists`(sel), `visible`(sel), `click`(sel), `fill`(sel,val), `hover`(sel), `eval`(js — must be an **expression**, not statements).

**Not batchable** (different mechanism — use standalone): `press`, `shot`/`shot-el`, navigation (`open`/`new`/`reload`/`back`/`fwd`/`close`), `wait*`.

## Assertions (exit 1 on fail — CI-friendly)

| Command | Notes |
|---|---|
| `surf exists "<sel>"` | exit 0 if `querySelector(sel)` is non-null |
| `surf visible "<sel>"` | exit 0 if present AND visible (display/visibility/opacity + offsetParent checks; fixed-position aware) |
| `surf assert "<js>" [expected]` | with `expected`: exit 0 if `String(<js>) == expected`; without: exit 0 if `<js>` is truthy |

All print a stderr message and return rc 1 on failure.

## Interact

| Command | Returns |
|---|---|
| `surf click "<sel>"` | scrolls into view, clicks first match → `{"ok":true,"tag":"..."}` or `{"ok":false,"err":"not_found"}` |
| `surf fill "<sel>" "<val>"` | focuses, sets `.value`, fires `input` + `change` → `{"ok":true,...}` / `{"ok":false,"err":"not_found"}` (React/Vue-safe) |
| `surf hover "<sel>"` | dispatches `mouseover`/`mousemove`/`mouseenter` (scrolls into view) → `{"ok":true,"tag":...}` |
| `surf select-option "<sel>" "<val>"` | sets a `<select>` value + fires `input`/`change` → `{"ok":true,"value":...}` / `{"ok":false,"err":"not_select"}` / `not_found` |
| `surf submit "<sel>"` | resolves the form (from a form element, `.form`, or `closest('form')`) and calls `requestSubmit()` → `{"ok":true}` / `{"ok":false,"err":"no_form"}` / `not_found` |
| `surf scroll down\|up\|top\|bottom [N]` | scroll by N viewport-heights (default 1); `N` sanitized to digits |
| `surf scroll-to "<sel>"` | `scrollIntoView({block:"center",behavior:"instant"})` → `{"ok":true}` / `not_found` |
| `surf press "<key>"` | real key/chord via System Events — see below |

### `press` — key chords

`surf press "<key>"` uses **real key synthesis** (so Enter submits, Escape closes, `cmd+a` selects all — unlike JS-dispatched events). Syntax: a key, optionally preceded by `+`-joined modifiers.

- Keys: `enter`/`return`, `tab`, `escape`/`esc`, `space`, `delete`/`backspace`, `up`/`down`/`left`/`right`, or any single char (`a`, `!`, …).
- Modifiers: `cmd` (=command/meta), `ctrl`, `alt` (=option), `shift`.
- Examples: `surf press enter`, `surf press tab`, `surf press cmd+a`, `surf press cmd+shift+c`, `surf press shift+arrowright`.

Activates the target tab's window first (can't press keys on a background tab). Needs **Accessibility** for your terminal; on failure it opens the Accessibility pane and says so.

## Screenshots

| Command | Notes |
|---|---|
| `surf shot [<path>]` | window screenshot → PNG (default `./surf-shot.png`). Brings the window to front, reads `bounds`, `screencapture -R`. Needs **Screen Recording** for the terminal. |
| `surf shot-el "<sel>" [<path>]` | element screenshot: scrolls into view, reads `getBoundingClientRect` + `devicePixelRatio` + chrome height, captures the window, crops with built-in `sips`. Best-effort positioning. → `{"ok":...}` for missing selectors |

## Diagnostics

```bash
surf doctor
```

One-shot environment + permission check. Prints ✓/✗ for: macOS, Chrome running, **JavaScript-from-AppleScript toggle** (probed on a throwaway `about:blank` tab — never restricted, unlike x.com/incognito/PWA), **Screen Recording** (`screencapture`), **Accessibility** (`UI elements enabled`). Exit 0 if all green, 1 otherwise. Each ✗ prints the fix path. Run this first when something won't work.

## Setup

```bash
surf setup
```

Attempts to GUI-click **View → Developer → Allow JavaScript from Apple Events**, then verifies with a real JS call. Chromium menus don't respond to scripted clicks, so if it can't, follow the printed manual instruction. Needs Accessibility for the GUI attempt; the manual click needs none.

## Environment

| Variable | Default | Purpose |
|---|---|---|
| `SURF_APP` | `Google Chrome` | app name (`Google Chrome Beta`, `Chromium`, …) |
| `SURF_TARGET_FILE` | `~/.config/surf/target` | where the pinned tab is stored |
| `SURF_WAIT_TIMEOUT` | `15` | default `wait*` timeout (seconds) |
| `SURF_WAIT_INTERVAL` | `0.3`–`0.4` | `wait*` poll interval (seconds) |

## Recipes

```bash
# Scrape the H1 of the page you're reading
surf text "h1"

# Structured scrape (one round-trip)
surf eval 'JSON.stringify({title:document.title, h1:document.querySelector("h1")?.innerText, links:document.querySelectorAll("a").length})'

# Scrape a list of all item titles
surf list ".item-title"

# Fill + submit a search
surf fill "input[name=q]" "skyvern"
surf click "button[type=submit]"

# Pick a dropdown option, then submit
surf select-option "select#country" "US"
surf submit "form#checkout"

# Wait for results to render, then assert + screenshot
surf wait ".result" --timeout 20
surf assert 'document.querySelectorAll(".result").length' '5'
surf shot-el ".result" ~/result.png

# Press Enter to confirm a dialog
surf press enter

# Drive a background tab without losing your place
surf tabs
surf select w2.t5
surf text "h1"
surf select reset

# Machine-readable session for an agent
surf tabs --json | jq '.[] | select(.url|test("github"))'
```

## How it works

Pure bash + `osascript`. JS is written to a temp file and read by AppleScript (`read POSIX file … as «class utf8»`) to avoid quoting hell, then `execute … javascript` runs it in the target tab. `--json` for `tabs` is built via AppleScript tab-delimited output → `python3 -c json.dumps`; `here`/`text`/`count` use the browser's `JSON.stringify`. No background process ever runs.

## Exit codes

`0` = success · `1` = error / assertion failed / timeout / missing element (commands return JSON with `ok:false` and rc 0 for not-found; assertions/wait return rc 1).
