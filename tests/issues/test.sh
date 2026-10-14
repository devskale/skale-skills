#!/usr/bin/env bash
# issues test suite
#   bash tests/issues/test.sh
set -uo pipefail
cd "$(dirname "$0")/../.."

SKILL=skills/issues
SCRIPT="$PWD/$SKILL/issues"
PASS=0; FAIL=0

ok()   { PASS=$((PASS+1)); }
bad()  { FAIL=$((FAIL+1)); echo "  FAIL: $1" >&2; }

# run_in <dir> <args...> — run the CLI from a dir (project resolution walks up).
# Output is CAPTURED (var or grep on the captured string), never piped live into
# `grep -q`: with `set -o pipefail`, a `run_in … | grep -q` pipeline dies with
# SIGPIPE (141) once grep exits after its first match — the `&& ok` after it
# silently never runs.
run_in() { local d="$1"; shift; (cd "$d" && "$SCRIPT" "$@" 2>&1); }

echo "issues tests"
echo "------------"

# ── structure ──────────────────────────────────────────────────────────────
[ -f "$SKILL/SKILL.md" ] && ok || bad "SKILL.md missing"
[ -f "$SKILL/install.sh" ] && ok || bad "install.sh missing"
[ -f "$SKILL/install.bat" ] && ok || bad "install.bat missing"
[ -x "$SCRIPT" ] && ok || bad "issues not executable"
[ -f "$SKILL/.gitignore" ] && ok || bad ".gitignore missing"
[ "$(wc -l < "$SKILL/SKILL.md" | tr -d ' ')" -le 99 ] && ok || bad "SKILL.md over 99 lines — disclose detail to references/ (progressive disclosure), don't compress"
# launcher conventions (CODING_RULES): symlink resolution, --update/--selfcheck, auto-update
grep -q 'BASH_SOURCE\[0\]' "$SCRIPT" && ok || bad "launcher must resolve symlinks via BASH_SOURCE[0]"
grep -q -- '--update|--self-update)' "$SCRIPT" && ok || bad "launcher must support --update"
grep -q -- '--selfcheck)' "$SCRIPT" && ok || bad "launcher must support --selfcheck"
grep -q 'GIT_ROOT' "$SCRIPT" && ok || bad "launcher must walk up to GIT_ROOT (cwd-independent auto-update)"
grep -q '\.last-update' "$SCRIPT" && ok || bad "launcher must write .last-update"
bash -n "$SCRIPT" && ok || bad "bash -n syntax check failed"

# ── sandbox board (isolated ISSUES_DIR + fake repo with .handoff) ──────────
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT
export ISSUES_DIR="$TEST_ROOT/works"            # the shared works root (single dir — no separate bundle since 1.4.0)
export ISSUES_WORK_DIR="$TEST_ROOT/works"
export ISSUES_THROWAY_BASE="https://invalid.invalid"   # tests stay offline — bootstrap pull/push must fail into their NOTE branches
REPO="$TEST_ROOT/repo"
mkdir -p "$REPO/.git"                     # repo marker — init refuses non-repo roots (walk-up trap guard)

# init: 5 columns + container link (idempotent; default name .work)
echo "$(run_in "$REPO" init testproj)" | grep -q "board:" && ok || bad "init did not report board"
[ -d "$TEST_ROOT/works/testproj/issues/backlog" ] && ok || bad "backlog column missing after init"
[ -L "$REPO/.work" ] && ok || bad ".work symlink missing after init"
# works root: repo link points DIRECTLY at the works entry (no bundle indirection since 1.4.0)
[ "$(readlink "$REPO/.work")" = "$TEST_ROOT/works/testproj" ] && ok || bad "repo .work must point at the works entry"
ls "$TEST_ROOT/works/testproj/issues/backlog" >/dev/null 2>&1 && ok || bad "works entry must resolve to the board"
run_in "$REPO" init testproj >/dev/null && ok || bad "init not idempotent (2nd run failed)"

