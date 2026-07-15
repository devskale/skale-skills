# surf/lib/shot.sh — shot / shot-el. Sourced by surf.sh.

cmd_shot() {
  local out="${1:-./surf-shot.png}" tgt W T bounds x1 y1 x2 y2 w h err rc
  tgt="$(get_target)"
  if [ "$tgt" = "front" ]; then W=1; else W=$(echo "$tgt"|cut -d' ' -f1); T=$(echo "$tgt"|cut -d' ' -f2)
    osascript -e "tell application \"$APP\" to set active tab index of window $W to $T" >/dev/null 2>&1 || true
  fi
  osascript -e "tell application \"$APP\" to set index of window $W to 1" >/dev/null 2>&1 || true  # bring window to front
  sleep 0.2
  bounds="$(osascript -e "tell application \"$APP\" to get bounds of window 1" 2>&1)"
  # bounds may contain negative values when the window is partly off-screen.
  if ! echo "$bounds" | grep -qE '^[ -]?[0-9]+,[[:space:]]*[ -]?[0-9]+'; then die "could not read window bounds: $bounds"; fi
  x1=$(echo "$bounds"|awk -F', ' '{print $1}'); y1=$(echo "$bounds"|awk -F', ' '{print $2}')
  x2=$(echo "$bounds"|awk -F', ' '{print $3}'); y2=$(echo "$bounds"|awk -F', ' '{print $4}')
  # screencapture -R rejects a negative origin and ignores off-screen edges,
  # so clamp the rect to the desktop bounds (Finder reports {0,0,W,H}).
  db="$(osascript -e 'tell application "Finder" to get bounds of window of desktop' 2>/dev/null || true)"
  dx2=$(echo "$db"|awk -F', ' '{print $3}'); dy2=$(echo "$db"|awk -F', ' '{print $4}')
  if [ "${x1:-0}" -lt 0 ] 2>/dev/null; then x1=0; fi
  if [ "${y1:-0}" -lt 0 ] 2>/dev/null; then y1=0; fi
  if [ -n "${dx2:-}" ] && [ "${x2:-0}" -gt "${dx2:-0}" ] 2>/dev/null; then x2="$dx2"; fi
  if [ -n "${dy2:-}" ] && [ "${y2:-0}" -gt "${dy2:-0}" ] 2>/dev/null; then y2="$dy2"; fi
  w=$((x2 - x1)); h=$((y2 - y1))
  if [ "${w:-0}" -le 0 ] || [ "${h:-0}" -le 0 ]; then die "window has no on-screen area (bounds: $bounds)"; fi
  err=$(screencapture -R "$x1,$y1,$w,$h" -o -x "$out" 2>&1); rc=$?
  if [ $rc -ne 0 ]; then
    echo "surf: screencapture failed ($err)" >&2
    if echo "$err" | grep -qi "could not create image"; then
      echo "   → macOS needs Screen Recording permission for your terminal." >&2
      open "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture" 2>/dev/null || true
      echo "   → Enable Ghostty in System Settings → Privacy & Security → Screen Recording, then re-run." >&2
    fi
    return 1
  fi
  echo "shot → $out (${w}x${h})"
}

cmd_shot_el() {
  [ "${1-}" ] || die "shot-el needs a selector"
  local sel="$1" out="${2:-./surf-shot.png}" r parsed tmp x y w h
  r="$(run_js "$(printf '(function(){var e=document.querySelector(%s);if(!e)return JSON.stringify({ok:false,err:"not_found"});e.scrollIntoView({block:"center",behavior:"instant"});var r=e.getBoundingClientRect();var d=window.devicePixelRatio||1;return JSON.stringify({ok:true,x:Math.round(r.left*d),y:Math.round(r.top*d),w:Math.round(r.width*d),h:Math.round(r.height*d),chrome:Math.round((window.outerHeight-window.innerHeight)*d)})})()' "$(js_str "$sel")")")"
  echo "$r" | grep -q '"ok":true' || { echo "$r" >&2; return 1; }
  parsed="$(printf '%s' "$r" | python3 -c 'import sys,json;d=json.loads(sys.stdin.read());print(d["x"],d["y"]+d["chrome"],d["w"],d["h"])')"
  set -- $parsed; x=$1; y=$2; w=$3; h=$4
  [ "${w:-0}" -gt 0 ] 2>/dev/null && [ "${h:-0}" -gt 0 ] 2>/dev/null || { echo "surf: shot-el bad rect ($parsed)" >&2; return 1; }
  tmp="$(mktemp -t surf).png"
  cmd_shot "$tmp" >/dev/null 2>&1 || { echo "surf: window capture failed" >&2; rm -f "$tmp"; return 1; }
  if sips -c "$h" "$w" --cropOffset "$y" "$x" "$tmp" --out "$out" >/dev/null 2>&1; then
    echo "shot-el -> $out (~${w}x${h})"
  else
    echo "surf: sips crop failed" >&2; rm -f "$tmp"; return 1
  fi
  rm -f "$tmp"
}
