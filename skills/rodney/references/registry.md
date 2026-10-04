# Rodney Command Registry (generated)

> **Generated from the installed binary** (`rodney help --json`) — do not edit
> by hand; regenerate with `scripts/gen-registry.sh --write`. The binary is
> the source of truth; for one command at runtime prefer `rodney help <command>`.

## Accessibility

### `rodney ax-find [--name N] [--role R] [--json]`

Find accessible nodes by name/role. Exit 1 if no match.

```bash
rodney ax-find --role button --name Checkout
```

### `rodney ax-node <selector> [--json]`

Show accessibility info for one element.

```bash
rodney ax-node "#submit"
```

### `rodney ax-tree [--depth N] [--json]`

Dump the accessibility tree (roles, names, states).

Flags:

- `--depth N   limit tree depth`
- `--json      structured output`

```bash
rodney ax-tree --depth 3
```

## Advanced interaction

### `rodney drag <source-selector> <target-selector>`

Drag an element onto another via real mouse events (down, move, up) — sliders, sortables, kanban boards.

```bash
rodney drag ".card" "#done-column"
```

### `rodney filechooser <path>`

Intercept file choosers as a persistent foreground process: every chooser the page opens gets the given file, until Ctrl+C.

```bash
rodney filechooser upload.png
```

### `rodney onload <js> [--clear]`

Register JS that runs on EVERY navigation of the session (persisted) — hide cookie banners, inject test hooks, stub globals. No args: list.

Flags:

- `--clear   remove all onload scripts`

```bash
rodney onload "document.querySelector('.banner')?.remove()"
rodney onload
rodney onload --clear
```

### `rodney tap <selector>`

Tap an element with touch semantics (pairs with `rodney device` emulation).

```bash
rodney device iphone-x && rodney tap "#menu"
```

### `rodney xpath-of <selector>`

Print the computed XPath of an element — helps building XPath queries.

```bash
rodney xpath-of "h1"
```

## Browser lifecycle

### `rodney connect <host:port>`

Attach to an already-running Chrome's remote debug port instead of launching one.

```bash
rodney connect 127.0.0.1:9222
```

### `rodney start [--show] [--insecure|-k] [--incognito] [--local]`

Launch Chrome (headless by default) and save the connection state. Other rodney commands reuse this browser.

Flags:

- `--show      launch visible Chrome instead of headless`
- `--insecure, -k   ignore certificate errors`
- `--incognito  throwaway profile, deleted on stop`
- `--local    directory-scoped session (./.rodney/)`

```bash
rodney start
rodney start --show --insecure
```

### `rodney status`

Show browser status: running, debug URL, active page, current URL.

```bash
rodney status
```

### `rodney stop`

Shut down Chrome, the auth proxy, the console collector; clear session state.

```bash
rodney stop
```

## Console

### `rodney console [--level L] [--json] [--browser] [--follow] [--clear]`

Read console output. Without a background collector: live stream (Ctrl+C). With collector (console-start): print buffered messages.

Flags:

- `--level L    filter: log, info, warn, error, debug`
- `--json       JSON lines output`
- `--browser    also browser-level log entries (network errors, security)`
- `--follow     print buffered, then tail live`
- `--clear      print and empty the buffer`

```bash
rodney console --level error
rodney console --json | jq 'select(.type=="error")'
```

### `rodney console-start`

Start the background console collector — captures console/browser logs between commands into console.jsonl.

```bash
rodney console-start
```

### `rodney console-stop`

Stop the collector and remove the buffer.

```bash
rodney console-stop
```

## Cookies

### `rodney cookie-clear [--domain <domain>]`

Clear all cookies, or only those of one domain.

```bash
rodney cookie-clear --domain example.com
```

### `rodney cookie-delete <name> [--domain d] [--url u] [--path p]`

Delete cookies by name (scoped by domain/url/path if given).

```bash
rodney cookie-delete session
```

