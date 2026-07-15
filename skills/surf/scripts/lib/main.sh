# surf/lib/main.sh — usage + dispatch. Sourced by surf.sh (entry calls main "$@").

usage() {
  cat <<'EOF'
surf — drive your real Chrome (macOS, AppleScript). No daemon/port/extension/ack.

  surf tabs                       list windows → tabs (refs like w1.t3)
  surf here                       active/target tab: URL | title
  surf select [wN.tN | reset]     target a tab (op background tabs w/o focus); blank = show
  surf open <url>                 navigate target tab
  surf new [<url>]                new tab (front window)
  surf reload | back | fwd        target-tab controls
  surf close                      close target/active tab
  surf title | url                document.title / location.href
  surf text  "<sel>"              textContent of first match
  surf html  "<sel>"              outerHTML of first match
  surf attr  "<sel>" <name>       attribute value of first match
  surf count "<sel>"              number of matches
  surf list "<sel>"               JSON array of all matches' text (scrape lists)
  surf exists "<sel>"             exit 0 if present (else 1)
  surf visible "<sel>"            exit 0 if present & visible (else 1)
  surf assert "<js>" [expected]   exit 0 if JS truthy / == expected (else 1)
  surf click "<sel>"              click first match (scrolls into view)
  surf fill  "<sel>" "<val>"      set value + fire input/change
  surf eval  "<js>"               run JS in target tab, print result
  surf wait  "<sel>" [--timeout N] poll until element exists (exit 1 on timeout)
  surf wait-url "<sub>" [--timeout N]  poll until URL contains substring
  surf wait-stable [--timeout N]      poll until DOM stops changing
  surf scroll down|up|top|bottom [N]  scroll by N viewport-heights (default 1)
  surf scroll-to "<sel>"              scroll element into view (center)
  surf hover "<sel>"                  fire mouseover/mouseenter on first match
  surf select-option "<sel>" "<val>"  set a <select> value + fire change
  surf submit "<sel>"                 submit the enclosing form (requestSubmit)
  surf press "<key>"                 press a key/chord (enter, tab, escape, a, cmd+a) — real synthesis
  surf shot  [<path>]             screenshot the window (PNG)
  surf shot-el "<sel>" [<path>]  screenshot one element (crop via sips)
  surf batch                      run a JSON steps array in ONE call (stdin) — reads + interactions
  surf doctor                     check macOS/Chrome/JS-toggle/Screen-Recording/Accessibility
  surf setup                      one-time: enable Chrome JS-from-AppleScript
  surf --version | --selfcheck    version / install info
  surf help                       this message

Selectors are CSS. tabs/here/text/count accept --json. One-time setup: `surf setup` (or View → Developer → Allow JavaScript from Apple Events).
EOF
}

main() {
  case "${1-}" in
    --version) echo "surf $VERSION"; exit 0 ;;
  esac
  local sub="${1-}"; [ "${1-}" ] && shift || true
  case "$sub" in
    tabs)   cmd_tabs "$@" ;;
    here)   cmd_here "$@" ;;
    select) cmd_select "$@" ;;
    open)   cmd_open "$@" ;;
    new)    cmd_new "$@" ;;
    reload|refresh) cmd_reload ;;
    back)   cmd_back ;;
    fwd|forward)    cmd_fwd ;;
    close)  cmd_close ;;
    title)  cmd_title ;;
    url)    cmd_url ;;
    text)   cmd_text "$@" ;;
    html)   cmd_html "$@" ;;
    attr)   cmd_attr "$@" ;;
    count)  cmd_count "$@" ;;
    list)   cmd_list "$@" ;;
    exists)  cmd_exists "$@" ;;
    visible) cmd_visible "$@" ;;
    assert)  cmd_assert "$@" ;;
    click)  cmd_click "$@" ;;
    fill)   cmd_fill "$@" ;;
    eval)   cmd_eval "$@" ;;
    wait)   cmd_wait "$@" ;;
    wait-url) cmd_wait_url "$@" ;;
    wait-stable) cmd_wait_stable "$@" ;;
    scroll)      cmd_scroll "$@" ;;
    scroll-to)   cmd_scroll to "$@" ;;
    hover)       cmd_hover "$@" ;;
    select-option) cmd_select_option "$@" ;;
    submit)      cmd_submit "$@" ;;
    press)       cmd_press "$@" ;;
    shot)        cmd_shot "$@" ;;
    shot-el)     cmd_shot_el "$@" ;;
    setup)  cmd_setup ;;
    doctor) cmd_doctor ;;
    batch)  cmd_batch "$@" ;;
    ""|help|-h|--help) usage ;;
    *) die "unknown command: $sub (try: surf help)" ;;
  esac
}
