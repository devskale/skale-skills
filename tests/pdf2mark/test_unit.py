#!/usr/bin/env python3
"""Unit tests for SSE job waiting in pdf2mark.py (_sse_wait) — no network.

The SSE path is an ACCELERATOR with a hard contract: any failure mode
(older server, proxy eating the stream, stream ending without a terminal
event, env kill switch, deadline) must return None so the caller falls
back to proven 3s polling. These tests pin exactly that: SSE never
breaks a conversion, it can only make waiting snappier.

Runs under any python3 (monkeypatches requests.get in the module).
Invoked by tests/pdf2mark/test.sh.
"""
import json
import os
import sys
import time
from contextlib import contextmanager
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parents[2] / "skills" / "pdf2mark" / "scripts"
sys.path.insert(0, str(SCRIPTS))
import pdf2mark  # noqa: E402

PASS = 0
FAIL = 0


def check(name, cond):
    global PASS, FAIL
    if cond:
        PASS += 1
    else:
        FAIL += 1
        print(f"  FAIL: {name}", file=sys.stderr)


class FakeSSE:
    """Simulates requests.get(stream=True) for an SSE endpoint."""

    def __init__(self, events, status_code=200):
        self.events = events  # list[str]: complete SSE wire lines
        self.status_code = status_code

    def __enter__(self):
        return self

    def __exit__(self, *a):
        return False

    def iter_lines(self, decode_unicode=True):
        return iter(self.events)


def wire(status, **extra):
    """One complete SSE status event as wire lines (incl. trailing blank)."""
    payload = {"status": status, "expires_in": 7000}
    payload.update(extra)
    return ["event: status", "data: " + json.dumps(payload), ""]


def sse(events, status_code=200):
    fake = FakeSSE(events, status_code)

    def getter(url, **kw):
        return fake

    pdf2mark.requests.get = getter
    return fake


HDRS = {"Authorization": "Bearer x"}
DEADLINE = time.monotonic() + 60

# 1. happy path: transitions streamed, done snapshot returned
sse(wire("queued") + [": ping", ""] + wire("running") + wire("done", chars=12345))
body = pdf2mark._sse_wait("job123", HDRS, DEADLINE, False)
check("done snapshot returned", body and body["status"] == "done")
check("payload carried (chars)", body.get("chars") == 12345)
check("ttl carried (expires_in)", body.get("expires_in") == 7000)

# 2. failed event -> failed snapshot (caller exits with its error)
sse(wire("queued") + wire("failed", error="conversion failed: boom"))
body = pdf2mark._sse_wait("job123", HDRS, DEADLINE, False)
check("failed snapshot returned", body and body["status"] == "failed")
check("error carried", body.get("error") == "conversion failed: boom")

# 3. older server without the endpoint (404) -> None -> polling fallback
sse([], status_code=404)
check("404 -> None (fallback)", pdf2mark._sse_wait("job123", HDRS, DEADLINE, False) is None)

# 4. stream ends without terminal event -> None (fallback)
sse(wire("queued") + wire("running"))
check("stream end without terminal -> None", pdf2mark._sse_wait("job123", HDRS, DEADLINE, False) is None)

# 5. kill switch env -> None without any request
called = []

def boom(url, **kw):
    called.append(url)
    raise AssertionError("must not be called with PDF2MD_NO_SSE")

pdf2mark.requests.get = boom
os.environ["PDF2MD_NO_SSE"] = "1"
check("PDF2MD_NO_SSE -> None", pdf2mark._sse_wait("job123", HDRS, DEADLINE, False) is None)
check("kill switch makes no request", not called)
del os.environ["PDF2MD_NO_SSE"]

# 6. deadline already passed -> None without consuming the stream
sse(wire("queued") + wire("done"))
check("deadline passed -> None", pdf2mark._sse_wait("job123", HDRS, time.monotonic() - 1, False) is None)

# 7. request error (proxy reset) -> None, never an exception
def broken(url, **kw):
    raise pdf2mark.requests.RequestException("connection reset")

pdf2mark.requests.get = broken
try:
    check("request error -> None", pdf2mark._sse_wait("job123", HDRS, DEADLINE, False) is None)
except Exception as e:
    check(f"request error must not raise ({e})", False)

# 8. malformed data line -> None, never an exception
sse(["event: status", "data: {not json", ""])
try:
    check("malformed json -> None", pdf2mark._sse_wait("job123", HDRS, DEADLINE, False) is None)
except Exception as e:
    check(f"malformed json must not raise ({e})", False)


# ── 9. pages-aware poll budget (_poll_budget_for_pages) ──────────────────
# Vorfall 2026-10-22: 222 Seiten > 600s statisches Budget -> Fehler, obwohl
# der Job kurz danach fertig war. Real gemessen: 2.7–9 s/Seite -> Budget
# pages×10s+120s (großzügiger oberer Rand).
B = pdf2mark._poll_budget_for_pages
check("222 pages -> 2220+120=2340s (covers the observed ~29min)",
      B(222, 600) == 222 * 10 + 120)
check("316 pages -> 3280s (st7789v case, >19min observed)",
      B(316, 600) == 316 * 10 + 120)
check("small doc keeps base when pages-budget is smaller",
      B(30, 600) == 600)  # 30×10+120=420 < 600 -> base wins
check("unknown pages -> base", B(None, 600) == 600)
check("zero pages -> base", B(0, 600) == 600)
check("garbage pages -> base", B("many", 600) == 600)
check("negative pages -> base", B(-5, 600) == 600)

# ── 10. _poll_wait extends the deadline once pages are known ─────────────
# Simulierter Job: 1. Poll running(222 pages), 2. Poll done. time.sleep wird
# gepatcht (kein echtes Warten); requests.get liefert die Fake-Antworten.
class _FakeResp:
    def __init__(self, payload, status_code=200):
        self._p = payload
        self.status_code = status_code
    def json(self):
        return self._p

_poll_calls = {"n": 0}
_real_sleep = pdf2mark.time.sleep
pdf2mark.time.sleep = lambda s: None

def _seq_get(url, **kw):
    _poll_calls["n"] += 1
    if _poll_calls["n"] == 1:
        return _FakeResp({"status": "running", "pages": 222})
    return _FakeResp({"status": "done", "markdown": "ok", "pages": 222})

pdf2mark.requests.get = _seq_get
_short_deadline = pdf2mark.time.monotonic() + 1  # would expire next loop!
try:
    body = pdf2mark._poll_wait("jobX", "http://x/jobs/jobX", {}, _short_deadline, False)
    check("_poll_wait survives a short deadline via pages-extension",
          body.get("status") == "done" and _poll_calls["n"] == 2)
except SystemExit as e:
    check(f"_poll_wait must not exit while pages-budget covers the job ({e})", False)
finally:
    pdf2mark.time.sleep = _real_sleep

print("")
print(f"PASS={PASS} FAIL={FAIL}")
sys.exit(0 if FAIL == 0 else 1)
