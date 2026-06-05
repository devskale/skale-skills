#!/usr/bin/env bash
# ============================================================
# rodney vs agent-browser — Performance & Resource Benchmark v2
# Fixed: macOS ps compatibility, click targets
# ============================================================
set -uo pipefail

URL="https://example.com"
ITERATIONS=3

timestamp() { date +%s%N 2>/dev/null || date +%s; }
ms_diff() { echo "$(( ($2 - $1) / 1000000 ))"; }

# ── RSS: works on macOS (ps -o rss) and Linux ────────────
get_rss_kb() {
  # Sum RSS in KB for all matching processes
  local pat="$1"
  if [[ "$(uname)" == "Darwin" ]]; then
    # macOS: ps -o pid,rss,comm
    ps -eo rss=,comm= 2>/dev/null | awk -v p="$pat" 'tolower($0) ~ tolower(p) && $1+0>0 {sum+=$1} END {printf "%.0f\n", sum+0}'
  else
    # Linux: same format
    ps -eo rss=,comm= 2>/dev/null | awk -v p="$pat" 'tolower($0) ~ tolower(p) {sum+=$1} END {print sum+0}'
  fi
}

count_procs() {
  local pat="$1"
  ps -eo comm= 2>/dev/null | grep -ci "$pat" 2>/dev/null || echo 0
}

get_rss_detail() {
  echo "--- Process memory detail ---"
  if [[ "$(uname)" == "Darwin" ]]; then
    ps -eo pid,rss,comm -r 2>/dev/null | head -20
  else
    ps -eo pid,rss,comm --sort=-rss 2>/dev/null | head -20
  fi
}

