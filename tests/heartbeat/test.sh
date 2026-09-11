#!/usr/bin/env bash
# heartbeat extension test suite
#   bash tests/heartbeat/test.sh
# The extension's parser/format helpers live in extensions/lib/heartbeat-parse.ts
# (pure functions, zero imports) — unit-tested here via node's native TS type
# stripping, no pi runtime needed. Structure + lint gate + registration
# surface are checked statically.
set -uo pipefail
cd "$(dirname "$0")/../.."

EXT=extensions/heartbeat.ts
LIB=extensions/lib/heartbeat-parse.ts
PASS=0; FAIL=0; WARN=0

ok()   { PASS=$((PASS+1)); }
bad()  { FAIL=$((FAIL+1)); echo "  FAIL: $1" >&2; }
warn() { WARN=$((WARN+1)); echo "  WARN (skipped honestly): $1" >&2; }

echo "heartbeat extension tests"
echo "-------------------------"

# structure
[ -f "$EXT" ] && ok || bad "heartbeat.ts missing"
[ -f extensions/heartbeat.md ] && ok || bad "heartbeat.md missing"
[ -f "$LIB" ] && ok || bad "lib/heartbeat-parse.ts missing"
[ -x scripts/lint.sh ] && ok || bad "scripts/lint.sh missing"

# lib is dependency-free (tests run it without the pi runtime)
grep -q "^import\|^} from\|require(" "$LIB" && bad "heartbeat-parse.ts must stay import-free" || ok

# lint/typecheck gate (extensions/)
if bash scripts/lint.sh >/tmp/hb-lint.log 2>&1; then ok; else bad "lint.sh failed ($(tail -1 /tmp/hb-lint.log))"; fi

# registration surface
grep -q 'registerCommand("heartbeat"' "$EXT" && ok || bad "slash command not registered"
grep -q "registerTool(heartbeatTool)" "$EXT" && ok || bad "agent tool not registered"
grep -q "promptGuidelines" "$EXT" && ok || bad "promptGuidelines missing"
grep -q "deliverAs: \"followUp\"" "$EXT" && ok || bad "reminders must use followUp delivery"

# once-semantics wired end to end
grep -q "state.once" "$EXT" && ok || bad "state.once missing"
grep -q "One-shot delivered" "$EXT" && ok || bad "one-shot finish message missing"
grep -q "oneShotTimerId" "$EXT" && ok || bad "one-shot timer missing"

# stale-ctx guards + busy escape
grep -q "isStaleCtxError" "$EXT" && ok || bad "stale-ctx guard missing"
grep -q "BUSY_STUCK_MS" "$EXT" && ok || bad "busy-stuck escape missing"

# parser unit tests via node type stripping (node ≥ 22.6)
if command -v node >/dev/null 2>&1; then
  NODE_MAJOR=$(node -p "process.versions.node.split('.')[0]")
  if [ "$NODE_MAJOR" -ge 23 ] || { [ "$NODE_MAJOR" -eq 22 ] && node --experimental-strip-types /dev/null >/dev/null 2>&1; }; then
    STRIP=""; [ "$NODE_MAJOR" -eq 22 ] && STRIP="--experimental-strip-types"
    cat > /tmp/hb-parse.test.ts <<'EOF'
import assert from "node:assert";
import { parseDuration, humanDuration, parseCommand } from "./EXT_REL/lib/heartbeat-parse.ts";

// parseDuration
assert.equal(parseDuration("30"), 30_000);
assert.equal(parseDuration("30s"), 30_000);
assert.equal(parseDuration("5m"), 300_000);
assert.equal(parseDuration("2h"), 7_200_000);
assert.equal(parseDuration("1d"), 86_400_000);
assert.equal(parseDuration("90s"), 90_000);
assert.equal(parseDuration("0s"), null, "zero interval is invalid");
assert.equal(parseDuration("-5"), null);
assert.equal(parseDuration("abc"), null);
assert.equal(parseDuration("5x"), null);

// humanDuration
assert.equal(humanDuration(30_000), "30s");
assert.equal(humanDuration(90_000), "1m 30s");
assert.equal(humanDuration(3_600_000), "1h");
assert.equal(humanDuration(86_400_000), "1d");
assert.equal(humanDuration(90_061_000), "1d 1h 1m 1s");
assert.equal(humanDuration(0), "0s");

// parseCommand — subcommands
assert.deepEqual(parseCommand(""), { action: "help" });
assert.deepEqual(parseCommand("help"), { action: "help" });
assert.deepEqual(parseCommand("?"), { action: "help" });
assert.deepEqual(parseCommand("status"), { action: "status" });
assert.deepEqual(parseCommand("off"), { action: "stop" });
assert.deepEqual(parseCommand("stop"), { action: "stop" });
assert.deepEqual(parseCommand("pause"), { action: "pause" });
assert.deepEqual(parseCommand("resume"), { action: "resume" });
assert.deepEqual(parseCommand("message"), { action: "message" });
assert.deepEqual(parseCommand('message "Focus on X"'), { action: "message", message: "Focus on X" });
assert.deepEqual(parseCommand("time"), { action: "time" });
assert.deepEqual(parseCommand("time 5m"), { action: "time", duration: "5m" });

// parseCommand — start variants
assert.deepEqual(parseCommand("30s"), { action: "start", duration: "30s" });
const start1 = parseCommand('5m "Focus on X" --limit 3');
assert.equal(start1.action, "start");
assert.equal(start1.duration, "5m");
assert.equal(start1.message, "Focus on X");
assert.equal(start1.maxCount, 3);
const start2 = parseCommand("--once 10s");
assert.equal(start2.once, true);
assert.equal(start2.duration, "10s");
const start3 = parseCommand("-f /tmp/x.md --lines 4");
assert.equal(start3.file, "/tmp/x.md");
assert.equal(start3.lines, 4);
const start4 = parseCommand("--limit 5"); // no duration → default interval
assert.equal(start4.action, "start");
assert.equal(start4.maxCount, 5);
assert.equal(start4.duration, undefined);

console.log("parser unit tests passed");
EOF
    sed -i '' "s|./EXT_REL|$(pwd)/extensions|" /tmp/hb-parse.test.ts 2>/dev/null || sed -i "s|./EXT_REL|$(pwd)/extensions|" /tmp/hb-parse.test.ts
    if node $STRIP /tmp/hb-parse.test.ts >/tmp/hb-unit.log 2>&1; then
      ok
      grep -q "parser unit tests passed" /tmp/hb-unit.log && ok || bad "unit test output unexpected"
    else
      bad "parser unit tests failed: $(tail -3 /tmp/hb-unit.log)"
    fi
    rm -f /tmp/hb-parse.test.ts
  else
    warn "parser unit tests skipped (node < 22.6, no type stripping)"
  fi
else
  warn "parser unit tests skipped (node not found)"
fi

# smoke: extension loads in pi is a live check — skipped here, covered by pi itself
warn "live load in pi not exercised (interactive)"

echo
echo "PASS=$PASS FAIL=$FAIL WARN=$WARN"
[ "$FAIL" -eq 0 ]
