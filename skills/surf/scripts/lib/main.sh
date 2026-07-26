# surf/lib/main.sh — dispatch. Sourced by surf.sh (entry calls main "$@").
# Help text lives in lib/help.sh (cmd_help / _surf_help_overview / _surf_help_command).

main() {
  case "${1-}" in
    --version) echo "surf $VERSION"; exit 0 ;;
  esac

  # `surf <command> --help` / `-h` -> per-command help (before normal dispatch).
  if [ $# -ge 2 ]; then
    local _h
    for _h in "${@:2}"; do
      if [ "$_h" = "--help" ] || [ "$_h" = "-h" ]; then
        cmd_help "$1"; exit $?
      fi
    done
  fi

  local sub="${1-}"; [ "${1-}" ] && shift || true
  case "$sub" in
    tabs)   cmd_tabs "$@" ;;
    here)   cmd_here "$@" ;;
    select) cmd_select "$@" ;;
    find-tab) cmd_find_tab "$@" ;;
    bookmarks) cmd_bookmarks "$@" ;;
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
    cookie)  cmd_cookie "$@" ;;
    localstorage) cmd_localstorage "$@" ;;
    exists)  cmd_exists "$@" ;;
    visible) cmd_visible "$@" ;;
    assert)  cmd_assert "$@" ;;
    click)  cmd_click "$@" ;;
    fill)   cmd_fill "$@" ;;
    form)    cmd_form "$@" ;;
    eval)   cmd_eval "$@" ;;
    wait)   cmd_wait "$@" ;;
    wait-url) cmd_wait_url "$@" ;;
    wait-stable) cmd_wait_stable "$@" ;;
    scroll)      cmd_scroll "$@" ;;
    scroll-to)   cmd_scroll to "$@" ;;
    hover)       cmd_hover "$@" ;;
    select-option) cmd_select_option "$@" ;;
    submit)      cmd_submit "$@" ;;
    download)    cmd_download "$@" ;;
    press)       cmd_press "$@" ;;
    shot)        cmd_shot "$@" ;;
    shot-el)     cmd_shot_el "$@" ;;
    shot-full)   cmd_shot_full "$@" ;;
    setup)  cmd_setup ;;
    doctor) cmd_doctor ;;
    batch)  cmd_batch "$@" ;;
    ""|help|-h|--help) cmd_help "$@" ;;
    *) die "unknown command: $sub (try: surf help)" ;;
  esac
}