# happy path: new → start → review → done
echo "$(run_in "$REPO" new happy-path)" | grep -q "backlog/happy-path.md" && ok || bad "new did not create in backlog"
grep -q "^state: OPEN" "$TEST_ROOT/works/testproj/issues/backlog/happy-path.md" && ok || bad "new must stamp state OPEN"
echo "$(run_in "$REPO" start happy-path)" | grep -q "WIP" && ok || bad "start did not set WIP"
[ -f "$TEST_ROOT/works/testproj/issues/active/happy-path.md" ] && ok || bad "start did not move to active/"
echo "$(run_in "$REPO" review happy-path)" | grep -q "FOR_REVIEW" && ok || bad "review did not set FOR_REVIEW"
echo "$(run_in "$REPO" done happy-path)" | grep -q "DONE" && ok || bad "done did not set DONE"
[ -f "$TEST_ROOT/works/testproj/issues/archive/happy-path.md" ] && ok || bad "done did not move to archive/"
# regression: done <slug> must SET DONE, not list archive
grep -q "^state: DONE" "$TEST_ROOT/works/testproj/issues/archive/happy-path.md" && ok || bad "done <slug> must set state DONE (regression: was 'ls archive')"

# board / ls / show (live issue present so ls has something to list)
run_in "$REPO" new live-one >/dev/null
out=$(run_in "$REPO" board); echo "$out" | grep -q "total" && ok || bad "board did not print total"
out=$(run_in "$REPO" ls --tsv); echo "$out" | grep -q "live-one" && ok || bad "ls --tsv missing live issue"
out=$(run_in "$REPO" ls all --tsv); echo "$out" | grep -q "happy-path" && ok || bad "ls all --tsv missing archived issue"
out=$(run_in "$REPO" show happy-path); echo "$out" | grep -q "^state: DONE" && ok || bad "show did not print issue"
out=$(run_in "$REPO" ls --json); echo "$out" | grep -q '"slug"' && ok || bad "ls --json broken"

# ── regression: flag without value must die cleanly (was: unbound variable) ─
for flag in --module --triage --to --from --state --sort; do
    out=$(run_in "$REPO" ls "$flag" ""); rc=$?
    # empty value arg: ls_opts must not crash with 'unbound variable'
    echo "$out" | grep -q "unbound variable" && bad "ls $flag crashed with unbound variable (regression)" || ok
done
out=$(run_in "$REPO" ls --module); rc=$?
[ "$rc" -eq 1 ] && [ "${out#issues: }" != "$out" ] && ok || bad "ls --module (no value) must die with 'issues: … needs a value', got rc=$rc: $out"
out=$(run_in "$REPO" board-html --out); rc=$?
[ "$rc" -eq 1 ] && echo "$out" | grep -q "needs a value" && ok || bad "board-html --out (no value) must die cleanly"

# ── regression: bad slugs must be rejected (was: silently accepted, broke rows) ─
for slug in "test|pipe" "test space" "test/slash" "$(printf 'test\ttab')"; do
    out=$(run_in "$REPO" new "$slug"); rc=$?
    [ "$rc" -eq 1 ] && echo "$out" | grep -q "bad slug" && ok || bad "new must reject slug '$slug' (regression: pipe/tab/space/slash break rows)"
done
# no stray files created by rejected slugs (happy-path is archived; live-one is the only live .md)
n=$(find "$TEST_ROOT/works/testproj/issues" -name "*.md" | wc -l | tr -d ' ')
[ "$n" -eq 2 ] && ok || bad "rejected slugs must not create files (found $n .md files)"

# duplicate slug in LIVE columns → loud refusal (archive/ + live may coexist by design)
cp "$TEST_ROOT/works/testproj/issues/backlog/live-one.md" "$TEST_ROOT/works/testproj/issues/active/live-one.md"
out=$(run_in "$REPO" show live-one); rc=$?
[ "$rc" -eq 1 ] && echo "$out" | grep -q "duplicate slug" && ok || bad "duplicate live slug must die loudly (live_dup_guard)"
rm "$TEST_ROOT/works/testproj/issues/active/live-one.md"

