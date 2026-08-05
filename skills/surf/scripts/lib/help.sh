# surf/lib/help.sh — self-discoverable help. Sourced by surf.sh.
#
# Two modes (both daemon-free, browser-free — pure text):
#   surf help               categorized overview (the whole vocabulary at a glance)
#   surf help <command>     per-command detail: usage, return, example, see-also
# `surf <command> --help` / `-h` and bare `surf` route here too (see main.sh).
#
# Bash-3.2-safe: no associative arrays — a case statement maps names to blocks.

# ── overview ────────────────────────────────────────────────────────
_surf_help_overview() {
cat <<EOF
surf v${VERSION} — drive your real, logged-in Chrome (macOS, AppleScript).
No daemon · no debug port · no extension · no per-connection dialog.
Targets the active tab of the front window unless you 'surf select' a tab.
Selectors are CSS.

USAGE
  surf <command> [args] [--json] [--timeout N]
  surf <command> --help      detail for one command (usage, return, example)
  surf help [command]        same thing

GETTING STARTED
  surf setup                 one-time: enable Chrome JS-from-AppleScript
  surf doctor                check of every prerequisite (macOS, Chrome, JS, perms)
  surf tabs                  list windows -> tabs (refs like w1.t3)
  surf here                  active tab: URL | title

COMMANDS
  Navigation & tabs   tabs  here  select  find-tab  open  new  reload  back  fwd  close
  Read                title  url  text  html  attr  count  list  table  eval  cookie  localstorage
  Interact            click  fill  form  hover  select-option  submit  scroll  scroll-to  press  download
  Wait                wait  wait-url  wait-stable       (all take --timeout N)
  Assert              exists  visible  assert           (exit 1 on fail)
  Screenshots         shot  shot-el  shot-full
  Bookmarks           bookmarks               read/search Chrome bookmarks (file, no browser)
  Pipeline            batch                   many ops, one browser call (stdin JSON)
  Diagnostics         doctor  setup  help  --version  --selfcheck  --update

EXAMPLES
  surf text "h1"                       read the page heading
  surf click "a.signin"                click the first match
  surf fill "input[name=q]" "skyvern"  type into a field
  surf wait ".result" --timeout 20     poll until it appears
  surf shot ~/page.png                 screenshot the window
  surf batch                           JSON steps on stdin  (see: surf help batch)

TIP
  Drill into any command:   surf click --help   (or: surf help click)
  Stuck? Run:               surf doctor
  Full reference:           $SKILL_ROOT/references/commands.md
EOF
}

# ── per-command detail ──────────────────────────────────────────────
# $1 = command name. Unknown name → caller (cmd_help) rejects before reaching here.
_surf_help_command() {
  case "$1" in
    tabs) cat <<'EOF'
surf tabs — list every window and tab

USAGE
  surf tabs [--json]

RETURNS
  One line per tab:  wN.tN  URL  |  title
  With --json:  [{"window":N,"tab":N,"url":"..","title":".."}, ...]
  Use the wN.tN refs with `surf select`.

EXAMPLE
  surf tabs
  surf tabs --json | jq '.[] | select(.url|test("github"))'

SEE ALSO
  here · select
EOF
;;
    here) cat <<'EOF'
surf here — what is on the target tab

USAGE
  surf here [--json]

RETURNS
  Bare:    URL | title
  --json:  {"window":N,"tab":N,"url":"..","title":".."}

EXAMPLE
  surf here
  surf here --json

SEE ALSO
  tabs · select · title · url
EOF
;;
    select) cat <<'EOF'
surf select — pin a tab to operate (even in the background, without focus)

USAGE
  surf select [wN.tN | reset]      blank = show the current target

RETURNS
  "target -> window W, tab T  (URL)" on pin; "target reset -> ..." on reset;
  "target: none (...)" when blank and nothing is pinned.

NOTES
  Drift-resilient: stores W T URL, so if indices shift (reorder/close) the next
  op re-resolves by URL and re-pins. A pinned tab navigated in place is followed
  silently; a gone tab falls back to the active tab. Never deletes on uncertainty.

EXAMPLE
  surf select w2.t5
  surf text "h1"            # reads the pinned (background) tab
  surf select reset