### `rodney cookie-get [name] [--json]`

Get cookies: one value by name, or all cookies (--json for structured output).

```bash
rodney cookie-get
rodney cookie-get session --json
```

### `rodney cookie-set <name> <value> [--domain d] [--url u] [--path p] [--expires t] [--http-only] [--secure]`

Set a cookie. Defaults to the current page's URL/domain.

```bash
rodney cookie-set session abc123
```

## Debugging

### `rodney doctor`

Self-diagnostics: version, Chrome detection, ffmpeg, session state, browser connectivity. Exit 2 if any check fails.

```bash
rodney doctor
```

### `rodney monitor [host:port]`

Serve rod's live monitor web UI (pages, eval console, request log). Foreground process.

```bash
rodney monitor
```

## Dialogs

### `rodney dialog [--dismiss] [--text MSG] [--json]`

Handle JavaScript dialogs (alert/confirm/prompt/beforeunload). Runs as a persistent foreground process: handles every dialog that opens until Ctrl+C. Default accepts dialogs; use --dismiss to reject them.

Flags:

- `--dismiss   dismiss (cancel) instead of accepting`
- `--text MSG   response text for prompt dialogs`
- `--json      JSON lines output`

```bash
rodney open page.html && rodney dialog
rodney dialog --dismiss
```

## Element checks

### `rodney assert <js-expression> [expected] [-m msg]`

Assert a JS expression is truthy (or equals 'expected'). Exit 1 on failure.

Flags:

- `-m, --message msg   custom failure message`

```bash
rodney assert "document.title" "Dashboard"
rodney assert "document.querySelectorAll('.row').length" 5
```

### `rodney count <selector>`

Count matching elements.

```bash
rodney count "li.item"
```

### `rodney exists <selector>`

Check if an element exists. Exit 0 if yes, exit 1 if not.

```bash
rodney exists ".error"
```

### `rodney visible <selector>`

Check if an element is visible. Exit 0/1.

```bash
rodney visible "#modal"
```

## Emulation

### `rodney geo --lat <lat> --lon <lon>`

Spoof geolocation coordinates.

```bash
rodney geo --lat 52.52 --lon 13.40
```

### `rodney locale <locale>`

Override the locale (what Intl APIs report).

```bash
rodney locale de-DE
```

### `rodney media [--type T] [--feature name=value ...]`

Emulate media type or features (e.g. prefers-color-scheme).

```bash
rodney media --type print
rodney media --feature prefers-color-scheme=dark
```

### `rodney timezone <timezone-id>`

Override the timezone (what Date/timezone APIs report).

```bash
rodney timezone Asia/Tokyo
```

### `rodney ua <user-agent>`

Override the browser user agent string.

```bash
rodney ua "Mozilla/5.0 (iPhone)"
```

## Interaction

### `rodney clear <selector>`

Clear an input field.

```bash
rodney clear "#search"
```

### `rodney click <selector>`

Click an element (waits for it to appear).

```bash
rodney click "button#submit"
```

### `rodney download <selector> [file|-]`

Download the href/src target of an element. '-' streams to stdout.

```bash
rodney download "a.pdf"
rodney download "img.logo" -
```

### `rodney file <selector> <path|->`

Set a file on a file input element. '-' reads the content from stdin.

```bash
rodney file "#upload" photo.png
cat data.csv | rodney file "#upload" -
```

### `rodney focus <selector>`

Focus an element (use before 'type' or 'press').

```bash
rodney focus "#email"
```

### `rodney hover <selector>`

Hover over an element (triggers mouseenter/mouseover).

```bash
rodney hover ".menu-item"
```

### `rodney input <selector> <text>`

Type text into an input field by setting .value (fast, but fires no key events — use 'type' or 'press' if the page reacts to keyboard input).

```bash
rodney input "#search" "query"
```

### `rodney js <expression>`

