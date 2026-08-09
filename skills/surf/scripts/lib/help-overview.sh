# surf/lib/help-overview.sh — the categorized help OVERVIEW (index). Sourced by surf.sh.
# Split from help.sh (Q2-B): the overview is its own concern, separate from the
# per-command detail blocks in help-command.sh.
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