SEE ALSO
  tabs · here
EOF
;;
    open) cat <<'EOF'
surf open — be on a URL (reuse an open tab, else navigate)

USAGE
  surf open <url> [--new]

RETURNS
  "reuse: wN.tN  <url>"  — a tab with that URL was already open; switched to it
                          (and pinned as the target). No navigation.
  "ok: <url>"            — no reusable tab; navigated the target tab.
  "ok (wN.tN): <url>"    — same, with a pinned target.

NOTES
  Reuse is the default — two tiers, tried in order:
    1. exact URL match (a single trailing slash is ignored)
    2. same-origin path-segment prefix: the request path is a prefix of an open
       tab's path at a "/" boundary — e.g. open "localhost:3000/dashboard" reuses
       a tab at "localhost:3000/dashboard/ai-chat", landing on the deeper
       (already logged-in) page instead of duplicating.
  --new skips both tiers and navigates the target tab (forces a fresh load).

EXAMPLE
  surf open "https://example.com"
  surf open --new "https://example.com"   # force a fresh navigation

SEE ALSO
  new · find-tab · select · back · fwd · reload
EOF
;;
    new) cat <<'EOF'
surf new — open a new tab in the front window

USAGE
  surf new [<url>]      default about:blank

NOTES
  Opens in a normal (non-incognito, JS-capable) window.

EXAMPLE
  surf new "https://example.com"
  surf new

SEE ALSO
  open · close
EOF
;;
    reload) cat <<'EOF'
surf reload — reload the target tab

USAGE
  surf reload

SEE ALSO
  open · back · fwd
EOF
;;
    back) cat <<'EOF'
surf back — history.back() on the target tab

USAGE
  surf back

SEE ALSO
  fwd · reload
EOF
;;
    fwd) cat <<'EOF'
surf fwd — history.forward() on the target tab (alias: forward)

USAGE
  surf fwd

SEE ALSO
  back · reload
EOF
;;
    close) cat <<'EOF'
surf close — close the target (or active) tab

USAGE
  surf close

NOTES
  Clears a pinned target after closing.

SEE ALSO
  new · select
EOF
;;
    title) cat <<'EOF'
surf title — print document.title of the target tab

USAGE
  surf title [--json]

RETURNS
  document.title; with --json: {"title":".."}

SEE ALSO
  url · here · text
EOF
;;
    url) cat <<'EOF'
surf url — print location.href of the target tab

USAGE
  surf url [--json]

RETURNS
  location.href; with --json: {"url":".."}

SEE ALSO
  title · here
EOF
;;
    text) cat <<'EOF'
surf text — read an element's text

USAGE
  surf text "<css-selector>" [--json]

RETURNS
  Trimmed textContent of the first match (max 10000 chars); "NOT_FOUND" if none.
  With --json: {"selector":"..","found":true|false,"text":".."}

EXAMPLE
  surf text "h1"
  surf text "div.price" --json

SEE ALSO
  html · attr · list · count
EOF
;;
    html) cat <<'EOF'
surf html — read an element's outerHTML

USAGE
  surf html "<css-selector>" [--json]

RETURNS
  outerHTML of the first match; "NOT_FOUND" if none.
  With --json: {"selector":..,"found":bool,"html":..}

EXAMPLE
  surf html "h1"

SEE ALSO
  text · attr
EOF
;;
    attr) cat <<'EOF'
surf attr — read an element attribute

USAGE
  surf attr "<css-selector>" <attribute-name> [--json]

RETURNS
  getAttribute(name) of the first match; "NOT_FOUND" if no element.
  With --json: {"selector":..,"name":..,"found":bool,"value":..}

EXAMPLE
  surf attr "a" "href"

SEE ALSO
  text · html
EOF
;;
    count) cat <<'EOF'
surf count — count elements matching a selector

USAGE
  surf count "<css-selector>" [--json]

RETURNS
  querySelectorAll(sel).length as a string.
  With --json: {"selector":"..","count":N}

EXAMPLE
  surf count "a"
  surf count "li" --json

SEE ALSO
  list · text · exists
EOF
;;
    list) cat <<'EOF'
surf list — scrape text from all matches as a JSON array

