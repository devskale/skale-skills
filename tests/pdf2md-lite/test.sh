#!/usr/bin/env bash
# pdf2md test suite
#   bash tests/pdf2md/test.sh
# Live conversion needs a reachable API + token (credgoo FETCH_URL_BEARER);
# without them those checks WARN honestly. The llamaparse scan path uploads
# the document to LlamaCloud and costs credits — opt in: PDF2MD_TEST_SCAN=1.
set -uo pipefail
cd "$(dirname "$0")/../.."
ROOT=$(pwd)

SKILL=skills/pdf2md-lite
SCRIPT="$SKILL/pdf2md"
PY="$SKILL/scripts/pdf2md.py"
PASS=0; FAIL=0; WARN=0

ok()   { PASS=$((PASS+1)); }
bad()  { FAIL=$((FAIL+1)); echo "  FAIL: $1" >&2; }
warn() { WARN=$((WARN+1)); echo "  WARN (network-dependent, skipped honestly): $1" >&2; }

check() { # check <desc> <expected-exit> <cmd...>
    local desc="$1" want="$2"; shift 2
    "$@" >/tmp/pdf2md.out 2>&1
    local got=$?
    if [ "$got" -eq "$want" ]; then ok; else bad "$desc (want exit $want, got $got)"; fi
}

echo "pdf2md tests"
echo "-------------"

# structure (house convention: SKILL.md, install.sh, install.bat, .gitignore, launcher)
[ -f "$SKILL/SKILL.md" ] && ok || bad "SKILL.md missing"
[ -f "$SKILL/install.sh" ] && ok || bad "install.sh missing"
[ -f "$SKILL/install.bat" ] && ok || bad "install.bat missing"
[ -f "$SKILL/.gitignore" ] && ok || bad ".gitignore missing"
[ -f "$SKILL/pyproject.toml" ] && ok || bad "pyproject.toml missing"
[ -f "$PY" ] && ok || bad "scripts/pdf2md.py missing"
[ -x "$SCRIPT" ] && ok || bad "launcher not executable"
grep -q 'GIT_ROOT=' "$SCRIPT" && ok || bad "launcher must resolve enclosing git root (GIT_ROOT)"
grep -q 'GIT_ROOT/.git' "$SCRIPT" && ok || bad "auto-update guard must use GIT_ROOT/.git"

# frontmatter: name + version, version aligned with pyproject
head -1 "$SKILL/SKILL.md" | grep -q '^---$' && ok || bad "SKILL.md missing frontmatter"
grep -q '^name: pdf2md-lite' "$SKILL/SKILL.md" && ok || bad "frontmatter name: pdf2md"
grep -q '^description:' "$SKILL/SKILL.md" && ok || bad "frontmatter description missing"
FMV=$(grep -m1 '^version:' "$SKILL/SKILL.md" | grep -o '[0-9][0-9.]*')
PYV=$(grep -m1 '^version' "$SKILL/pyproject.toml" | grep -o '[0-9][0-9.]*')
[ -n "$FMV" ] && [ "$FMV" = "$PYV" ] && ok || bad "version mismatch SKILL.md($FMV) vs pyproject($PYV)"

# progressive disclosure: lean SKILL.md, details in linked references/
LINES=$(wc -l < "$SKILL/SKILL.md")
[ "$LINES" -le 100 ] && ok || bad "SKILL.md too long: $LINES lines (house rule: <100)"
[ -f "$SKILL/references/api.md" ] && ok || bad "references/api.md missing"
grep -q 'references/api.md' "$SKILL/SKILL.md" && ok || bad "SKILL.md does not link references/api.md"

# gitignore guards the venv (pi package updates run git clean -fdx)
grep -q '^\.venv/$' "$SKILL/.gitignore" && ok || bad ".gitignore misses .venv/"
grep -q '^\.last-update$' "$SKILL/.gitignore" && ok || bad ".gitignore misses .last-update"
git check-ignore -q "$SKILL/.last-update" && ok || bad ".last-update not ignored"

