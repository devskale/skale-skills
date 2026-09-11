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

# registration surface (wiring lives in heartbeat.ts)
grep -q 'registerCommand("heartbeat"' "$EXT" && ok || bad "slash command not registered"
grep -q "registerTool(heartbeatTool)" "$EXT" && ok || bad "agent tool not registered"
grep -q "promptGuidelines" "$EXT" && ok || bad "promptGuidelines missing"
grep -q "parseCommand" "$EXT" && ok || bad "command parser not wired"

# logic markers (live in the core lib since the wiring/core split)
CORE=extensions/lib/heartbeat-core.ts
[ -f "$CORE" ] && ok || bad "heartbeat-core.ts missing"
grep -q 'deliverAs: "followUp"' "$CORE" && ok || bad "reminders must use followUp delivery"
grep -q "state.once" "$CORE" && ok || bad "state.once missing"
grep -q "One-shot delivered" "$CORE" && ok || bad "one-shot finish message missing"
grep -q "oneShotTimerId" "$CORE" && ok || bad "one-shot timer missing"
grep -q "isStaleCtxError" "$CORE" && ok || bad "stale-ctx guard missing"
grep -q "BUSY_STUCK_MS" "$CORE" && ok || bad "busy-stuck escape missing"

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

# control-flow tests: override / once / pause-resume / busy-shift / stuck-busy
# The core is compiled to CJS with the cached tsc and driven against a mocked
# host + ctx — the same code pi runs, no pi process needed.
TSC_BIN="$HOME/.cache/skale-skills/lint/node_modules/.bin/tsc"
if [ ! -x "$TSC_BIN" ]; then
    warn "control-flow tests skipped (cached tsc not found — run scripts/lint.sh once)"
else
    HBC=/tmp/hb-core; rm -rf "$HBC"; mkdir -p "$HBC"
    ( cd extensions/lib && "$TSC_BIN" heartbeat-core.ts heartbeat-parse.ts session-state.ts \
        --outDir "$HBC" --module commonjs --target es2022 --skipLibCheck --noResolve \
        ) >/tmp/hb-tsc.log 2>&1
    if [ ! -f "$HBC/heartbeat-core.js" ]; then
        warn "control-flow tests skipped (tsc emit failed: $(tail -1 /tmp/hb-tsc.log))"
    else
        cat > "$HBC/run.js" <<'EOF'
const core = require("./heartbeat-core.js");
let pass = 0, fail = 0;
const eq = (got, want, msg) => {
    if (got === want) pass++;
    else { fail++; console.log(`  FAIL: ${msg} (want ${JSON.stringify(want)}, got ${JSON.stringify(got)})`); }
};
const mocks = () => ({
    host: { sent: [], entries: [], sendUserMessage(t) { this.sent.push(t); }, appendEntry(t, d) { this.entries.push([t, d]); } },
    ctx: { hasUI: true, ui: { status: {}, lastNotify: null, setStatus(k, v) { this.status[k] = v; }, notify(m, l) { this.lastNotify = { m, l }; } } },
});

// 1. OVERRIDE: starting while active restarts with the new settings
let m = mocks(); core.resetAll();
core.control(m.host, m.ctx, { action: "start", duration: "1h", message: "old" });
const r2 = core.control(m.host, m.ctx, { action: "start", duration: "30s", message: "new" });
eq(r2.state.message, "new", "override: message replaced");
eq(r2.state.intervalMs, 30_000, "override: interval replaced");
eq(r2.state.active, true, "override: still active");
if (!r2.text.includes("Restarted")) { fail++; console.log("  FAIL: override text lacks 'Restarted'"); } else pass++;

// 2. ONCE: fires exactly once, then stops
m = mocks(); core.resetAll();
core.control(m.host, m.ctx, { action: "start", duration: "1h", once: true, message: "shot" });
core.onBeatDue(m.host, m.ctx);
eq(m.host.sent.length, 1, "once: exactly one delivery");
eq(m.ctx.ui.lastNotify && m.ctx.ui.lastNotify.m.includes("One-shot delivered"), true, "once: finish notice");
eq(m.host.entries.at(-1)[1].active, false, "once: persisted inactive");