USAGE
  surf list "<css-selector>"

RETURNS
  JSON array of every match's trimmed textContent (cap 1000 items, 500 chars each);
  "[]" if none.

EXAMPLE
  surf list ".item-title"
  surf list "a" | jq 'length'

SEE ALSO
  count · text
EOF
;;
    eval) cat <<'EOF'
surf eval — run JavaScript in the target tab

USAGE
  surf eval "<js-expression>"

RETURNS
  The expression's value, stringified. Returns ONE value — for complex shapes,
  return JSON:  surf eval 'JSON.stringify({a:1, b:document.title})'

EXAMPLE
  surf eval '1+1'
  surf eval 'document.querySelectorAll("a").length'
  surf eval 'JSON.stringify({title:document.title, h1:document.querySelector("h1")?.innerText})'

SEE ALSO
  text · count · batch
EOF
;;
    click) cat <<'EOF'
surf click — click the first match (scrolls into view first)

USAGE
  surf click "<css-selector>"

RETURNS
  {"ok":true,"tag":".."}  or  {"ok":false,"err":"not_found"}

EXAMPLE
  surf click "a.signin"
  surf click "button[type=submit]"

SEE ALSO
  fill · hover · submit · press
EOF
;;
    fill) cat <<'EOF'
surf fill — set a field's value and fire input/change (React/Vue-safe)

USAGE
  surf fill "<css-selector>" "<value>"

RETURNS
  {"ok":true,"mode":"value"|"richtext","tag":".."}  or  {"ok":false,"err":"not_found"}

NOTES
  Auto-detects the target: plain <input>/<textarea> get .value + input/change
  (React/Vue-safe); contenteditable elements (Notion/Gmail/Slack compose) get
  caret-to-end + execCommand('insertText') with an InputEvent fallback. The
  returned "mode" tells you which path ran.

EXAMPLE
  surf fill "input[name=q]" "skyvern"

SEE ALSO
  click · select-option · submit · press
EOF
;;
    hover) cat <<'EOF'
surf hover — fire mouseover/mousemove/mouseenter on the first match

USAGE
  surf hover "<css-selector>"

RETURNS
  {"ok":true,"tag":".."}  or  {"ok":false,"err":"not_found"}

EXAMPLE
  surf hover ".menu-trigger"

SEE ALSO
  click
EOF
;;
    select-option) cat <<'EOF'
surf select-option — set a <select> value and fire change

USAGE
  surf select-option "<css-selector>" "<value>"

RETURNS
  {"ok":true,"value":".."}  |  {"ok":false,"err":"not_select"}  |  {"ok":false,"err":"not_found"}

EXAMPLE
  surf select-option "select#country" "US"

SEE ALSO
  fill · submit
EOF
;;
    submit) cat <<'EOF'
surf submit — submit the form enclosing a selector

USAGE
  surf submit "<css-selector>"

RETURNS
  {"ok":true}  |  {"ok":false,"err":"no_form"}  |  {"ok":false,"err":"not_found"}

NOTES
  Resolves the form from a form element, .form, or closest('form'), then calls
  requestSubmit().

EXAMPLE
  surf submit "button#go"

SEE ALSO
  fill · select-option · click
EOF
;;
    scroll) cat <<'EOF'
surf scroll — scroll the target tab

USAGE
  surf scroll down|up|top|bottom [N]      N = viewport-heights (default 1)

EXAMPLE
  surf scroll down
  surf scroll down 3
  surf scroll top

SEE ALSO
  scroll-to
EOF
;;
    scroll-to) cat <<'EOF'
surf scroll-to — scroll an element into view (centered)

USAGE
  surf scroll-to "<css-selector>"

RETURNS
  {"ok":true}  |  {"ok":false,"err":"not_found"}

EXAMPLE
  surf scroll-to "#footer"

SEE ALSO
  scroll
EOF
;;
    press) cat <<'EOF'
surf press — synthesize a real key / chord via System Events

USAGE
  surf press "<key>"        a key, optionally preceded by +-joined modifiers

KEYS
  enter|return, tab, escape|esc, space, delete|backspace, up|down|left|right,
  or any single character (a, !, ...)

MODIFIERS
  cmd (=meta), ctrl, alt (=option), shift

