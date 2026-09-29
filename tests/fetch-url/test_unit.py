#!/usr/bin/env python3
"""Unit tests for credgoo refresh-retry in fetch.py (_key_with_refresh).

Cache-first, self-heal on miss/error, but at most one forced refetch per
cooldown window. Runs under the skill venv's python (monkeypatches
get_api_key → no network, no credgoo store). Invoked by
tests/fetch-url/test.sh.
"""
import os
import sys
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parents[2] / "skills" / "fetch-url" / "scripts"
sys.path.insert(0, str(SCRIPTS))
import fetch  # noqa: E402

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
    calls.clear()

    def fake(service, no_cache=False, **kw):
        calls.append((service, no_cache))
        return key(no_cache)

    fetch.get_api_key = fake


# 1. cache hit → single call, no refresh
calls = []
run(calls, lambda n: "TOKEN")
check("cache hit returns key", fetch._key_with_refresh("S") == "TOKEN")
check("cache hit: 1 call, no no_cache", len(calls) == 1 and calls[0][1] is False)

# 2. miss → one forced refetch succeeds
calls = []
run(calls, lambda n: None if not n else "FRESH")
check("miss then refresh returns key", fetch._key_with_refresh("S") == "FRESH")
check("refetch forced with no_cache=True", len(calls) == 2 and calls[1][1] is True)

# 3. total miss → None
calls = []
run(calls, lambda n: None)
check("total miss returns None", fetch._key_with_refresh("S") is None)
check("total miss tries twice", len(calls) == 2)

# 3b. NO refresh gate: a repeated miss retries the source every time.
# Regression test for the removed per-skill gate.
calls2 = []
run(calls2, lambda n: None)
check("repeat miss returns None", fetch._key_with_refresh("S") is None)
check("repeat miss still hits the source (no gate)", len(calls2) == 2 and calls2[1][1] is True)

# 4. network error → refetch recovers
calls = []


def raiser(n):
    if not n:
        raise OSError("read timed out")
    return "RECOVERED"


run(calls, raiser)
check("error then refresh returns key", fetch._key_with_refresh("S") == "RECOVERED")
check("error path retried with no_cache", len(calls) == 2 and calls[1][1] is True)

# 5. both raise → None, never propagates
calls = []
run(calls, lambda n: (_ for _ in ()).throw(OSError("down")))
check("both fail returns None", fetch._key_with_refresh("S") is None)

# 6. get_bearer_token prefers env, then credgoo refresh path
import os  # noqa: E402

calls = []
run(calls, lambda n: None if not n else "CREDGOO-TOKEN")
os.environ["FETCH_URL_BEARER"] = "ENV-TOKEN"
check("env wins over credgoo", fetch.get_bearer_token() == "ENV-TOKEN")
check("env short-circuits (0 credgoo calls)", len(calls) == 0)
del os.environ["FETCH_URL_BEARER"]
check("credgoo refresh path used when env unset", fetch.get_bearer_token() == "CREDGOO-TOKEN")

print("")
print(f"PASS={PASS} FAIL={FAIL}")
sys.exit(0 if FAIL == 0 else 1)
