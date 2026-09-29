#!/usr/bin/env python3
"""Unit tests for credgoo refresh-retry in fetch.py (_key_with_refresh).

Cache-first, self-heal on miss/error, but at most one forced refetch per
cooldown window. Runs under the skill venv's python (monkeypatches
get_api_key → no network, no credgoo store). Invoked by
tests/fetch-url/test.sh.
"""
import sys
import tempfile
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parents[2] / "skills" / "fetch-url" / "scripts"
sys.path.insert(0, str(SCRIPTS))
import fetch  # noqa: E402

# Isolate the cooldown: throwaway stamp dir, wide-open window.
fetch._CREDGOO_STAMP_DIR = Path(tempfile.mkdtemp())
fetch._CREDGOO_STAMP = fetch._CREDGOO_STAMP_DIR / "credgoo-refresh"
fetch._CREDGOO_REFRESH_COOLDOWN_S = 3600

PASS = 0
FAIL = 0


def check(name, cond):
    global PASS, FAIL
    if cond:
        PASS += 1
    else:
        FAIL += 1
        print(f"  FAIL: {name}", file=sys.stderr)


def reset():
    try:
        fetch._CREDGOO_STAMP.unlink()
    except Exception:
        pass


def run(calls, key):
    calls.clear()

    def fake(service, no_cache=False, **kw):
        calls.append((service, no_cache))
        return key(no_cache)

    fetch.get_api_key = fake


# 1. cache hit → single call, no refresh
reset()
calls = []
run(calls, lambda n: "TOKEN")
check("cache hit returns key", fetch._key_with_refresh("S") == "TOKEN")
check("cache hit: 1 call, no no_cache", len(calls) == 1 and calls[0][1] is False)

# 2. miss → one forced refetch succeeds
reset()
calls = []
run(calls, lambda n: None if not n else "FRESH")
check("miss then refresh returns key", fetch._key_with_refresh("S") == "FRESH")
check("refetch forced with no_cache=True", len(calls) == 2 and calls[1][1] is True)

# 3. total miss → None
reset()
calls = []
run(calls, lambda n: None)
check("total miss returns None", fetch._key_with_refresh("S") is None)
check("total miss tries twice", len(calls) == 2)

# 3b. cooldown: repeat miss stays offline (no network hammer)
calls2 = []
run(calls2, lambda n: None)
check("cooldown: repeat miss returns None", fetch._key_with_refresh("S") is None)
check("cooldown: only cache call", len(calls2) == 1 and calls2[0][1] is False)

# 3c. window expiry → refetch allowed again
fetch._CREDGOO_REFRESH_COOLDOWN_S = 0
calls3 = []
run(calls3, lambda n: None if not n else "AGAIN")
check("expiry allows refetch", fetch._key_with_refresh("S") == "AGAIN")
check("expiry made 2 calls", len(calls3) == 2 and calls3[1][1] is True)
fetch._CREDGOO_REFRESH_COOLDOWN_S = 3600

# 4. network error → refetch recovers
reset()
calls = []


def raiser(n):
    if not n:
        raise OSError("read timed out")
    return "RECOVERED"


run(calls, raiser)
check("error then refresh returns key", fetch._key_with_refresh("S") == "RECOVERED")
check("error path retried with no_cache", len(calls) == 2 and calls[1][1] is True)

# 5. both raise → None, never propagates
reset()
calls = []
run(calls, lambda n: (_ for _ in ()).throw(OSError("down")))
check("both fail returns None", fetch._key_with_refresh("S") is None)

# 6. get_bearer_token prefers env, then credgoo refresh path
import os  # noqa: E402

reset()
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