# usage / error exits (offline-safe: file check runs before token resolve)
check "no args → exit 2" 2 "$SCRIPT"
check "--help → exit 0" 0 "$SCRIPT" --help
check "missing file → exit 1" 1 "$SCRIPT" /nonexistent.pdf
check "unknown flag → exit 2" 2 "$SCRIPT" --bogus /nonexistent.pdf

# size guard: an oversized file is rejected by stat, not by reading it into RAM
# (regression: convert() used to open()+read() first — a 2GB file was buffered
# before the 10MB check fired). Empty files get their own clean error.
BIG=$(mktemp)
dd if=/dev/zero of="$BIG" bs=1024 count=11264 2>/dev/null   # 11 MB > 10 MB limit
check "oversized file → exit 1" 1 "$SCRIPT" "$BIG"
grep -q "larger than 10MB" /tmp/pdf2md.out && ok || bad "oversized message lacks the limit"
EMPTY=$(mktemp)
check "empty file → exit 1" 1 "$SCRIPT" "$EMPTY"
grep -q "is empty" /tmp/pdf2md.out && ok || bad "empty-file message missing"
rm -f "$BIG" "$EMPTY"

# path handling: relative paths + ~ expansion resolve against the caller's cwd
( cd /tmp && "$ROOT/$SCRIPT" pdf2md-rel-missing.pdf >/tmp/pdf2md.out 2>&1 )
[ $? -eq 1 ] && ok || bad "missing relative file → exit 1"
"$SCRIPT" '~/pdf2md-nonexistent.pdf' >/tmp/pdf2md.out 2>&1
[ $? -eq 1 ] && grep -q "$HOME/pdf2md-nonexistent.pdf" /tmp/pdf2md.out && ok \
    || bad "~/ in arguments not expanded"

# launcher flags (convention: --update/--selfcheck)
check "--selfcheck → exit 0" 0 "$SCRIPT" --selfcheck
grep -q "pdf2md v" /tmp/pdf2md.out && ok || bad "selfcheck shows version"
grep -q "dir:" /tmp/pdf2md.out && ok || bad "selfcheck shows dir"
check "--update → exit 0" 0 "$SCRIPT" --update
grep -q "Updated" /tmp/pdf2md.out && ok || bad "--update reports Updated"
[ -f "$SKILL/.last-update" ] && ok || bad "stamp file created"

# token available? (env wins, then credgoo)
TOKEN=no
[ -n "${PDF2MD_BEARER:-}" ] || [ -n "${FETCH_URL_BEARER:-}" ] && TOKEN=env
if [ "$TOKEN" = no ] && command -v credgoo >/dev/null 2>&1; then
    [ -n "$(credgoo FETCH_URL_BEARER 2>/dev/null | head -1)" ] && TOKEN=credgoo
fi

# live smoke: text-layer PDF via pdfplumber (no cloud OCR cost)
FIXTXT=/tmp/pdf2md-fixture.txt
FIXPDF=/tmp/pdf2md-fixture.pdf
if [ "$TOKEN" = no ]; then
    warn "live conversion skipped (no token: PDF2MD_BEARER/FETCH_URL_BEARER/credgoo)"
