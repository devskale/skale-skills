---
name: surf-guide
description: "Surf — lean macOS CLI to drive your real, logged-in Google Chrome via AppleScript. Setup, capabilities, recipes, and a head-to-head comparison with rodney and chrome-devtools-mcp."
version: 1.0.0
date: 2026-07-12
---

# Surf — Drive Your Real Chrome (macOS, AppleScript)

> Lean, Rodney-style CLI that controls the browser you're **already logged into** — cookies, tabs, and sessions intact. No daemon, no debug port, no extension, no CDP, no "Allow remote debugging?" dialog.

**Skill:** [`skills/surf/`](../../skills/surf/) · **Command:** `surf` · **Platform:** macOS + Google Chrome only

---

## What it is

`surf` is a ~11 KB bash script that talks to your running Google Chrome through **macOS AppleScript** and Chrome's **"Allow JavaScript from Apple Events"**. It doesn't launch a browser — it drives the one you have open. JS is injected via `execute … javascript`; navigation/tab control uses Chrome's AppleScript dictionary.

```
bash  →  osascript  →  Google Chrome (your live session)
```

No background process, nothing listening on a port, no extension to install, no per-connection permission prompt.

## Install & one-time setup

```bash
cd skills/surf && ./install.sh     # creates ~/.local/bin/surf
surf setup                          # try to flip the Chrome toggle via GUI
```

`surf setup` will attempt to GUI-click the toggle, but **Chromium menus don't respond to scripted clicks** — so if it reports JS still off, do it once by hand:

> Chrome menu bar → **View → Developer ▸ → Allow JavaScript from Apple Events** (a ✓ appears).

That single toggle is permanent and unlocks every JS command (`text`, `click`, `fill`, `eval`, …). Pure navigation (`tabs`, `here`, `open`, `new`, `reload`) works without it.

> Optional, for `surf shot` only: grant **Screen Recording** to your terminal in *System Settings → Privacy & Security → Screen Recording* (`screencapture` needs it).

## What you can do with `surf`

### List & target tabs
```bash
surf tabs                       # w1.t1  URL  |  title  (every window/tab)
surf tabs --json                # [{window,tab,url,title}, ...]
surf here                       # active/target tab: URL | title
surf select w1.t3               # pin a tab — operate it in the background, no focus steal
surf select reset               # back to active tab of front window
surf close                      # close the target/active tab
```
`select` is the killer feature vs plain AppleScript: **drive a background tab without leaving the one you're reading.**

### Navigate
```bash
surf open https://example.com   # navigate the target tab
surf new https://example.com    # new tab (a normal window)
surf reload                     # reload target tab
surf back / surf fwd            # history.back() / forward()
```

### Wait (async-ready)
```bash
surf wait ".result" --timeout 20   # poll until element exists (exit 1 on timeout)
surf wait-url "/checkout"          # poll until URL contains substring
surf wait-stable                   # poll until the DOM stops changing
```

### Read  (tabs/here/text/count accept --json)
```bash
surf title / surf url           # document.title / location.href
surf text "h1"                  # textContent of first match (CSS)
surf html "article"             # outerHTML of first match
surf attr "a.login" "href"      # attribute value
surf count "a"                  # number of matches
surf list ".item-title"         # JSON array of all matches' text (scrape lists)
surf eval 'JSON.stringify({...})'  # arbitrary JS, result stringified
```

### Assert (exit 1 on fail — CI-friendly)
```bash
surf exists ".result"           # exit 0 if present
surf visible ".modal"           # exit 0 if present AND visible
surf assert 'document.querySelectorAll(".row").length' '5'   # exit 0 if JS == expected
```

### Interact
```bash
surf click "button#submit"      # scrolls into view, clicks first match
surf fill "input[name=q]" "x"   # sets value + fires input/change (React/Vue-safe)
surf hover ".menu-item"         # mouseover/mouseenter
surf select-option "select#c" "US"  # set a <select> value + fire change
surf submit "form#checkout"     # submit the enclosing form (requestSubmit)
surf scroll down 3              # scroll by N viewport-heights (down|up|top|bottom)
surf scroll-to "h2"             # scroll element into view (center)
surf press enter                # real key/chord: enter, tab, escape, a, cmd+a
```

### Screenshot
```bash
surf shot                       # → ./surf-shot.png  (window rect, no shadow)
surf shot ~/Desktop/before.png
surf shot-el "h1" after.png     # one element (crop via sips)
```

### Meta
```bash
surf --version                  # surf 1.0.0
surf --selfcheck                # version + dir + last update
surf --update                   # git pull the skill
surf help                       # full usage
```


## Recipes

```bash
# Scrape the heading of whatever you're reading
surf text "h1"

# Multi-field structured scrape (one round-trip)
surf eval 'JSON.stringify({
  title: document.title,
  price: document.querySelector(".price")?.innerText,
  stock: document.querySelector("[data-stock]")?.dataset.stock
})'

# Fill + submit a search
surf fill "input[name=q]" "skyvern browser agent"
surf click "button[type=submit]"

# Drive a background tab without losing your place
surf tabs
surf select w1.t5
surf text "h1"
surf select reset

# Before/after screenshot during a change
surf shot ~/before.png
surf click "button#toggle"
surf shot ~/after.png

# Wait for something (poll)
for i in {1..20}; do
  [ "$(surf count '.result')" -gt 0 ] && break
  sleep 0.5
done
```