# set with bad state
out=$(run_in "$REPO" set happy-path BLOED); rc=$?
[ "$rc" -eq 1 ] && echo "$out" | grep -q "bad state" && ok || bad "set must reject bad state"

# cancel without a reason must still exit 0 (regression: trailing `[ $# -gt 0 ] && {…}` returned 1)
run_in "$REPO" new cancel-noreason >/dev/null
run_in "$REPO" cancel cancel-noreason >/dev/null && ok || bad "cancel <slug> without reason must exit 0 (regression: function returned 1)"
grep -q "^state: CANCELLED" "$TEST_ROOT/works/testproj/issues/cancelled/cancel-noreason.md" && ok || bad "cancel-noreason not in cancelled/ with CANCELLED"
# cancel with reason: reason appended, exit 0
run_in "$REPO" new cancel-reason >/dev/null
run_in "$REPO" cancel cancel-reason "duplicate of other" >/dev/null && ok || bad "cancel <slug> <reason> must exit 0"
grep -q "duplicate of other" "$TEST_ROOT/works/testproj/issues/cancelled/cancel-reason.md" && ok || bad "cancel reason not appended"

# purge: interactive abort (n) and forced (-y)
run_in "$REPO" new purge-me >/dev/null
run_in "$REPO" done purge-me >/dev/null
echo "n" | run_in "$REPO" purge >/dev/null
[ -f "$TEST_ROOT/works/testproj/issues/archive/purge-me.md" ] && ok || bad "purge aborted (n) must keep the file"
echo "$(run_in "$REPO" purge -y purge-me)" | grep -q "1 purged" && ok || bad "purge -y did not purge"
[ ! -f "$TEST_ROOT/works/testproj/issues/archive/purge-me.md" ] && ok || bad "purged file still exists"

# board-html: renders + escapes (live issue present so it has something to render)
out=$(run_in "$REPO" board-html --out "$TEST_ROOT/board.html" --title '<script>x</script>')
[ -f "$TEST_ROOT/board.html" ] && ok || bad "board-html did not write output"
grep -q '<script>x</script>' "$TEST_ROOT/board.html" && bad "board-html title not HTML-escaped (XSS)" || ok

# doctor: fresh nonexistent root, no container link → problems reported, exit 1
# (ISSUES_DIR points at a path that does NOT exist yet — the suite's own root
# was already created by init, so use a fresh subdir)
DOCTOR_DIR="$TEST_ROOT/doctor-cwd"
mkdir -p "$DOCTOR_DIR"
DOCTOR_ROOT="$TEST_ROOT/doctor-handoffs"
out=$(ISSUES_DIR="$DOCTOR_ROOT" run_in "$DOCTOR_DIR" doctor); rc=$?
[ "$rc" -eq 1 ] && ok || bad "doctor must exit 1 when problems found (rc=$rc)"
echo "$out" | grep -q "synced root missing" && ok || bad "doctor must warn about missing root"
echo "$out" | grep -q "no git history in root" && ok || bad "doctor must warn about missing versioning"
echo "$out" | grep -q "problem(s)" && ok || bad "doctor must report problem count"
# legacy compat: a repo with only an old-name .handoff link still resolves
LEGACY_RE="$TEST_ROOT/legacy-repo"; mkdir -p "$LEGACY_RE/.git"
ln -s "$TEST_ROOT/works/testproj" "$LEGACY_RE/.handoff"
out=$(run_in "$LEGACY_RE" board)
echo "$out" | grep -q "project: testproj" && ok || bad "legacy .handoff link must still resolve (got: $out)"