// 3. BUSY SHIFT: beat due mid-turn is shifted, not consumed
m = mocks(); core.resetAll();
core.control(m.host, m.ctx, { action: "start", duration: "1h" });
core.setBusy(true);
core.onBeatDue(m.host, m.ctx);
eq(m.host.sent.length, 0, "busy: no fire while busy");
eq(core.control(m.host, m.ctx, { action: "status" }).state.active, true, "busy: still active");
core.setBusy(false);
core.onBeatDue(m.host, m.ctx);
eq(m.host.sent.length, 1, "busy: fires when idle again");

// 4. STUCK BUSY: missing turn_end (busy older than 15 min) → treat as idle
m = mocks(); core.resetAll();
core.control(m.host, m.ctx, { action: "start", duration: "1h" });
core.setBusy(true, Date.now() - 16 * 60_000);
core.onBeatDue(m.host, m.ctx);
eq(m.host.sent.length, 1, "stuck busy: fires instead of shifting forever");

// 5. PAUSE/RESUME one-shot: pause clears the timer, resume re-arms the deadline
m = mocks(); core.resetAll();
core.control(m.host, m.ctx, { action: "start", duration: "1h", once: true });
core.control(m.host, m.ctx, { action: "pause" });
eq(core.control(m.host, m.ctx, { action: "status" }).state.paused, true, "pause: paused");
core.control(m.host, m.ctx, { action: "resume" });
const rs = core.control(m.host, m.ctx, { action: "status" });
eq(rs.state.active, true, "resume: still active");
eq(rs.state.once, true, "resume: still one-shot (not recurring)");
eq(rs.state.paused, false, "resume: not paused");

// 6. maxCount stop
m = mocks(); core.resetAll();
core.control(m.host, m.ctx, { action: "start", duration: "1h", maxCount: 2 });
core.onBeatDue(m.host, m.ctx);
core.onBeatDue(m.host, m.ctx);
eq(m.host.sent.length, 2, "maxCount: two deliveries");
eq(core.control(m.host, m.ctx, { action: "status" }).state.active, false, "maxCount: stopped after limit");

// 7. restoreFrom: lost heartbeat is reported once, config kept, active cleared
m = mocks(); core.resetAll();
const lost = core.restoreFrom({ active: true, message: "keep me", intervalMs: 30_000 }, m.host);
eq(lost, true, "restore: reports lost active heartbeat");
eq(core.control(m.host, m.ctx, { action: "status" }).state.message, "keep me", "restore: config kept");
eq(core.control(m.host, m.ctx, { action: "status" }).state.active, false, "restore: active cleared");
eq(m.host.entries.at(-1)[1].active, false, "restore: persists cleared flag (no repeat nag)");

// 8. ESC: toggles pause when active+idle, passes through otherwise
m = mocks(); core.resetAll();
eq(core.onEscape(m.host, m.ctx), false, "esc: no heartbeat → not consumed");
core.control(m.host, m.ctx, { action: "start", duration: "1h" });
eq(core.onEscape(m.host, m.ctx), true, "esc: consumed when active");
eq(core.control(m.host, m.ctx, { action: "status" }).state.paused, true, "esc: paused");
eq(core.onEscape(m.host, m.ctx), true, "esc: consumed when paused");
eq(core.control(m.host, m.ctx, { action: "status" }).state.paused, false, "esc: resumed");
core.setBusy(true);
eq(core.onEscape(m.host, m.ctx), false, "esc: busy → not consumed (abort preserved)");

console.log(`CORE TESTS: ${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
EOF
        if node "$HBC/run.js" >/tmp/hb-core.log 2>&1; then
            ok
        else
            bad "control-flow tests failed: $(grep -m1 'FAIL:' /tmp/hb-core.log)"
        fi
    fi
fi

# smoke: extension loads in pi is a live check — skipped here, covered by pi itself
warn "live load in pi not exercised (interactive)"

echo
echo "PASS=$PASS FAIL=$FAIL WARN=$WARN"
[ "$FAIL" -eq 0 ]