RETURNS
  "pressed: <key>" on success.

NOTES
  Real synthesis — Enter submits, Escape closes, cmd+a selects all (unlike
  JS-dispatched events). Activates the target window first; cannot press keys on
  a background tab. Needs Accessibility for your terminal.

EXAMPLE
  surf press enter
  surf press tab
  surf press cmd+a
  surf press cmd+shift+c

SEE ALSO
  click · fill
EOF
;;
    wait) cat <<'EOF'
surf wait — poll until an element exists

USAGE
  surf wait "<css-selector>" [--timeout N]      N in seconds (default 15)

RETURNS
  "found: <sel>" (exit 0) as soon as the element exists; on timeout prints an
  error and exits 1.

EXAMPLE
  surf wait ".result" --timeout 20

SEE ALSO
  wait-url · wait-stable · exists
EOF
;;
    wait-url) cat <<'EOF'
surf wait-url — poll until the URL contains a substring

USAGE
  surf wait-url "<substring>" [--timeout N]      N in seconds (default 15)

RETURNS
  "ok: <url>" (exit 0) when location.href contains the substring; on timeout
  exits 1.

EXAMPLE
  surf wait-url "checkout/success" --timeout 30

SEE ALSO
  wait · wait-stable
EOF
;;
    wait-stable) cat <<'EOF'
surf wait-stable — poll until the DOM stops changing

USAGE
  surf wait-stable [--timeout N]      N in seconds (default 15)

RETURNS
  "stable: <N>ms" (exit 0) after a MutationObserver quiet window
  (SURF_STABLE_QUIET_MS, default 700); on timeout exits 1.

NOTES
  Keep the mutating tab in the FOREGROUND — Chrome throttles background-tab
  timers to ~1/sec, which can read as "quiet" and exit early.

EXAMPLE
  surf wait-stable --timeout 12

SEE ALSO
  wait · wait-url
EOF
;;
    exists) cat <<'EOF'
surf exists — exit 0 if an element is present

USAGE
  surf exists "<css-selector>" [--json]

RETURNS
  exit 0 if querySelector(sel) is non-null, else exit 1.
  With --json: {"selector":..,"exists":bool} (still exits 0/1).

EXAMPLE
  surf exists "#cookie-banner" && echo "present"

SEE ALSO
  visible · count · wait
EOF
;;
    visible) cat <<'EOF'
surf visible — exit 0 if an element is present AND visible

USAGE
  surf visible "<css-selector>" [--json]

RETURNS
  exit 0 if the element exists and is visible (display/visibility/opacity +
  offsetParent checks, fixed-position aware), else exit 1.
  With --json: {"selector":..,"visible":bool,"reason":"visible|hidden|absent"}.

EXAMPLE
  surf visible ".modal"

SEE ALSO
  exists · wait
EOF
;;
    assert) cat <<'EOF'
surf assert — assert a JS expression is truthy or equals an expected value

USAGE
  surf assert "<js>" [expected] [--json]

RETURNS
  With [expected]: exit 0 if String(<js>) == expected, else exit 1.
  Without:        exit 0 if <js> is truthy, else exit 1.
  With --json: {"js":..,"expected":..,"got":..,"pass":bool} (still exits 0/1).

EXAMPLE
  surf assert 'document.querySelectorAll(".result").length' '5'
  surf assert 'document.querySelector(".logged-in")'

SEE ALSO
  exists · visible · eval
EOF
;;
    shot) cat <<'EOF'
surf shot — screenshot the target window to a PNG

USAGE
  surf shot [<path>]      default ./surf-shot.png

NOTES
  Captures the window rectangle via screencapture; a background-tab target is
  activated first. Needs Screen Recording for your terminal.

EXAMPLE
  surf shot ~/page.png

SEE ALSO
  shot-el
EOF
;;
    shot-el) cat <<'EOF'
surf shot-el — screenshot a single element (cropped via sips)

USAGE
  surf shot-el "<css-selector>" [<path>]

NOTES
  Scrolls into view, reads getBoundingClientRect + devicePixelRatio, captures the
  window, and crops with sips. Best-effort positioning. Needs Screen Recording.