Evaluate a JavaScript expression on the active page. Bare expressions are auto-wrapped; statements like console.log work via the wrapper.

```bash
rodney js "document.title"
rodney js "1 + 1"
```

### `rodney press <key> [key ...]`

Press keys as real keyboard events. Combos use +; multiple args press in sequence.

Flags:

- `keys: enter, tab, escape, backspace, delete, space, up, down, left, right, home, end, pageup, pagedown, shift, ctrl, alt, meta, or a single character`

```bash
rodney press enter
rodney press ctrl+a
rodney press shift tab
```

### `rodney scroll <x> <y> [--steps N]`

Scroll the page by x/y pixels (relative; negative y scrolls up).

Flags:

- `--steps N   scroll in N increments (smooth scroll, lazy-loading)`

```bash
rodney scroll 0 600
rodney scroll 0 1000 --steps 10
```

### `rodney scroll-el <selector>`

Scroll an element into view.

```bash
rodney scroll-el "#footer"
```

### `rodney select <selector> <value>`

Select a dropdown option by value.

```bash
rodney select "#topic" "support"
```

### `rodney submit <selector>`

Submit a form.

```bash
rodney submit "form#login"
```

### `rodney type <text>`

Type text into the focused element as real keyboard input — fires key and input events (SPA validation, autocomplete react to it).

```bash
rodney focus "#search" && rodney type "query"
```

## Navigation

### `rodney back`

Go back one step in history.

```bash
rodney back
```

### `rodney clear-cache`

Clear the browser cache.

```bash
rodney clear-cache
```

### `rodney forward`

Go forward one step in history.

```bash
rodney forward
```

### `rodney open <url> [--reuse]`

Navigate the active page to a URL. http:// is added if no scheme is given.

Flags:

- `--reuse    switch to an existing page already at that URL instead of navigating the active page away`

```bash
rodney open https://example.com
rodney open https://example.com --reuse
```

### `rodney reload [--hard]`

Reload the page.

Flags:

- `--hard   bypass the cache`

```bash
rodney reload --hard
```

## Network interception

### `rodney block <pattern> [--method M]`

Fail matching requests client-side (offline behaviour). Persistent foreground process.

```bash
rodney block '*.ads.*'
```

### `rodney mock <pattern> <response> [--status N] [--type MIME] [--method M]`

Serve a canned response for matching requests. Runs as a persistent foreground process — Ctrl+C to stop.

Flags:

- `--status N    HTTP status (default 200)`
- `--type MIME   content type (default text/plain)`
- `--method M    restrict to HTTP method`
- `response '-' reads body from stdin`

```bash
rodney mock '*api/users*' '{"id":1}' --type application/json
```

## Network requests

### `rodney requests [--json] [--follow] [--clear]`

Read captured network requests. Without a background collector: live stream (Ctrl+C). With collector (requests-start): print buffered requests.

Flags:

- `--json    JSON lines output`
- `--follow  print buffered, then tail live`
- `--clear   print and empty the buffer`

```bash
rodney requests
rodney requests --json | jq 'select(.status>=400)'
```

### `rodney requests-start`

Start the background request collector — captures all requests/responses between commands into requests.jsonl.

```bash
rodney requests-start
```

### `rodney requests-stop`

Stop the request collector and remove the buffer.

```bash
rodney requests-stop
```

## Page info

### `rodney attr <selector> <name>`

Print an attribute value of an element.

```bash
rodney attr "a.link" href
```

### `rodney history`

Print the navigation history of the active page (* marks current).

```bash
rodney history
```

### `rodney html [selector]`

Print HTML of the page or of one element (pretty-printed).

```bash
rodney html
rodney html "#main"
```

### `rodney pdf [file]`

Save the page as PDF (default: <title>.pdf).

```bash
rodney pdf out.pdf
```

### `rodney resource <url> [file|-]`

Print the cached body of an already-loaded resource (script, XHR response, image) — no new request. Substring URL match.

