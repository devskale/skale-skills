# Rodney Troubleshooting & Agent Retry

Quick-reference for agents driving rodney. For the canonical command list, run
`rodney --help` (source of truth) or read [commands.md](commands.md).

## Exit codes

| Code | Meaning | Agent action |
|------|---------|--------------|
| `0` | Success | Continue |
| `1` | Assertion / check failed (`exists`, `visible`, `count`, `assert`) | Retry candidate |
| `2` | Error (bad args, timeout, no browser) | Fix root cause first |

## Diagnostic flow

When a command fails, don't blindly retry — classify first:

1. **Is the browser alive?** `rodney status` (or `rodney-cleanup --json`).
   - No browser / stale state → `rodney-cleanup --clean`, then `rodney start`.
   - Dies again shortly after start → binary-level problem, see the first failure
     scenario below (`ROD_CHROME_BIN` override).
2. **Was it a timeout?** `wait`, `waitstable`, `waitidle` time out → page slow or
   selector wrong. Retry with a longer `ROD_TIMEOUT` or a different wait.
3. **Was it an assertion (exit 1)?** Element missing / not visible / wrong value →
   the page may not have rendered yet. Retry after `waitstable`.
4. **Was it an error (exit 2)?** Bad selector, bad args, no browser → **fix, don't retry**.

## Common failure scenarios

- **Browser silently exits 20–60 s after `start`, between commands, no crash report**
  → the system Chrome binary is unstable headless — not a rodney bug. Signature:
  `status` shows a stale PID right after successful commands; state.json appears/vanishes;
  no Chrome entry in `~/Library/Logs/DiagnosticReports/`. Seen jMacAir 2026-11-05: regular
  Chrome exited deterministically ~30 s (even bare `nohup … --headless`, no rodney), while
  Chrome Beta survived; the regular binary also wrote Chrome-**Beta** Crashpad paths
  (install mismatch). **Fix:** verify with a bare probe
  (`nohup "<chrome>" --headless --user-data-dir /tmp/probe about:blank &`, watch the PID
  60 s), then `export ROD_CHROME_BIN="<stable binary>"` (e.g. Chrome Beta) and restart.
  Don't debug rodney internals before the probe rules the binary out.
- **Click / input does nothing** → SPA re-rendered, selector stale. Re-query with
  `waitstable`, re-select, retry. For autocomplete/booking flows, prefer the site's
  public API or `rodney js` to set values directly.
- **Element not found** → selector wrong or not loaded. Check with `rodney exists`,
  `rodney count`, or `rodney js` to inspect the DOM. Fix the selector.
- **Page didn't navigate** → `open` timed out. Retry `open`, then `waitstable`.
- **Text extraction empty** → element matched but has no text, or page not loaded.
  Verify with `rodney html <sel>`.
- **Assertion fails intermittently** → timing. `waitstable` then re-assert.

## Stall detection & recovery

A rodney command that hangs **>10s** is likely stalled. Recover:

```bash
rodney status        # is the browser still responsive?
rodney-ps --json     # how many chrome processes? any orphans?
rodney stop && rodney start   # hard reset if wedged
```

Don't let a stalled command block forever — use a timeout on the agent side and
treat a repeated stall as a browser-health problem, not a retry problem.

## Decision matrix: retry vs adapt

| Situation | Action |
|-----------|--------|
| Exit 1 (assertion), timing-related | **Retry** (usually with `waitstable` first) |
| Exit 2 (bad args / no browser) | **Fix** root cause, don't retry |
| Same failure 3+ times | **Adapt**: change selector / wait / strategy |
| 5+ failures on one task | **Escalate** to user |
| Command hangs >10s | Check browser health, hard reset |

## Cost-optimized retry pattern

For flaky timing/network steps, retry in a shell loop to avoid repeated round-trips
(roughly 70–90% fewer tokens than asking the agent to re-inspect each time):

```bash
for i in 1 2 3; do
    rodney waitstable && rodney click "#submit" && break
    sleep 2
done
```

Only escalate to full agent-driven retry (re-read output, re-plan) when the loop
exhausts or the failure is strategic (wrong selector, wrong page).

## When to give up

- 5+ failures on the same step with no progress.
- Browser repeatedly wedges (status hangs, multiple orphans after cleanup).
- The site actively blocks automation (CAPTCHA, bot detection) — switch approach
  (public API, `surf` on a real session, or `chrome-devtools-mcp`).

## Debug commands

```bash
rodney status            # browser info + active page
rodney-ps --json         # process visibility (managed vs orphan)
rodney-cleanup --clean   # remove stale state + kill orphans (non-interactive)
rodney url / title / html   # where am I, what's rendered
rodney js 'document.querySelector("body").innerText.slice(0,500)'
```