EXAMPLE
  surf shot-el ".chart" ~/chart.png

SEE ALSO
  shot
EOF
;;
    find-tab) cat <<'EOF'
surf find-tab — search open tabs by URL or title

USAGE
  surf find-tab "<query>" [--activate]

RETURNS
  Every match as:  wN.tN  URL  |  title   (exit 0). No match -> stderr + exit 1.
  --activate brings the first match's window to front and makes it the active tab.

EXAMPLE
  surf find-tab "github"
  surf find-tab "inbox" --activate

SEE ALSO
  tabs · select
EOF
;;
    bookmarks) cat <<'EOF'
surf bookmarks — read/search Chrome bookmarks (from the profile file)

USAGE
  surf bookmarks [query] [--profile NAME] [--json]

RETURNS
  One line per bookmark:  name  |  url   (all, or those matching query).
  --json -> [{"name","url"}, ...]. Defaults to "Default" profile.

NOTES
  Reads the Bookmarks file directly — no browser or JS toggle needed.

EXAMPLE
  surf bookmarks "ryanair"
  surf bookmarks --profile "Profile 1" --json
EOF
;;
    table) cat <<'EOF'
surf table — scrape an HTML <table> to JSON

USAGE
  surf table ["<css-selector>"]      default "table" (the first table)

RETURNS
  {"headers":[...] | null, "rows":[[...], ...], "truncated":bool}
  First row containing <th> is treated as headers; else headers is null.
  Cells are text trimmed; colspan/rowspan are NOT unfolded (v1). Rows capped at 1000.
  Missing table -> {"ok":false,"err":"not_found"}.

EXAMPLE
  surf table
  surf table "table.results" | jq '.rows'

SEE ALSO
  list · text · count
EOF
;;
    cookie) cat <<'EOF'
surf cookie — read cookies visible to JS (non-HttpOnly)

USAGE
  surf cookie [name] [--json]

RETURNS
  no name:   all readable cookies as "k=v; k2=v2"
  name:      that cookie's value, or NOT_FOUND
  --json:    {"k":"v", ...}

NOTES
  HttpOnly cookies (sessions, auth) are hidden from JS by design — use a CDP
  tool for those.

EXAMPLE
  surf cookie
  surf cookie session_id
EOF
;;
    localstorage) cat <<'EOF'
surf localstorage — read window.localStorage

USAGE
  surf localstorage [key]

RETURNS
  key:    that key's value, or NOT_FOUND
  no key: JSON object of all keys (each value capped at 2000 chars)

EXAMPLE
  surf localstorage theme
  surf localstorage
EOF
;;
    form) cat <<'EOF'
surf form — fill many fields in ONE browser call

USAGE
  surf form '<sel>=<val>' '<sel>=<val>' ...

RETURNS
  {"ok":N,"fail":N,"results":[{"sel","ok","tag"|"err"}, ...]}
  Each arg splits on the LAST '=' (so input[type=text]=x works).

EXAMPLE
  surf form '#user=alice' '#pass=secret' 'input[name=remember]=1'

SEE ALSO
  fill · select-option · submit
EOF
;;
    download) cat <<'EOF'
surf download — click a trigger and capture the downloaded file

USAGE
  surf download "<selector>" [--timeout N] [--dir DIR]

RETURNS
  "downloaded: /path/to/file" on success; exit 1 on timeout.

NOTES
  Watches DIR (default ~/Downloads) for a new file; Chrome writes <name>.crdownload
  mid-download and renames on finish. Times out if Chrome is set to "Ask where to
  save" (the dialog blocks). Env: SURF_DOWNLOAD_DIR, SURF_DOWNLOAD_TIMEOUT.

EXAMPLE
  surf download "a[href$='.pdf']"
  surf download "#export-btn" --timeout 60
EOF
;;
    shot-full) cat <<'EOF'
surf shot-full — full-page screenshot (scroll + stitch)

USAGE
  surf shot-full [<path>]      default ./surf-shot-full.png

NOTES
  Scrolls the page slice by slice, captures each viewport, stitches with Pillow.
  Needs Screen Recording. Caveats: lazy images may need longer to render;
  position:fixed/sticky elements repeat in each slice.

