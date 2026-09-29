#!/usr/bin/env python3
"""Unit tests for credgoo lookup in search.py (_key_with_refresh).

Cache-first; one refetch from the source on a miss or a fetch error. Freshness
is credgoo's job (its cache carries a 7-day TTL), so there is deliberately no
refresh gate here — the tests below pin that decision, including the
multi-key sequence that a per-skill gate used to starve.

Runs under the skill venv's python (monkeypatches get_api_key → no network, no
credgoo store). Invoked by tests/web-search/test.sh.
"""
import os
import sys
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

print("")
print(f"PASS={PASS} FAIL={FAIL}")
sys.exit(0 if FAIL == 0 else 1)