# init migrates a legacy link to the configured name
out=$(run_in "$LEGACY_RE" init testproj)
[ -L "$LEGACY_RE/.work" ] && [ ! -e "$LEGACY_RE/.handoff" ] && ok || bad "init must migrate legacy .handoff → .work"

# ISSUES_LINK_NAME env: init creates the configured name
ENVNAME_RE="$TEST_ROOT/envname-repo"; mkdir -p "$ENVNAME_RE/.git"
out=$(ISSUES_LINK_NAME=.tasks run_in "$ENVNAME_RE" init testproj)
[ -L "$ENVNAME_RE/.tasks" ] && ok || bad "ISSUES_LINK_NAME must drive the created link name"
out=$(ISSUES_LINK_NAME=.tasks run_in "$ENVNAME_RE" board)
echo "$out" | grep -q "project: testproj" && ok || bad "walk-up must honor ISSUES_LINK_NAME"

# --fix: creates missing columns + pins identity (HANDOFF_ME unset, ~/.handoff-me absent → hostname)
# run inside REPO after removing one column
rmdir "$TEST_ROOT/works/testproj/issues/review"
out=$(run_in "$REPO" doctor --fix); rc=$?
[ -d "$TEST_ROOT/works/testproj/issues/review" ] && ok || bad "doctor --fix must recreate missing column"
echo "$out" | grep -q "created missing columns" && ok || bad "doctor --fix must report created columns"
# unknown flag dies cleanly
out=$(run_in "$REPO" doctor --bogus); rc=$?
[ "$rc" -eq 1 ] && echo "$out" | grep -q "unknown doctor flag" && ok || bad "doctor --bogus must die cleanly"

# help (capture first — help output is large; echo|grep -q can SIGPIPE under pipefail)
out=$(run_in "$REPO" help); echo "$out" | grep -q "TROUBLESHOOTING" && ok || bad "help missing TROUBLESHOOTING section"
echo "$out" | grep -q "done <slug>" && ok || bad "help must document done <slug>"

# launcher flags
out=$(run_in "$REPO" --selfcheck); echo "$out" | grep -q "selfcheck" && ok || bad "--selfcheck broken"

echo
echo "PASS: $PASS  FAIL: $FAIL"
[ "$FAIL" -eq 0 ]

# ── works bootstrap: no shared works dir → pull attempt (offline → NOTE, not fatal) ──
BOOT_RE="$TEST_ROOT/boot-repo"; mkdir -p "$BOOT_RE/.git"
rm -rf "$TEST_ROOT/works"                      # simulate: no shared works root on this machine
out=$(ISSUES_THROWAY_BASE="https://invalid.invalid" run_in "$BOOT_RE" init bootproj); rc=$?
[ "$rc" -eq 0 ] && ok || bad "init must survive a failed bootstrap pull (rc=$rc)"
[ -d "$TEST_ROOT/works" ] && ok || bad "init must create the works dir even without a snapshot"
echo "$out" | grep -q "no snapshot\|starting empty" && ok || bad "init must report the empty-bootstrap NOTE"
# ── works bootstrap: works dir present → push attempt (offline → NOTE, not fatal) ──
out=$(ISSUES_THROWAY_BASE="https://invalid.invalid" run_in "$BOOT_RE" init bootproj); rc=$?
[ "$rc" -eq 0 ] && ok || bad "init must survive a failed bootstrap push (rc=$rc)"
echo "$out" | grep -q "could not push" && ok || bad "init must report the failed push NOTE"

# ── init outside a repo: refuse (a link at a non-repo root is a walk-up trap) ──
NOREPO="$TEST_ROOT/no-repo"; mkdir -p "$NOREPO"
out=$(run_in "$NOREPO" init testproj 2>&1); rc=$?
[ "$rc" -ne 0 ] && ok || bad "init outside a repo must fail (rc=$rc)"
[ ! -e "$NOREPO/.work" ] && ok || bad "init outside a repo must not plant .work"
echo "$out" | grep -q "no repo root" && ok || bad "init must explain the repo-root refusal"