EXAMPLE
  surf shot-full ~/report.png

SEE ALSO
  shot · shot-el
EOF
;;
    batch) cat <<'EOF'
surf batch — run many ops in ONE browser call (reads + interactions)

USAGE
  surf batch            # reads a JSON steps array from stdin

RETURNS
  A JSON array of {"op":"..","v":..} — one entry per step. Each step is
  try/catch-wrapped, so one bad selector yields {"err":".."} without aborting
  the batch. "v" is exactly what the standalone op would print.

STEPS (stdin)
  [{"op":"title"},{"op":"count","sel":"a"},{"op":"text","sel":"h1"},
   {"op":"attr","sel":"a","name":"href"},{"op":"click","sel":"#go"},
   {"op":"fill","sel":"#q","val":"x"},{"op":"eval","js":"1+1"}]

SUPPORTED OPS
  title, url, text(sel), html(sel), attr(sel,name), count(sel), list(sel),
  exists(sel), visible(sel), click(sel), fill(sel,val), hover(sel), eval(js)

NOT BATCHABLE (different mechanism — use the standalone command)
  press, shot/shot-el, navigation (open/new/reload/back/fwd/close), wait*

EXAMPLE
  surf batch <<'EOF'
  [{"op":"title"},{"op":"count","sel":"a"},{"op":"text","sel":"h1"}]
  EOF

SEE ALSO
  eval · text · count
EOF
;;
    doctor) cat <<'EOF'
surf doctor — one-shot environment + permission diagnostic

USAGE
  surf doctor

RETURNS
  Prints a check list with results:
    macOS · Chrome running · JavaScript-from-AppleScript toggle ·
    Screen Recording · Accessibility
  Exit 0 if all green, 1 otherwise. Each failure prints the fix path.

NOTES
  The JS toggle is probed on a throwaway about:blank tab, so it is immune to the
  x.com / incognito / app-PWA false "turned off" error.

EXAMPLE
  surf doctor

SEE ALSO
  setup
EOF
;;
    setup) cat <<'EOF'
surf setup — one-time enable of Chrome JS-from-AppleScript

USAGE
  surf setup

NOTES
  Attempts to GUI-click View -> Developer -> Allow JavaScript from Apple Events,
  then verifies with a real JS call. Chromium menus often ignore scripted clicks;
  if it can't, follow the printed manual instruction (click it once by hand).
  Needs Accessibility for the GUI attempt; the manual click needs none.

SEE ALSO
  doctor
EOF
;;
    help) cat <<'EOF'
surf help — show help

USAGE
  surf help [command]        blank = categorized overview
  surf <command> --help      per-command detail (same as `surf help <command>`)

EXAMPLE
  surf help
  surf help batch
  surf click --help
EOF
;;
    --version) cat <<'EOF'
surf --version — print the version

USAGE
  surf --version
EOF
;;
    --selfcheck) cat <<'EOF'
surf --selfcheck — install info

USAGE
  surf --selfcheck

RETURNS
  Version, skill directory, and last auto-update time.
EOF
;;
    --update) cat <<'EOF'
surf --update — update the skill

USAGE
  surf --update

NOTES
  git pull --ff-only the skale-skills repo and refresh the update stamp.
EOF
;;
  esac
}

# ── dispatcher ──────────────────────────────────────────────────────
# blank arg -> overview; known command -> per-command; unknown -> stderr + rc 1.
cmd_help() {
  local cmd="${1-}"
  if [ -z "$cmd" ]; then _surf_help_overview; return 0; fi
  case "$cmd" in
    tabs|here|select|find-tab|open|new|reload|back|fwd|close|\
    title|url|text|html|attr|count|list|table|eval|cookie|localstorage|\
    click|fill|form|hover|select-option|submit|scroll|scroll-to|press|download|\
    wait|wait-url|wait-stable|\
    exists|visible|assert|\
    shot|shot-el|shot-full|\
    batch|bookmarks|doctor|setup|help|\
    --version|--selfcheck|--update)
      _surf_help_command "$cmd"; return 0 ;;
    *)
      echo "surf: no help for '$cmd'." >&2
      echo "Run 'surf help' for the command list." >&2
      return 1 ;;
  esac
}
