#!/usr/bin/env python3
"""Unit tests for search.py — no network, no credgoo store.

Covers the credgoo lookup (_key_with_refresh): cache-first; one refetch from
the source on a miss or a fetch error. Freshness is credgoo's job (its cache
carries a 7-day TTL), so there is deliberately no refresh gate here — the
tests below pin that decision, including the multi-key sequence that a
per-skill gate used to starve.

Also covers the Duck→SearXNG fallback helpers (_duck_only_flags,
_searxng_fallback): monkeypatches _run_searxng_search, pins that a Duck
error row triggers exactly one SearXNG attempt, that both-failed reports
None, and that clean results pass through untouched.

Runs under the skill venv's python. Invoked by tests/web-search/test.sh.
"""
import argparse
import io
import json
import os
import sys
from contextlib import redirect_stderr
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parents[2] / "skills" / "web-search" / "scripts"
sys.path.insert(0, str(SCRIPTS))
import search  # noqa: E402

PASS = 0
FAIL = 0


def check(name, cond):
    global PASS, FAIL
    if cond:
        PASS += 1
    else:
        FAIL += 1
        print(f"  FAIL: {name}", file=sys.stderr)


def run(calls, key):
    """Install a fake get_api_key; key is a callable(nocache)->value|raise."""
    calls.clear()

    def fake(service, no_cache=False, **kw):
        calls.append((service, no_cache))
        return key(no_cache)

    search.get_api_key = fake


# 1. cache hit → single call, no network
calls = []
run(calls, lambda n: "TOKEN")
check("cache hit returns key", search._key_with_refresh("S") == "TOKEN")
check("cache hit makes exactly 1 call", len(calls) == 1 and calls[0][1] is False)

# 2. miss → one refetch, which succeeds
calls = []
run(calls, lambda n: None if not n else "FRESH")
check("miss then refetch returns key", search._key_with_refresh("S") == "FRESH")
check("refetch forced with no_cache=True", len(calls) == 2 and calls[1][1] is True)

# 3. total miss → None (caller falls back)
calls = []
run(calls, lambda n: None)
check("total miss returns None", search._key_with_refresh("S") is None)
check("total miss tries exactly twice", len(calls) == 2)

# 3b. NO refresh gate: a repeated miss retries the source every time.
# Regression test for the removed per-skill gate — a gate made the second call
# of a multi-key skill return None even though the source was reachable.
calls2 = []
run(calls2, lambda n: None)
check("repeat miss returns None", search._key_with_refresh("S") is None)
check("repeat miss still hits the source (no gate)", len(calls2) == 2 and calls2[1][1] is True)

# 4. network error on cache read → refetch recovers
calls = []


def raiser(n):
    if not n:
        raise OSError("read timed out")
    return "RECOVERED"


run(calls, raiser)
check("network error then refetch returns key", search._key_with_refresh("S") == "RECOVERED")
check("error path retried with no_cache", len(calls) == 2 and calls[1][1] is True)

# 5. both attempts fail → None, never propagates
calls = []
run(calls, lambda n: (_ for _ in ()).throw(OSError("down")))
check("both fail returns None", search._key_with_refresh("S") is None)

# 6. THE SEQUENCE: web-search needs two keys (bearer + DUCK_API_URL). Both must
#    resolve — a shared refresh gate used to starve the second one.
os.environ.pop("DUCK_API_URL", None)
os.environ.pop("WEB_SEARCH_BEARER", None)
calls = []


def multi(service, no_cache=False, **kw):
    calls.append((service, no_cache))
    return {
        "WEB_SEARCH_BEARER": "TOK",
        "DUCK_API_URL": "https://amd.skale.dev/api/duck",
    }[service]


search.get_api_key = multi
bearer = search.get_bearer_token()
url = search.get_duck_api_url()
check("sequence: bearer resolves", bearer == "TOK")
check("sequence: DUCK_API_URL resolves", url == "https://amd.skale.dev/api/duck")
check("sequence: both services queried", {c[0] for c in calls} == {"WEB_SEARCH_BEARER", "DUCK_API_URL"})

