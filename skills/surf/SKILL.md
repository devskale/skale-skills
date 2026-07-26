---
name: surf
version: "1.4.1"
description: "Drive the user's real, logged-in Google Chrome on macOS for web scraping, form filling, screenshots, and tab-aware automation — no daemon, no debug port, no extension, no per-connection dialog. Sessions stay intact (cookies, logins, tabs). Uses macOS AppleScript + Chrome's 'Allow JavaScript from Apple Events'. Use when the user wants to automate, scrape, click, fill, read, or screenshot the browser they are already logged into. Triggers on: control my Chrome, drive my browser, automate my logged-in browser, scrape this page, fill this form, click this, read the page, take a browser screenshot, surf."
---

# Surf — Drive Your Real Chrome (macOS AppleScript)

`surf` drives the browser you're already logged into — your **session** (cookies, logins, tabs) stays intact. It speaks macOS AppleScript + Chrome's "Allow JavaScript from Apple Events": no daemon, no port 9222, no extension, no CDP, no "Allow remote debugging?" dialog. Rodney-style fire-and-forget CLI.

## Quick Start

```bash
cd skills/surf && ./install.sh   # macOS + Google Chrome required
surf setup                       # one-time: enable Chrome JS-from-AppleScript
surf doctor                      # ✓/✗ check: macOS · Chrome · JS toggle · Screen Recording · Accessibility
surf tabs && surf here           # smoke test — list tabs, show the active one
surf help                      # categorized overview; `surf help <cmd>` drills in
```

**Manual toggle** (only if `surf setup` can't click it — Chromium menus ignore scripted clicks): Chrome menu → **View → Developer ▸ → Allow JavaScript from Apple Events** (a ✓ appears). Needed for `text`/`click`/`fill`/`eval`/`title`; pure navigation (`open`/`tabs`/`here`) works without it.

**Verify before assuming failure:** when a command misbehaves, run `surf doctor` first — it pinpoints the missing permission or toggle rather than guessing.

## Usage — run each command as a separate bash call

`surf` is a CLI, not an MCP tool — invoke each subcommand via **bash**, one per call. It targets the **active tab of the front window** unless you `surf select` a tab. Selectors are CSS. The map below is the vocabulary; for every flag, exact return shape, and worked recipe see `references/commands.md`.

**Self-discovery:** `surf help` prints the categorized overview below with examples; `surf help <command>` (or `surf <command> --help`) shows usage, return value, and an example for any single command — no need to leave the terminal.

## Command map

```
Navigation & tabs
  surf tabs                       list windows → tabs (refs like w1.t3); --json
  surf here                       active/target tab: URL | title; --json
  surf select [wN.tN | reset]     pin a tab (operate background tabs w/o focus); reset to clear
  surf open <url> · new [<url>] · reload · back · fwd · close

Read
  surf title | url
  surf text "<sel>" · html "<sel>" · attr "<sel>" <name>
  surf count "<sel>" · list "<sel>"        (list = JSON array of all matches' text)
  surf eval "<js>"                          run JS in the page, print stringified result

Interact
  surf click "<sel>" · fill "<sel>" "<val>" · hover "<sel>"
  surf select-option "<sel>" "<val>" · submit "<sel>"
  surf scroll down|up|top|bottom [N] · scroll-to "<sel>"
  surf press "<key>"                        real key/chord (enter, tab, escape, cmd+a)

Wait        (all take --timeout N; exit 1 on timeout)
  surf wait "<sel>" · wait-url "<sub>" · wait-stable

Assert      (exit 1 on fail — CI-friendly)
  surf exists "<sel>" · visible "<sel>" · assert "<js>" [expected]

Screenshots
  surf shot [<path>] · shot-el "<sel>" [<path>]

Meta
  surf batch · surf doctor · surf setup · surf --version | --selfcheck | help
```

## Batch — many ops, one browser call

Feed a JSON steps array on stdin; get a JSON array of `{op,v}` back. One `execute javascript` round-trip cuts `osascript` launch overhead in agent loops. Each step is try/catch-wrapped, so one bad selector returns `{err}` instead of aborting the run; `v` is exactly what the standalone op prints.

```bash
surf batch <<'EOF'
[{"op":"title"},{"op":"count","sel":"a"},{"op":"text","sel":"h1"},{"op":"fill","sel":"#q","val":"x"}]
EOF
```

Ops: `title`/`url`/`text`/`html`/`attr`/`count`/`list`/`exists`/`visible`/`click`/`fill`/`hover`/`eval`. **Not batchable** (different mechanism — use the standalone command): `press`, `shot`/`shot-el`, navigation (`open`/`new`/`reload`/`back`/`fwd`/`close`), `wait*`.

## When to pick something else

| Need | Use |
|---|---|
| Your real **session** on macOS, zero ceremony | **surf** |
| CI / headless / cross-platform, or a fresh isolated browser | **rodney** |
| Perf traces / Lighthouse / console / network — needs CDP | **chrome-devtools-mcp** |

`surf` drives your **visible** Chrome on **macOS-only**. It has no headless mode, no CDP-level introspection, and no Linux/Windows path — reach for the tool above instead.

## Gotchas

- **Tabs that lie about JS.** `x.com`, Chrome **app/PWA windows**, and **incognito** windows make `execute javascript` fail with *"Executing JavaScript through AppleScript is turned off"* **even when the global toggle is ON**. If reads/`eval` fail on one tab, `surf select` a normal-site tab and retry. `surf doctor` probes JS on a throwaway `about:blank` tab, so it is immune to this and reliably reports the true global state.
- **`wait-stable` foregrounds the tab.** Chrome throttles background-tab timers to ~1/sec, so a `setInterval`-driven mutation in a background tab can read as "quiet" and exit early. Keep the mutating tab foreground, or mutate via continuous DOM changes — the observer also fires on `appendChild`/attributes/`characterData`.
- **`select` is drift-resilient and never silent.** It stores `W T URL`; if indices shift (reorder/close) the next op re-resolves by URL and re-pins (note on stderr); a tab that navigated in place is followed silently; a gone tab falls back to the active tab. It never deletes the target on uncertainty. Re-list current refs with `surf tabs`.
- **`shot` captures the window rectangle** (`screencapture -R`), so a background-tab target is activated first. Needs **Screen Recording** for your terminal.
- **`press` uses real key synthesis** — so Enter submits and `cmd+a` selects all (unlike JS-dispatched events) — and activates the target window first; it cannot press keys on a background tab. Needs **Accessibility** for your terminal.
- **`eval` returns one stringified value.** For complex shapes, return JSON: `surf eval 'JSON.stringify({...})'`.
- **Exit codes:** `0` = success · `1` = error / assertion failed / timeout. Not-found is *not* an error for read/interact commands (they return JSON `{ok:false}` with rc 0); assertions and `wait*` return rc 1 on failure.

## References

- **[references/commands.md](references/commands.md)** — full command reference: every flag, exact return shapes, `press` key/chord syntax, environment variables (`SURF_APP`, `SURF_TARGET_FILE`, `SURF_WAIT_*`), how-it-works internals, and recipes. **Read when** you need a flag, an exact return value, env tuning, or a worked example beyond the map above.
- **[surf-todo.md](surf-todo.md)** — roadmap and known limitations. **Read when** a behavior surprises you (e.g. JS-failure detection on x.com/incognito is heuristic; `--json` is not yet uniform across all commands).
