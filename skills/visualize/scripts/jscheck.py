#!/usr/bin/env python3
"""JS quality gate for visualize HTML pages.

Every inline <script> must parse, and no const/let may be used before its
declaration (the "Cannot access X before initialization" class of bug that once
slipped through validate — 2026-09-27).

**One extractor defines what a script block is** — for the syntax check AND the
TDZ heuristic. That single definition is the whole point: the old gate had two
(`<script[[:space:]]*>` for syntax, `<script[^>]*>` for TDZ), and the narrower
one silently skipped every attributed tag, so `<script type="module">` — the
mermaid template's own tag — was never checked. Two more holes came from the
line-based parse: code on the same line as `<script>` was dropped, and a
`</script>` on a final line without a trailing newline was never read.

Checks (exit 1 lists every failure):
  syntax   node --check per block. type="module" is checked as ESM (.mjs),
           everything else as a classic script (.js). Blocks with src= are
           fetched code, not inline code, and non-JS types (application/ld+json,
           text/template) never execute — both are skipped, not failed.
  tdz      a const/let name used as `name.on(` / `.attr(` / `.style(` /
           `.text(` / `.join(` / `.call(` textually before its declaration.

HTML comments are stripped first: a commented-out script does not run, so
flagging its syntax would be a false positive (same rule chartcheck.py uses).

Best-effort by design: without node the launcher exits 0 and says so — a page
must never be blocked by a missing tool (parity with chartcheck without python3).
"""

from __future__ import annotations

import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

BLOCK = re.compile(r"<script\b([^>]*)>(.*?)</script\s*>", re.S | re.I)
SRC_ATTR = re.compile(r"\bsrc\s*=", re.I)
TYPE_ATTR = re.compile(r"\btype\s*=\s*[\"']?([^\"'\s>]+)", re.I)
# Data, not code: JSON-LD blocks and client-side template scripts never run, so
# a JS syntax check on them is a false positive.
NON_JS = re.compile(
    r"^(?:application/(?:ld\+)?json|"
    r"text/(?:template|plain|x-handlebars|x-template|ng-template))",
    re.I,
)
TDZ_USE = r"\.(?:on|attr|style|text|join|call)\s*\("
TDZ_DECL = re.compile(r"\b(?:const|let)\s+([a-zA-Z_$][\w$]*)")


def blocks(src: str) -> list[tuple[int, str, bool]]:
    """Inline JS blocks as ``(n, code, is_module)``, in document order.

    Numbering counts only checked blocks, so a reported ``#2`` is the second
    block an author can see, not the second ``<script>`` tag in the file.
    """
    src = re.sub(r"<!--.*?-->", "", src, flags=re.S)
    out: list[tuple[int, str, bool]] = []
    for attrs, code in BLOCK.findall(src):
        if SRC_ATTR.search(attrs):
            continue
        m = TYPE_ATTR.search(attrs)
        t = (m.group(1) if m else "").strip().lower()
        if NON_JS.match(t) or not code.strip():
            continue
        out.append((len(out) + 1, code, t == "module"))
    return out


def syntax_errors(blks: list[tuple[int, str, bool]]) -> list[tuple[int, list[str]]]:
    """Run ``node --check`` on each block; return ``(n, output lines)`` on failure.

    The size assertion guards the one way this check could pass silently: a block
    that fails to reach disk reads back empty, and ``node --check`` exits 0 on an
    empty file. A gate must never turn a write failure into a green light, so a
    mismatch is reported as an error instead of an unchecked pass.
    """
    errs: list[tuple[int, list[str]]] = []
    tmp = Path(tempfile.mkdtemp(prefix="visualize-jscheck."))
    try:
        for n, code, is_module in blks:
            path = tmp / (f"block{n}.mjs" if is_module else f"block{n}.js")
            path.write_text(code, encoding="utf-8", newline="")
            if path.stat().st_size != len(code.encode("utf-8")):
                errs.append((n, ["internal: extracted block did not reach disk — refusing to pass it unchecked"]))
                continue
            r = subprocess.run(["node", "--check", str(path)],
                               capture_output=True, text=True)
            if r.returncode != 0:
                out = (r.stderr or r.stdout).strip().splitlines()[:5]
                errs.append((n, out))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    return errs


# Strings/comments blanked so braces and identifiers inside them never count.
MASK = re.compile(
    r'"(?:[^"\\\n]|\\.)*"|\'(?:[^\'\\\n]|\\.)*\'|`(?:[^`\\]|\\.)*`|//[^\n]*|/\*.*?\*/',
    re.S,
)


def tdz_issues(blks: list[tuple[int, str, bool]]) -> list[str]:
    """Use-before-declaration heuristic over the joined JS of the checked blocks.

    Scope-aware by brace depth: a use nested DEEPER than its declaration may run
    later (function body, callback, event handler) and is not flagged — that was
    a false positive that bounced valid pages (`function init(){ el.text(...) }`
    above `const el`). A use at the same or shallower depth executes immediately,
    before the declaration — flagged. Known limit: a brace-less arrow callback
    (``setTimeout(() => el.text())``) sits at the same depth and still flags; this
    is a stdlib heuristic, not a parser — the report says "you decide" material.
    """
    js = "\n".join(code for _, code, _ in blks)
    masked = []
    last = 0
    for m in MASK.finditer(js):
        masked.append(js[last:m.start()])
        masked.append(" " * (m.end() - m.start()))
        last = m.end()
    masked.append(js[last:])
    masked = "".join(masked)

    def depth_at(pos: int) -> int:
        head = masked[:pos]
        return head.count("{") - head.count("}")

    decls: dict[str, int] = {}
    for m in TDZ_DECL.finditer(js):
        decls.setdefault(m.group(1), m.start())
    issues: list[str] = []
    for name, pos in decls.items():
        decl_depth = depth_at(pos)
        for m in re.finditer(re.escape(name) + TDZ_USE, js[:pos]):
            if depth_at(m.start()) > decl_depth:
                continue   # nested deeper than the decl: may run after it
            ls = js.rfind("\n", 0, m.start()) + 1
            nl = js.find("\n", m.start())
            line = js[ls:nl if nl != -1 else len(js)]
            issues.append(f'  TDZ: "{name}" used before its declaration')
            issues.append(f"    line: {line.strip()[:80]}")
    return issues


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: jscheck <file.html>", file=sys.stderr)
        return 2
    try:
        src = Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace")
    except OSError as e:
        print(f"visualize jscheck: {e}", file=sys.stderr)
        return 2

    blks = blocks(src)
    errs = syntax_errors(blks)
    tdz = tdz_issues(blks)

    for n, lines in errs:
        print(f"visualize jscheck: ✗ script-block #{n} has a syntax error:", file=sys.stderr)
        for line in lines:
            print(f"    {line}", file=sys.stderr)
    if tdz:
        print("visualize jscheck: ✗ temporal-dead-zone violations:", file=sys.stderr)
        for t in tdz[:10]:
            print(t, file=sys.stderr)
    if errs or tdz:
        print("visualize jscheck: FAILED — fix the errors above", file=sys.stderr)
        return 1
    print(f"visualize jscheck: OK — {len(blks)} script block(s), no syntax errors, no TDZ violations")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