```bash
rodney resource /api/users
rodney resource app.js script.js
```

### `rodney stopload`

Stop the page's pending navigation and resource fetches — proceed with a half-loaded page (scraping speed).

```bash
rodney stopload
```

### `rodney text <selector>`

Print the text content of an element.

```bash
rodney text "h1"
```

### `rodney title`

Print the page title.

```bash
rodney title
```

### `rodney url`

Print the current URL.

```bash
rodney url
```

## Screenshots

### `rodney screenshot [-w N] [-h N] [--full] [file]`

Take a PNG screenshot. Default captures the FULL page; -h limits to the viewport height. '-' for stdout.

Flags:

- `-w N       viewport width (default 1280)`
- `-h N       viewport height (limits capture to the viewport)`
- `--full     force full-page capture even with -h`

```bash
rodney screenshot
rodney screenshot --full page.png
```

### `rodney screenshot-el <selector> [file]`

Screenshot a single element.

```bash
rodney screenshot-el "#chart"
```

## Tabs

### `rodney closepage [index|t:targetID]`

Close a page (default: the active one). t:<id> is drift-proof; the active index is adjusted automatically.

```bash
rodney closepage
rodney closepage t:ABC123
```

### `rodney newpage [url]`

Open a new page/tab and make it active.

```bash
rodney newpage https://example.com
```

### `rodney page <index|t:targetID>`

Switch the active page. t:<id> pins by stable target ID — drift-proof when parallel sessions shift indices.

```bash
rodney page 1
rodney page t:ABC123
```

### `rodney pages [--json]`

List all pages/tabs. * marks the active one.

Flags:

- `--json   machine-readable: index, target, title, url, active`

```bash
rodney pages
rodney pages --json
```

## Video recording

### `rodney start-video`

Start recording the page as video frames (saved on stop-video).

```bash
rodney start-video
```

### `rodney stop-video [file]`

Stop recording and save. .gif by default; .mp4 requires ffmpeg in PATH.

```bash
rodney stop-video demo.gif
```

## Viewport & device emulation

### `rodney device <name> [--landscape] [--clear] [--list]`

Emulate a device: viewport, device pixel ratio, touch, and user agent in one step.

Flags:

- `--landscape   use the landscape orientation`
- `--clear   stop emulating`
- `--list    list available devices`

```bash
rodney device iphone-x
rodney device pixel-2 --landscape
rodney device --list
```

### `rodney headers [k=v ...] [--clear]`

Set extra HTTP headers sent with every request on this session (e.g. auth tokens, API versioning). No args: list current. Persists in the session state.

Flags:

- `--clear   remove all extra headers`

```bash
rodney headers Authorization=Bearer tok
rodney headers X-Api-Version=2
rodney headers
```

### `rodney viewport <width> <height> [--clear]`

Set the page viewport size (affects layout, screenshots, innerWidth). Persists on the page until cleared or the browser stops.

Flags:

- `--clear   reset to default viewport`

```bash
rodney viewport 1280 800
rodney screenshot
```

## Waiting

### `rodney sleep <seconds>`

Sleep for N seconds.

```bash
rodney sleep 2
```

### `rodney wait <selector> | rodney wait --url <substring>`

Wait until an element appears (default timeout 30s, ROD_TIMEOUT to change).

```bash
rodney wait ".results"
```

### `rodney waitidle`

Wait until the network is idle.

```bash
rodney waitidle
```

### `rodney waitload`

Wait for the page load event.

```bash
rodney waitload
```

### `rodney waitnav`

Wait until the page navigates to a different URL (redirects, form submits, SPA route changes).

```bash
rodney waitnav
```

### `rodney waitpage [seconds]`

Wait until a NEW page/tab opens (window.open, target=_blank, OAuth popups) and switch the active page to it.

```bash
rodney waitpage 30
```

### `rodney waitstable`

Wait until the DOM stops changing.

```bash
rodney waitstable
```