else
    printf 'Skale pdf2md Funktionstest\nZeile zwei mit Umlauten: Aoeuess.\n' > "$FIXTXT"
    cupsfilter "$FIXTXT" > "$FIXPDF" 2>/dev/null
    if [ ! -s "$FIXPDF" ]; then
        warn "live conversion skipped (cannot build PDF fixture via cupsfilter)"
    else
        check "live convert → exit 0" 0 "$SCRIPT" "$FIXPDF" --out /tmp/pdf2md-out.md
        if [ -s /tmp/pdf2md-out.md ]; then
            ok
            grep -q "Funktionstest" /tmp/pdf2md-out.md && ok || bad "markdown lacks fixture text"
        else
            bad "live conversion produced empty output"
        fi
        check "live convert --method pdfplumber → exit 0" 0 \
            "$SCRIPT" "$FIXPDF" --method pdfplumber --out /tmp/pdf2md-out2.md

        # relative in+out resolve against the caller's cwd, not the skill dir
        TESTCWD=$(mktemp -d)
        cp "$FIXPDF" "$TESTCWD/rel.pdf"
        ( cd "$TESTCWD" && "$ROOT/$SCRIPT" rel.pdf --out rel-out.md ) >/tmp/pdf2md.out 2>&1
        [ -s "$TESTCWD/rel-out.md" ] && ok || bad "relative paths don't resolve against caller cwd"
        rm -rf "$TESTCWD"

        # robustness: network timeout → clean error, never a traceback
        # (blackhole address + tiny timeout; PDF2MD_URL is a supported override)
        PDF2MD_URL="http://10.255.255.1:9/" timeout 30 \
            "$SCRIPT" "$FIXPDF" --timeout 2 >/tmp/pdf2md.out 2>&1
        got=$?
        [ "$got" -eq 1 ] && ok || bad "blackhole timeout exit (want 1, got $got)"
        grep -q "Traceback" /tmp/pdf2md.out && bad "timeout leaked a traceback" || ok
        grep -q "retry with a higher --timeout" /tmp/pdf2md.out && ok \
            || bad "timeout message lacks retry hint"
    fi
fi

# --share on an async job: the URL is printed, the markdown NOT downloaded
# (regression: wait_job downloaded the shared result before main() could see
# --share, transferring the whole document for nothing). Mocked API: 202 job ->
# done with markdown_url; the mock COUNTS downloads of that URL.
if command -v python3 >/dev/null 2>&1; then
    # The mock needs a real PDF but NO token — build the fixture independently of
    # the live-token block above (which only runs when a token exists).
    if [ ! -s "$FIXPDF" ]; then
        printf 'Skale pdf2md share-path test\nZeile zwei.\n' > "$FIXTXT"
        cupsfilter "$FIXTXT" > "$FIXPDF" 2>/dev/null
    fi
    if [ ! -s "$FIXPDF" ]; then
        warn "share-path mock skipped (cannot build PDF fixture)"
    else
    MOCKDIR=$(mktemp -d)
    cat > "$MOCKDIR/mock_api.py" <<'MOCK'
import http.server, json, sys, threading

PORT = int(sys.argv[1])
HITS = {"downloads": 0}

class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_POST(self):
        n = int(self.headers.get("Content-Length", 0))
        self.rfile.read(n)
        body = json.dumps({"job_id": "job-test-123", "status": "queued", "poll": "/pdf/jobs/job-test-123"}).encode()
        self.send_response(202)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers(); self.wfile.write(body)
    def do_GET(self):
        # count ONLY the markdown download, not the job polls
        if not self.path.startswith("/pdf/jobs/"):
            HITS["downloads"] += 1
        if self.path.startswith("/pdf/jobs/"):
            body = json.dumps({"status": "done", "markdown_url": f"http://127.0.0.1:{PORT}/md", "expires_in": 7200}).encode()
            self.send_response(200)
        else:  # the markdown_url itself
            HITS["downloads"] += 1
            body = b"# shared markdown that must NOT be fetched with --share"
            self.send_response(200)
        self.send_header("Content-Type", "application/json" if self.path.startswith("/pdf/jobs/") else "text/plain")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers(); self.wfile.write(body)

import signal
def _bye(*_):
    print("DOWNLOADS=%d" % HITS["downloads"], file=sys.stderr, flush=True)
    raise SystemExit(0)