avg() {
  local arr=("$@") sum=0 n=${#arr[@]}
  [ "$n" -eq 0 ] && echo 0 && return
  for v in "${arr[@]}"; do sum=$((sum + v)); done
  echo $(( sum / n ))
}
winner() {
  local a="$1" b="$2" an="$3" bn="$4"
  [ "$a" -le "$b" ] 2>/dev/null && echo "$an ✅" || echo "$bn ✅"
}

echo "═══════════════════════════════════════════════════════"
echo "  BROWSER BENCHMARK v2: rodney vs agent-browser"
echo "═══════════════════════════════════════════════════════"
echo "  URL:        $URL  |  Iters: $ITERATIONS  |  $(date)"
echo "  OS:         $(uname -srm)  |  CPUs: $(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null)"
echo "  Rodney:     $(rodney --version 2>/dev/null)  |  Agent-Br: $(agent-browser --version 2>/dev/null)"
echo "═══════════════════════════════════════════════════════"

cleanup() { rodney stop 2>/dev/null; agent-browser close 2>/dev/null; sleep 1; }
trap cleanup EXIT

# ══════════════════════════════════════════════════════════
#  TEST A: RODNEY
# ══════════════════════════════════════════════════════════
echo ""; echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  TEST A: RODNEY (Python/rod → CDP → Chrome)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

R_START=() R_NAV=() R_TEXT=() R_CLICK=() R_STOP=()
R_RSS_START=() R_RSS_NAV=() R_RSS_POST=()

for i in $(seq 1 $ITERATIONS); do
  echo ""; echo "  ── Iteration $i/$ITERATIONS ──"

  # Baseline (no chrome)
  BASE=$(get_rss_kb "chrom")

  # START
  T1=$(timestamp); rodney start 2>&1; T2=$(timestamp)
  ms=$(ms_diff T1 T2); R_START+=("$ms")
  RS=$(get_rss_kb "chrom"); R_RSS_START+=("$RS")
  echo "    start:   ${ms}ms    RAM: ${RS} KB"

  # NAV
  T1=$(timestamp); rodney open "$URL" 2>&1; T2=$(timestamp)
  ms=$(ms_diff T1 T2); R_NAV+=("$ms")
  RS=$(get_rss_kb "chrom"); R_RSS_NAV+=("$RS")
  echo "    nav:     ${ms}ms    RAM: ${RS} KB"

  # WAIT STABLE
  rodney waitstable >/dev/null 2>&1

  # TEXT EXTRACT
  T1=$(timestamp); rodney text "body" 2>&1 | wc -c | tr -d ' '; T2=$(timestamp)  # just measure time
  # redo for timing without pipe overhead
  T1=$(timestamp); OUT=$(rodney text "body" 2>&1); T2=$(timestamp)
  ms=$(ms_diff T1 T2); R_TEXT+=("$ms")
  echo "    text:    ${ms}ms    (${#OUT} chars extracted)"

  # CLICK (target a link or button)
  T1=$(timestamp)
  if rodney exists "a" 2>/dev/null; then rodney click "a" 2>&1 >/dev/null
  elif rodney exists "button" 2>/dev/null; then rodney click "button" 2>&1 >/dev/null
  else rodney click "h1" 2>&1 >/dev/null; fi
  T2=$(timestamp)
  ms=$(ms_diff T1 T2); R_CLICK+=("$ms")
  echo "    click:   ${ms}ms"

  RS=$(get_rss_kb "chrom"); R_RSS_POST+=("$RS")
  echo "    RAM end: ${RS} KB"

  # STOP
  T1=$(timestamp); rodney stop 2>&1; T2=$(timestamp)
  ms=$(ms_diff T1 T2); R_STOP+=("$ms")
  echo "    stop:    ${ms}ms"

  sleep 1
done

# ══════════════════════════════════════════════════════════
#  TEST B: AGENT-BROWSER
# ══════════════════════════════════════════════════════════
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  TEST B: AGENT-BROWSER (Rust daemon + Chromium)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

AB_OPEN=() AB_SNAP=() AB_CLICK=() AB_CLOSE=()
AB_RSS_OPEN=() AB_RSS_POST=()

for i in $(seq 1 $ITERATIONS); do
  echo ""; echo "  ── Iteration $i/$ITERATIONS ──"

  BASE=$(get_rss_kb "chrom")

  # OPEN
  T1=$(timestamp); agent-browser open "$URL" 2>&1; T2=$(timestamp)
  ms=$(ms_diff T1 T2); AB_OPEN+=("$ms")
  RS=$(get_rss_kb "chrom"); AB_RSS_OPEN+=("$RS")
  echo "    open:    ${ms}ms    RAM: ${RS} KB"

  # SNAPSHOT
  T1=$(timestamp); SNAP=$(agent-browser snapshot 2>&1); T2=$(timestamp)
  ms=$(ms_diff T1 T2); AB_SNAP+=("$ms")
  echo "$SNAP" | head -15
  echo "    snapshot:${ms}ms    (${#SNAP} chars)"

  # CLICK — target a link (ref=e2 on example.com), not heading
  T1=$(timestamp)
  # Find a link/button ref from snapshot
  REF=$(echo "$SNAP" | grep -E '(link|button)' | grep -oE 'ref=e[0-9]+' | head -1 | sed 's/ref=/@/' || echo "@e2")
  agent-browser click --ref "$REF" 2>&1 >/dev/null
  T2=$(timestamp)
  ms=$(ms_diff T1 T2); AB_CLICK+=("$ms")
  echo "    click ($REF):${ms}ms"

  RS=$(get_rss_kb "chrom"); AB_RSS_POST+=("$RS")
  echo "    RAM end: ${RS} KB"

  # CLOSE
  T1=$(timestamp); agent-browser close 2>&1; T2=$(timestamp)
  ms=$(ms_diff T1 T2); AB_CLOSE+=("$ms")
  echo "    close:   ${ms}ms"

  sleep 1
done

# ══════════════════════════════════════════════════════════
#  RESULTS
# ══════════════════════════════════════════════════════════
echo ""
echo "═══════════════════════════════════════════════════════"
echo "  RESULTS (avg of $ITERATIONS iterations)"
echo "═══════════════════════════════════════════════════════"

R_S_AVG=$(avg "${R_START[@]}");    R_N_AVG=$(avg "${R_NAV[@]}")
R_T_AVG=$(avg "${R_TEXT[@]}");     R_C_AVG=$(avg "${R_CLICK[@]}")
R_ST_AVG=$(avg "${R_STOP[@]}");    R_RS_NAV=$(avg "${R_RSS_NAV[@]}")
AB_O_AVG=$(avg "${AB_OPEN[@]}");   AB_SN_AVG=$(avg "${AB_SNAP[@]}")
AB_CK_AVG=$(avg "${AB_CLICK[@]}"); AB_CL_AVG=$(avg "${AB_CLOSE[@]}")
AB_RS_OP=$(avg "${AB_RSS_OPEN[@]}")

printf '\n%-34s %9s %10s  %s\n' "METRIC" "rodney" "agnt-br" "WINNER"
printf '%-34s %9s %10s  %s\n' "─────────────────────────────────" "─────────" "──────────" "───────"

printf '%-34s %7s ms %7s ms  %s\n' "Cold start / open" "$R_S_AVG" "$AB_O_AVG" \
  "$(winner "$R_S_AVG" "$AB_O_AVG" "rodney" "ab")"

printf '%-34s %7s ms %7s ms  %s\n' "Navigate to page" "$R_N_AVG" "$AB_O_AVG" \
  "$(winner "$R_N_AVG" "$AB_O_AVG" "rodney" "ab")"

printf '%-34s %7s ms %7s ms  %s\n' "Page read (text/snapshot)" "$R_T_AVG" "$AB_SN_AVG" \
  "$(winner "$R_T_AVG" "$AB_SN_AVG" "rodney" "ab")"

printf '%-34s %7s ms %7s ms  %s\n' "Click element" "$R_C_AVG" "$AB_CK_AVG" \
  "$(winner "$R_C_AVG" "$AB_CK_AVG" "rodney" "ab")"

printf '%-34s %7s ms %7s ms  %s\n' "Stop / close" "$R_ST_AVG" "$AB_CL_AVG" \
  "$(winner "$R_ST_AVG" "$AB_CL_AVG" "rodney" "ab")"

R_TOT=$((R_S_AVG + R_N_AVG + R_T_AVG + R_C_AVG + R_ST_AVG))
AB_TOT=$((AB_O_AVG + AB_SN_AVG + AB_CK_AVG + AB_CL_AVG))
printf '%-34s %7s ms %7s ms  %s\n' "TOTAL workflow" "$R_TOT" "$AB_TOT" \
  "$(winner "$R_TOT" "$AB_TOT" "rodney" "ab")"

echo ""

printf '%-34s %8s KB %8s KB  %s\n' "RAM after navigate" "$R_RS_NAV" "$AB_RS_OP" \
  "$(winner "$R_RS_NAV" "$AB_RS_OP" "rodney" "ab")"

KB_TO_MB() { echo "$(echo "scale=1; $1 / 1024" | bc 2>/dev/null || echo '?') MB"; }
echo ""
echo "  (RAM in MB: rodney ≈ $(KB_TO_MB $R_RS_NAV) | agent-browser ≈ $(KB_TO_MB $AB_RS_OP))"

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  RAW DATA"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "rodney:"
echo "  start:${R_START[*]} ms  nav:${R_NAV[*]} ms  text:${R_TEXT[*]} ms  click:${R_CLICK[*]} ms  stop:${R_STOP[*]} ms"
echo "  rss_nav: ${R_RSS_NAV[*]} KB  rss_post: ${R_RSS_POST[*]} KB"
echo ""
echo "agent-browser:"
echo "  open:${AB_OPEN[*]} ms  snap:${AB_SNAP[*]} ms  click:${AB_CLICK[*]} ms  close:${AB_CLOSE[*]} ms"
echo "  rss_open:${AB_RSS_OPEN[*]} KB  rss_post:${AB_RSS_POST[*]} KB"
echo ""
echo "═══════════════════════════════════════════════════════"
echo "  TOP PROCESSES DURING LAST RUN (for reference):"
get_rss_detail
echo "═══════════════════════════════════════════════════════"
echo "  DONE  $(date)"
echo "═══════════════════════════════════════════════════════"
