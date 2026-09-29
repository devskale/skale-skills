#!/usr/bin/env python3
"""Unit tests for credgoo refresh-retry in search.py (_key_with_refresh).

Runs with the skill venv's python (monkeypatches the module's get_api_key,
so no network and no credgoo store are needed). Invoked by
tests/web-search/test.sh.
"""
import sys
import types
from pathlib import Path

# Import search.py standalone (it only needs credgoo importable, which the venv has).
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


# ── 1. cache hit → no refetch ──
calls = []
run(calls, lambda nocache: "TOKEN")
check("cache hit returns key", search._key_with_refresh("S") == "TOKEN")
check("cache hit makes exactly 1 call", len(calls) == 1 and calls[0][1] is False)

# ── 2. cache miss → one forced refetch that succeeds ──
calls = []
run(calls, lambda nocache: None if not nocache else "FRESH")
check("miss then refresh returns key", search._key_with_refresh("S") == "FRESH")
check("refresh forced with no_cache=True", len(calls) == 2 and calls[1][1] is True)

# ── 3. cache miss + refresh miss → None (falls back) ──
calls = []
run(calls, lambda nocache: None)
check("total miss returns None", search._key_with_refresh("S") is None)
check("total miss tries twice", len(calls) == 2)

# ── 4. first call raises (network) → refetch succeeds ──
calls = []


def raiser(nocache):
    if not nocache:
        raise OSError("read timed out")
    return "RECOVERED"


run(calls, raiser)
check("network error then refresh returns key", search._key_with_refresh("S") == "RECOVERED")
check("error path forced no_cache on retry", len(calls) == 2 and calls[1][1] is True)

# ── 5. both raise → None, never propagates ──
calls = []
run(calls, lambda nocache: (_ for _ in ()).throw(OSError("down")))
check("both fail returns None (no raise)", search._key_with_refresh("S") is None)

# ── 6. the public resolvers use the refreshing path ──
calls = []
run(calls, lambda nocache: None if not nocache else "https://host/api/duck")
import os
os.environ.pop("DUCK_API_URL", None)
check("_resolve_url goes through refresh", search.get_duck_api_url() == "https://host/api/duck")

print("")
print(f"PASS={PASS} FAIL={FAIL}")
sys.exit(0 if FAIL == 0 else 1)