signal.signal(signal.SIGTERM, _bye)
srv = http.server.HTTPServer(("127.0.0.1", PORT), H)
threading.Thread(target=srv.serve_forever, daemon=True).start()
print("ready", flush=True)
import time, atexit
atexit.register(lambda: print("DOWNLOADS=%d" % HITS["downloads"], file=sys.stderr, flush=True))
time.sleep(60)
MOCK
    python3 "$MOCKDIR/mock_api.py" 8731 >"$MOCKDIR/ready" 2>&1 &
    MOCKPID=$!
    for _ in $(seq 1 40); do grep -q ready "$MOCKDIR/ready" 2>/dev/null && break; sleep 0.25; done
    if grep -q ready "$MOCKDIR/ready" 2>/dev/null; then
        # the mock answers 202 -> pdf2md polls -> done with markdown_url.
        # With --share it must print the URL and NOT download the markdown.
        PDF2MD_URL="http://127.0.0.1:8731/pdf/to_md" PDF2MD_BEARER="test-token" \
            "$SCRIPT" "$FIXPDF" --share --no-wait --timeout 30 >"$MOCKDIR/out" 2>&1
        got=$?
        [ "$got" -eq 0 ] && ok || bad "--share async job exit (want 0, got $got): $(head -2 "$MOCKDIR/out")"
        grep -q "http://127.0.0.1:8731/md" "$MOCKDIR/out" && ok || bad "--share did not print the URL"
        grep -q "shared markdown that must NOT be fetched" "$MOCKDIR/out" && bad "--share downloaded the markdown anyway" || ok
    else
        warn "share-path mock could not start — skipped"
    fi
    # the mock reports its markdown-download counter on SIGTERM — read it AFTER
    # the kill, otherwise we grep before the handler flushed.
    kill -TERM $MOCKPID 2>/dev/null
    for _ in $(seq 1 20); do grep -q "DOWNLOADS=" "$MOCKDIR/ready" 2>/dev/null && break; sleep 0.1; done
    if grep -q "DOWNLOADS=0" "$MOCKDIR/ready" 2>/dev/null; then
        ok "share-path mock ran (download counter available)"
        ok "--share did not fetch the markdown URL"
    elif grep -q "DOWNLOADS=[1-9]" "$MOCKDIR/ready" 2>/dev/null; then
        bad "--share fetched the markdown URL (DOWNLOADS>0)"
    else
        warn "share-path mock counter unavailable — download check skipped"
    fi
    kill $MOCKPID 2>/dev/null
    rm -rf "$MOCKDIR"
    fi
else
    warn "python3 missing — share-path mock skipped"
fi

# SSE unit tests (no network): _sse_wait contract — every failure mode
# returns None so polling takes over; SSE never breaks a conversion.
if command -v python3 &>/dev/null && [ -f "tests/pdf2md/test_unit.py" ]; then
    if OUT=$(python3 "tests/pdf2md/test_unit.py" 2>&1); then
        check "sse unit tests (FAIL=0)" 0 true
    else
        check "sse unit tests" 1 false
        echo "$OUT" | sed 's/^/    /' >&2
    fi
    check "sse helper present" 0 grep -q "_sse_wait" "$PY"
    check "poll fallback kept" 0 grep -q "_poll_wait" "$PY"
    check "kill switch documented" 0 grep -q "PDF2MD_NO_SSE" "$PY"
else
    warn "python3 or test_unit.py missing — SSE unit tests skipped"
fi

# scan path (llamaparse) — uploads to LlamaCloud + costs credits; opt-in only
if [ "${PDF2MD_TEST_SCAN:-0}" = "1" ]; then
    if [ "$TOKEN" != no ] && [ -s "$FIXPDF" ]; then
        check "live llamaparse → exit 0" 0 "$SCRIPT" "$FIXPDF" --method llamaparse -v
    else
        warn "scan test skipped (no token or fixture)"
    fi
else
    warn "llamaparse scan path not exercised (opt in: PDF2MD_TEST_SCAN=1)"
fi

echo
echo "PASS=$PASS FAIL=$FAIL WARN=$WARN"
[ "$FAIL" -eq 0 ]