## Comparison: `surf` vs `rodney` vs `chrome-devtools-mcp`

These three overlap but solve different problems. Pick by what you need.

| | **surf** | **rodney** | **chrome-devtools-mcp** |
|---|---|---|---|
| **Mechanism** | macOS AppleScript + Chrome JS-from-Apple Events | Go binary (`go-rod`) → CDP | MCP server (Puppeteer) → CDP `--autoConnect` |
| **Whose browser** | ✅ your real, logged-in Chrome | ❌ launches its own Chrome | ✅ your real Chrome |
| **Per-connection dialog** | ✅ **none** | ✅ none (own browser) | ❌ **"Allow remote debugging?" every connect** (Chrome 144+, won't-fix) |
| **Platform** | macOS only | cross-platform | cross-platform |
| **Install weight** | ~11 KB, **zero deps** | Go binary (~11 MB) + Python shim | `npx`, downloads on demand |
| **Headless** | ❌ (drives visible Chrome) | ✅ default + `--show` | ❌ (your visible browser) |
| **Form factor** | bash CLI | bash CLI | MCP tools (drops into pi/Claude/etc.) |
| **Selectors** | CSS + arbitrary JS | CSS + JS + a11y tree | rich (text/role/CSS) + JS |
| **Background tabs (no focus)** | ✅ `select w1.tN` | ❌ one session | ⚠️ via `select_page` |
| **Screenshots** | ✅ window (`shot`, needs Screen Recording) | ✅ page + element | ✅ page + element |
| **Network / console / perf** | ❌ | ❌ | ✅ **console, network, perf traces, Lighthouse, heap** |
| **Assertions / CI** | DIY via `eval`/`count` + exit codes | ✅ built-in (`exists`, `assert`, `count`) | ❌ |
| **PDF / a11y audit** | ❌ | ✅ PDF + a11y tree | ✅ Lighthouse audits |
| **Multi-tab session** | ✅ your real tabs | isolated profile | ✅ your real tabs |
| **Agentic / LLM-driven** | ❌ (you are the loop) | ❌ (you are the loop) | ❌ (you are the loop) |
| **Best for** | Quick control of the browser you're in, on macOS, zero setup | Headless automation, scraping, CI, cross-platform | Deep debugging — console, network, perf — of a live session |

### When to pick which

- **`surf`** — *"I'm on a Mac, I want to click/fill/scrape in the browser I'm already logged into, and I don't want a daemon, a port, or a permission dialog."* The lightest path to your real session.
- **`rodney`** — *"I need a clean, scriptable browser for scraping, form automation, PDF export, a11y checks, or CI smoke tests — cross-platform, headless, with assertions."* It launches its own isolated browser (not yours).
- **`chrome-devtools-mcp`** — *"I need to debug a live page — read console logs, inspect network requests, record a performance trace, run Lighthouse, take a heap snapshot."* Accept the per-connection "Allow" click; you're at the keyboard anyway.

**They compose.** Run several:
- `surf` for everyday click/fill/scrape on your real session (no friction).
- `chrome-devtools-mcp` when you need console/network/perf on that same session.
- `rodney` for isolated/headless jobs and CI.

## Limitations & gotchas

- **macOS + Google Chrome only.** No Brave/Edge/Safari/Firefox, no Linux/Windows (it's AppleScript). Override the app name with `SURF_APP` (e.g. `Chromium`) — untested.
- **JS commands need the one-time toggle** (View → Developer → Allow JavaScript from Apple Events). `surf setup` tries to flip it but Chromium ignores scripted menu clicks — click it manually once.
- **`shot` needs Screen Recording** permission for your terminal. `surf shot` detects the failure and opens the settings pane for you.
- **Targets the active tab of the front window** by default. Use `surf select wN.tN` to pin a tab (works on background tabs); re-run `surf tabs` if a ref goes stale after you reorder/close.
- **Not agentic.** `surf` is a deterministic remote control — **you** are the reasoning loop. For LLM-driven browsing use [browser-use](https://github.com/browser-use/browser-use) or [Stagehand](https://github.com/browserbase/stagehand) (separate browser) or [Skyvern](https://github.com/Skyvern-AI/skyvern) (can `cdp-connect` to your Chrome — heavier).
- **No network/console/perf.** That's chrome-devtools-mcp's job (see above).
- **`eval` returns one stringified value.** Return JSON for complex shapes.

## How it works (under the hood)

Pure bash + `osascript`. To avoid quoting hell, JS is written to a temp file and read by AppleScript:

```applescript
tell application "Google Chrome"
  return execute active tab of front window javascript (read POSIX file "/tmp/surfXXX.js" as «class utf8»)
end tell
```

With a pinned target it addresses a specific tab without activating it:

```applescript
tell application "Google Chrome"
  return execute (tab 3 of window 1) javascript …
end tell
```

State (the pinned tab) lives in `~/.config/surf/target`. No background process ever runs.

## References

- **Skill source:** [`skills/surf/`](../../skills/surf/) · **Full command reference:** [`skills/surf/references/commands.md`](../../skills/surf/references/commands.md)
- **Comparison context:** [browser-tools-comparison.md](browser-tools-comparison.md) · **chrome-devtools-mcp setup:** [chrome-dev.md](chrome-dev.md) · **rodney setup:** [`guides/rodney-setup.md`](../../guides/rodney-setup.md)
