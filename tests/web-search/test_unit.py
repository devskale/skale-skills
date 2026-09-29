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

# Isolate the refresh cooldown: point the stamp at a throwaway dir and force
# the window wide open, so each case below starts from "refresh allowed".
import os as _os  # noqa: E402
import tempfile as _tempfile  # noqa: E402

_stamp_dir = _tempfile.mkdtemp()
search._CREDGOO_STAMP_DIR = Path(_stamp_dir)
search._CREDGOO_STAMP = search._CREDGOO_STAMP_DIR / "credgoo-refresh"
search._CREDGOO_REFRESH_COOLDOWN_S = 3600


def reset_cooldown():
    try:
        search._CREDGOO_STAMP.unlink()
    except Exception:
        pass


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


# ── 1. cache hit → no refetch, no network ──
reset_cooldown()
calls = []
run(calls, lambda nocache: "TOKEN")
check("cache hit returns key", search._key_with_refresh("S") == "TOKEN")
check("cache hit makes exactly 1 call", len(calls) == 1 and calls[0][1] is False)

# ── 2. cache miss → one forced refetch that succeeds ──
reset_cooldown()
calls = []
run(calls, lambda nocache: None if not nocache else "FRESH")
check("miss then refresh returns key", search._key_with_refresh("S") == "FRESH")
check("refresh forced with no_cache=True", len(calls) == 2 and calls[1][1] is True)

# ── 3. cache miss + refresh miss → None (falls back) ──
reset_cooldown()
calls = []
run(calls, lambda nocache: None)
check("total miss returns None", search._key_with_refresh("S") is None)
check("total miss tries twice", len(calls) == 2)

# ── 3b. cooldown: after a failed refresh, the NEXT call must NOT re-hit the network ──
# (same fake, cooldown now active because the stamp was written during call 1)
calls2 = []
run(calls2, lambda nocache: None)
check("cooldown: repeat miss stays offline", search._key_with_refresh("S") is None)
check("cooldown: repeat miss makes only the cache call", len(calls2) == 1 and calls2[0][1] is False)

# ── 3c. cooldown expires → refresh allowed again ──
search._CREDGOO_REFRESH_COOLDOWN_S = 0  # window open
calls3 = []
run(calls3, lambda nocache: None if not nocache else "AGAIN")
check("cooldown expiry allows refetch", search._key_with_refresh("S") == "AGAIN")
check("cooldown expiry made 2 calls", len(calls3) == 2 and calls3[1][1] is True)
search._CREDGOO_REFRESH_COOLDOWN_S = 3600

# ── 4. first call raises (network) → refetch succeeds ──
reset_cooldown()
calls = []


def raiser(nocache):
    if not nocache:
        raise OSError("read timed out")
    return "RECOVERED"


run(calls, raiser)
check("network error then refresh returns key", search._key_with_refresh("S") == "RECOVERED")
check("error path forced no_cache on retry", len(calls) == 2 and calls[1][1] is True)

# ── 5. both raise → None, never propagates ──
reset_cooldown()
calls = []
run(calls, lambda nocache: (_ for _ in ()).throw(OSError("down")))
check("both fail returns None (no raise)", search._key_with_refresh("S") is None)

# ── 6. the public resolvers use the refreshing path ──
reset_cooldown()
calls = []
run(calls, lambda nocache: None if not nocache else "https://host/api/duck")
import os
os.environ.pop("DUCK_API_URL", None)
check("_resolve_url goes through refresh", search.get_duck_api_url() == "https://host/api/duck")

print("")
print(f"PASS={PASS} FAIL={FAIL}")
sys.exit(0 if FAIL == 0 else 1)
