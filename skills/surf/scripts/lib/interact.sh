# surf/lib/interact.sh — click/fill/hover/select-option/submit/scroll/press. Sourced by surf.sh.

cmd_click() { [ "${1-}" ] || die "click needs a selector"
  run_js "$(printf '(function(){var e=document.querySelector(%s);if(!e)return JSON.stringify({ok:false,err:"not_found"});try{e.scrollIntoView({block:"center"})}catch(x){}e.click();return JSON.stringify({ok:true,tag:e.tagName})})()' "$(js_str "$1")")"; }
cmd_fill()  { [ "${1-}" ] && [ "${2-}" ] || die "fill needs <selector> <value>"
  run_js "$(printf '(function(){var e=document.querySelector(%s);if(!e)return JSON.stringify({ok:false,err:"not_found"});e.focus();e.value=%s;e.dispatchEvent(new Event("input",{bubbles:true}));e.dispatchEvent(new Event("change",{bubbles:true}));return JSON.stringify({ok:true,tag:e.tagName})})()' "$(js_str "$1")" "$(js_str "$2")")"; }

cmd_hover() {
  [ "${1-}" ] || die "hover needs a selector"
  run_js "$(printf '(function(){var e=document.querySelector(%s);if(!e)return JSON.stringify({ok:false,err:"not_found"});try{e.scrollIntoView({block:"center"})}catch(x){}e.dispatchEvent(new MouseEvent("mouseover",{bubbles:true}));e.dispatchEvent(new MouseEvent("mousemove",{bubbles:true}));e.dispatchEvent(new MouseEvent("mouseenter",{bubbles:true}));return JSON.stringify({ok:true,tag:e.tagName})})()' "$(js_str "$1")")"
}

cmd_select_option() {
  [ "${1-}" ] && [ "${2-}" ] || die "select-option needs <selector> <value>"
  run_js "$(printf '(function(){var e=document.querySelector(%s);if(!e)return JSON.stringify({ok:false,err:"not_found"});if(e.tagName!=="SELECT")return JSON.stringify({ok:false,err:"not_select",tag:e.tagName});e.value=%s;e.dispatchEvent(new Event("input",{bubbles:true}));e.dispatchEvent(new Event("change",{bubbles:true}));return JSON.stringify({ok:true,value:e.value})})()' "$(js_str "$1")" "$(js_str "$2")")"
}

cmd_submit() {
  [ "${1-}" ] || die "submit needs a selector (a form, or an element inside a form)"
  run_js "$(printf '(function(){var e=document.querySelector(%s);if(!e)return JSON.stringify({ok:false,err:"not_found"});var f=(e.tagName==="FORM")?e:(e.form||e.closest("form"));if(!f)return JSON.stringify({ok:false,err:"no_form"});if(typeof f.requestSubmit==="function"){f.requestSubmit()}else{f.submit()}return JSON.stringify({ok:true})})()' "$(js_str "$1")")"
}

cmd_scroll() {
  local dir="${1-}" n="${2-1}" sel js
  [ -n "$dir" ] || die "scroll needs: down|up|top|bottom [N]  or  to \"<sel>\""
  case "$dir" in
    down)   [[ "$n" =~ ^[0-9]+$ ]] || n=1; js="window.scrollBy(0, window.innerHeight*$n); 'ok'" ;;
    up)     [[ "$n" =~ ^[0-9]+$ ]] || n=1; js="window.scrollBy(0, -window.innerHeight*$n); 'ok'" ;;
    top)    js="window.scrollTo(0, 0); 'ok'" ;;
    bottom) js="window.scrollTo(0, document.documentElement.scrollHeight); 'ok'" ;;
    to)     sel="${2-}"; [ -n "$sel" ] || die "scroll to needs a selector"
            js="$(printf '(function(){var e=document.querySelector(%s);if(!e)return JSON.stringify({ok:false,err:"not_found"});e.scrollIntoView({block:"center",behavior:"instant"});return JSON.stringify({ok:true})})()' "$(js_str "$sel")")" ;;
    *) die "scroll: unknown '$dir'. Use down|up|top|bottom [N] or to \"<sel>\"" ;;
  esac
  run_js "$js"
}

cmd_press() {
  [ "${1-}" ] || die "press needs a key/chord (e.g. enter, tab, escape, a, cmd+a, shift+arrowright)"
  local input="$1" tgt W T key mods kl keycode="" ks="" modlist="" using="" m ma err
  tgt="$(get_target)"; W=1
  if [ "$tgt" != "front" ]; then W="$(echo "$tgt"|cut -d' ' -f1)"; T="$(echo "$tgt"|cut -d' ' -f2)"; fi
  osascript >/dev/null 2>&1 <<APPLESCRIPT
tell application "$APP"
  set index of window $W to 1
$( [ -n "$T" ] && echo "  set active tab index of window $W to $T" )
  activate
end tell
APPLESCRIPT
  sleep 0.25
  key="${input##*+}"
  if [ "$key" = "$input" ]; then mods=""; else mods="${input%+*}"; fi
  kl="$(printf '%s' "$key" | tr 'A-Z' 'a-z')"
  case "$kl" in
    enter|return) keycode=36 ;; tab) keycode=48 ;; esc|escape) keycode=53 ;;
    space) ks=" " ;; delete|backspace) keycode=51 ;;
    up) keycode=126 ;; down) keycode=125 ;; left) keycode=123 ;; right) keycode=124 ;;
    *) ks="$key" ;;
  esac
  if [ -n "$mods" ]; then
    IFS='+' read -ra ma <<< "$mods"
    for m in "${ma[@]}"; do
      case "$(printf '%s' "$m" | tr 'A-Z' 'a-z')" in
        cmd|command|meta) modlist="${modlist:+$modlist, }command down" ;;
        ctrl|control) modlist="${modlist:+$modlist, }control down" ;;
        alt|option) modlist="${modlist:+$modlist, }option down" ;;
        shift) modlist="${modlist:+$modlist, }shift down" ;;
      esac
    done
  fi
  [ -n "$modlist" ] && using=" using {$modlist}"
  ks="${ks//\\/\\\\}"; ks="${ks//\"/\\\"}"
  if [ -n "$keycode" ]; then
    err=$(osascript -e "tell application \"System Events\" to key code $keycode$using" 2>&1 || true)
  else
    err=$(osascript -e "tell application \"System Events\" to keystroke \"$ks\"$using" 2>&1 || true)
  fi
  if [ -n "$err" ]; then
    if echo "$err" | grep -qi "assistive access"; then
      echo "surf: press needs Accessibility for your terminal (System Events keystroke)." >&2
      open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" 2>/dev/null || true
      echo "   → Enable Ghostty/terminal in Privacy & Security → Accessibility, then re-run." >&2
    else
      echo "surf: press failed: $err" >&2
    fi
    return 1
  fi
  echo "pressed: $input"
}