# 6b. env vars short-circuit credgoo entirely (no network, no gate)
os.environ["DUCK_API_URL"] = "https://env.example/api/duck"
calls = []
search.get_api_key = multi
url = search.get_duck_api_url()
check("env wins over credgoo", url == "https://env.example/api/duck")
check("env short-circuits (0 credgoo calls)", len(calls) == 0)
del os.environ["DUCK_API_URL"]

# ── Duck→SearXNG fallback helpers (issue 2026-10-13) ──────────────────
# _run_searxng_search is monkeypatched → these run fully offline.

FB_ARGS = argparse.Namespace(
    site=None, filetype=None, inurl=None, exclude=None, exact=False,
    categories=None)

# 7. _duck_only_flags detects only the set flags
FLAG_ARGS = argparse.Namespace(
    site="x.com", filetype=None, inurl=None, exclude=None, exact=True,
    categories=None)
check("duck-only flags detected",
      search._duck_only_flags(FLAG_ARGS) == ["--site", "--exact"])
check("no duck-only flags → empty list",
      search._duck_only_flags(FB_ARGS) == [])

# 8. Duck error row → exactly one SearXNG attempt, its results win
attempts = []
search._run_searxng_search = lambda a: (attempts.append(1) or {
    "results": [{"title": "t", "url": "u"}]})
res, fell_back = search._searxng_fallback(
    FB_ARGS, [{"error": "Duck API error 502: outage"}])
check("fallback serves searxng results",
      isinstance(res, dict) and res.get("results") == [{"title": "t", "url": "u"}])
check("fallback flag set", fell_back is True)
check("exactly one searxng attempt", len(attempts) == 1)

# 9. both backends failed → None (caller exits; errors already printed)
attempts.clear()
search._run_searxng_search = lambda a: (attempts.append(1) or {
    "error": "SearXNG error: all 5 instances failed"})
res, fell_back = search._searxng_fallback(
    FB_ARGS, [{"error": "Duck API error 502: outage"}])
check("both failed → None", res is None and fell_back is True)
check("both failed still made one attempt", len(attempts) == 1)

# 10. clean results (no error row) pass through untouched, no attempt
attempts.clear()
clean = [{"title": "t", "url": "u"}]
res, fell_back = search._searxng_fallback(FB_ARGS, clean)
check("clean results pass through", res is clean and fell_back is False)
check("no searxng attempt without error", len(attempts) == 0)

# 11. error rows name their origin (descriptive messages, issue §5.3)
src = Path(search.__file__).read_text(encoding="utf-8")
check("duck 502 labeled", '"Duck API error 502' in src)
check("duck request errors labeled", 'f"Duck API request failed' in src)
check("duck news errors labeled", 'f"Duck news API request failed' in src)
check("searxng errors labeled", 'f"SearXNG error: all' in src)

# =============================================================================
# Degraded-instance handling (2026-10-16: lubu SearXNG update — private
# instance answered 200 with results:[] while ALL engines were suspended
# (CAPTCHA / access denied / 429). That is an outage, not a query miss:
# fall through to the next instance, and surface the suspension in output.
# ==============================================================================

class _FakeResp:
    """Minimal urlopen stand-in: context manager returning a JSON payload."""
    def __init__(self, payload):
        self._p = json.dumps(payload).encode()

    def read(self):
        return self._p

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False


def _sx_args():
    return argparse.Namespace(
        query="q", max=10, categories=None, engines=None,
        time_range=None, language="en", page=1,
    )


DEGRADED = {"query": "q", "results": [], "answers": [], "corrections": [],
            "infoboxes": [], "suggestions": [],
            "unresponsive_engines": [["duckduckgo", "CAPTCHA"],
                                     ["google", "Suspended: access denied"]]}
HEALTHY = {"query": "q", "results": [{"title": "t", "url": "u"}],
           "unresponsive_engines": []}


# 12. private degraded (empty + suspensions) → fall through to public
urls_requested = []
original_urlopen = search.urllib.request.urlopen


def _fake_urlopen_by_url(mapping):
    """Last mapping entry whose marker matches wins; marker None = default."""
    def fake(req, timeout=15, context=None):
        urls_requested.append(req.full_url)
        for marker, payload in mapping.items():
            if (marker is None or marker in req.full_url):
                return _FakeResp(payload)
        raise AssertionError(f"unexpected url {req.full_url}")
    return fake


search.urllib.request.urlopen = _fake_urlopen_by_url({
    "private.example": DEGRADED,
    None: HEALTHY,  # any public instance
})
stderr = io.StringIO()
with redirect_stderr(stderr):
    res = search.search_searxng(query="q", max_results=10, categories=None,
                                engines=None, time_range=None, language="en",
                                instance_url="https://private.example",
                                auth=None)
check("degraded private → public results served",
      isinstance(res, dict) and res.get("results") == [{"title": "t", "url": "u"}])
check("degraded private → tried public fallback",
      len(urls_requested) == 2 and "private.example" in urls_requested[0]
      and "private.example" not in urls_requested[1])
check("degraded fall-through warns LOUDLY (hard rule)",
      "suspended" in stderr.getvalue() and "private.example" in stderr.getvalue()
      and stderr.getvalue().startswith("Warning:"))

# 13. ALL instances degraded → first degraded payload (suspension stays visible)
urls_requested.clear()
search.urllib.request.urlopen = _fake_urlopen_by_url({
    "private.example": DEGRADED,
    None: DEGRADED,
})
res = search.search_searxng(query="q", max_results=10, categories=None,
                            engines=None, time_range=None, language="en",
                            instance_url="https://private.example",
                            auth=None)
check("all degraded → no error row, suspension kept",
      isinstance(res, dict) and "error" not in res
      and res.get("unresponsive_engines") == DEGRADED["unresponsive_engines"])
check("all degraded → every instance tried",
      len(urls_requested) == 1 + len(search.PUBLIC_SEARXNG_INSTANCES))

# 14. empty but HEALTHY (no suspensions) → genuine miss, returned immediately
urls_requested.clear()
search.urllib.request.urlopen = _fake_urlopen_by_url({
    "private.example": {"query": "q", "results": [],
                        "unresponsive_engines": []},
    None: HEALTHY,
})
res = search.search_searxng(query="q", max_results=10, categories=None,
                            engines=None, time_range=None, language="en",
                            instance_url="https://private.example",
                            auth=None)
check("healthy empty → returned as-is (no fallback)",
      isinstance(res, dict) and res.get("results") == []
      and res.get("_instance") == "https://private.example")
check("healthy empty → public NOT queried", len(urls_requested) == 1)

# 15. format_results: degraded payload names the suspended engines
text = search.format_results(DEGRADED, "searxng", "q")
check("degraded output mentions suspension",
      "suspended" in text and "duckduckgo" in text and "google" in text)
text_ok = search.format_results({"query": "q", "results": []}, "searxng", "q")
check("plain miss output unchanged",
      text_ok == "No results found for 'q'." and "suspended" not in text_ok)

search.urllib.request.urlopen = original_urlopen

# 16. malformed SEARXNG_URL env → loud warning, NOT a silent drop to credgoo
original_env = search.PRIVATE_SEARXNG_URL
search.PRIVATE_SEARXNG_URL = "@user@pass"  # url part empty → unparseable
run(calls, lambda n: "https://credgoo.example@u@p")  # credgoo would answer
stderr = io.StringIO()
with redirect_stderr(stderr):
    creds = search.get_searxng_credentials()
check("malformed SEARXNG_URL warns loudly",
      "Warning" in stderr.getvalue() and "SEARXNG_URL" in stderr.getvalue())
check("malformed SEARXNG_URL still falls back to credgoo",
      creds is not None and creds["url"] == "https://credgoo.example")
search.PRIVATE_SEARXNG_URL = original_env

print("")
print(f"PASS={PASS} FAIL={FAIL}")
sys.exit(0 if FAIL == 0 else 1)
