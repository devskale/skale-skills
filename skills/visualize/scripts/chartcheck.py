#!/usr/bin/env python3
"""Dataviz integrity checks for visualize HTML pages (evident-charts influence).

What this checks — and what it deliberately cannot. Every check must be provable
from the rendered markup alone, because that is all a self-contained HTML page
gives us. evident-charts lints the *chart script* against the *data*; we lint
the *page* against itself. That boundary is load-bearing: a data-integrity
check (does the total equal the sum of the parts?) needs the data, not the page,
so those rules stay in the data layer, not here.

Checks (each reports PASS-style evidence, FAIL blocks, WARN advises):
  bar-baseline      bars whose width∝value imply a zero origin; a page that
                    draws bars from a non-zero floor (or a log scale it never
                    says) is the classic lie
  log-unlabeled     a log scale in the markup, never stated in the visible text
  process-note      chart text addressed to the user ("TODO", "confirm",
                    "inferred") or a data file name standing in for a source
  missing-source    no "Source:"/"Data:" line naming a publisher + dataset
  value-and-axis    value labels on marks while a numeric value axis is also
                    present (says the number twice)
  equal-height-3d   3D/perspective tell on 1D/2D data (transform: perspective,
                    rotateX/rotateY on bar containers)
  redundant-legend  a legend AND direct labels on the same marks (pick one)

Each check names the element (selector or excerpt) it is about. An unreadable
chart is a P1; a chart that misleads is a P0 — the exit code only splits
block-vs-advise, severity is the reviewer's call.
"""

from __future__ import annotations

import re
import sys
from html.parser import HTMLParser
from typing import NamedTuple

Block = NamedTuple("Block", [("check", str), ("where", str), ("msg", str)])


class Page(HTMLParser):
    """Minimal DOM: text nodes, visible text per element, and bar/axis markup."""

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.text: list[str] = []
        self.tags: list[tuple[str, dict[str, str]]] = []
        self._skip = 0

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        a = {k: (v or "") for k, v in attrs}
        self.tags.append((tag, a))
        if tag in ("style", "script"):
            self._skip += 1

    def handle_endtag(self, tag: str) -> None:
        if tag in ("style", "script") and self._skip:
            self._skip -= 1

    def handle_data(self, data: str) -> None:
        if self._skip:
            return
        t = data.strip()
        if t:
            self.text.append(t)

    @property
    def all_text(self) -> str:
        return " ".join(self.text)


# ── text patterns (sourced from evident-charts SRC-2 / TI-1) ──────────────
PROCESS_NOTE = re.compile(
    r"\b(todo|fixme|confirm|verify this|check this|inferred|implied|placeholder|"
    r"note to self|don'?t forget|xxx)\b",
    re.I,
)
# a bare file name standing in for a publisher/dataset
FILE_SOURCE = re.compile(r"\b\w+\.(csv|tsv|xlsx?|json|parquet|py|r)\b", re.I)
# a source note anywhere in the visible text (evident-charts: "no text
# contains 'Source:'") - not only at line start, a note may read "value - source: X"
SOURCE_LINE = re.compile(r"\b(?:source|data)\s*[:|]", re.I)
LOG_MENTION = re.compile(r"\blog\s*\(?\s*(scale|axis|skala|achse)", re.I)


def check_bar_baseline(p: Page, raw: str) -> list[Block]:
    """Bars drawn as width% must imply a zero origin; flag a stated non-zero floor.

    Careful about what counts as an axis floor: a data maximum (a note like
    "max = 120") is the *denominator* of the lie factor, not the scale origin -
    width proportional to value/max still starts at zero. Only an explicit
    scale origin counts: axis-min, ymin, baseline, domain.
    """
    out: list[Block] = []
    widths = [float(m) for m in re.findall(r"style=\"[^\"]*width\s*:\s*([\d.]+)%", raw)]
    # A pure CSS bar (width % of value/max) always starts at zero, so a CSS-only
    # page cannot lie on this axis - the check can only fire where the page
    # declares a scale (SVG axis, chart-lib config) or says so in text.
    scale_keys = r"(?:axis[-_]?(?:min|max|base(?:line)?)|ymin|ymax|baseline|origin|domain)"
    # no left guard: the key may be a data-*/aria-* attribute (data-axis-min)
    floors = [float(f) for f in
              re.findall(rf"(?:{scale_keys})\s*[=:]\s*[\"']?(-?[\d.]+)", raw, re.I)]
    # Explicit note that the axis is truncated. Anchored on the verb so a
    # comment saying "never truncated" cannot trip it.
    if re.search(r"(?:axis[- ]break|truncat(?:ed|ing)\s+(?:axis|bar|scale)|"
                 r"bars?\s+start(?:s|ing)?\s+(?:at|above|non-?zero))", raw, re.I):
        out.append(Block("bar-baseline", "page", "chart states a truncated/non-zero bar baseline"))
    has_marks = bool(widths) or bool(re.search(r"<svg", raw, re.I))
    if has_marks and any(f > 0 for f in floors):
        bad = next(f for f in floors if f > 0)
        out.append(Block("bar-baseline", "axis",
                         f"axis floor {bad} with width-value bars (bars imply zero origin)"))
    return out


def check_log_scale(p: Page, raw: str) -> list[Block]:
    out: list[Block] = []
    mentions_log = bool(re.search(r"\blog\b", p.all_text, re.I))
    # a log-scaled bar/marker without the words "log" in any label/title/axis
    declares_log = re.search(r"(?:log[-_ ]?scale|scale[-_]?(?:type|kind)?\s*[=:]\s*['\"]?log\b)", raw, re.I)
    if declares_log and not mentions_log:
        out.append(Block("log-unlabeled", "page", "log scale in markup but never stated in the text"))
    return out


def check_process_notes(p: Page, raw: str) -> list[Block]:
    out: list[Block] = []
    for t in p.text:
        m = PROCESS_NOTE.search(t)
        if m:
            out.append(Block("process-note", "text", f"addressed to the user: {m.group(0)!r} — “{t[:50]}”"))
    for m in FILE_SOURCE.finditer(p.all_text):
        out.append(Block("process-note", "source", f"file name standing in for a source: {m.group(0)!r}"))
    return out


def check_source(p: Page, raw: str) -> list[Block]:
    if not SOURCE_LINE.search(p.all_text):
        return [Block("missing-source", "page", "no 'Source:'/'Data:' line naming the publisher + dataset")]
    return []


def check_value_and_axis(p: Page, raw: str) -> list[Block]:
    """Value labels on marks AND a numeric value axis = the number said twice."""
    has_val_labels = bool(re.search(r"class=\"[^\"]*val", raw))
    has_axis = bool(re.search(r"axis[-_]?(?:min|max|ticks?|label)", raw, re.I))
    if has_val_labels and has_axis:
        return [Block("value-and-axis", "page", "value labels on marks while a numeric value axis is also present")]
    return []


def check_3d(p: Page, raw: str) -> list[Block]:
    if re.search(r"perspective\s*:\s*\d|rotate[XY3d]|matrix3d", raw, re.I):
        return [Block("equal-height-3d", "page", "3D/perspective transform on 1D/2D data distorts values")]
    return []


def check_legend_labels(p: Page, raw: str) -> list[Block]:
    if re.search(r"class=\"[^\"]*legend", raw, re.I) and re.search(r"class=\"[^\"]*\bval\b", raw):
        return [Block("redundant-legend", "page", "legend AND direct value labels on the same marks — pick one")]
    return []


# A chart page draws data marks. Without one there is no data being
# misrepresented, so the source-note and axis rules would fire on ordinary
# pages (a report, a timeline, a repo tree) — noise, not a gate.
# A data chart, not any diagram: an architecture mermaid graph or a plain
# inline svg is a drawing without a data series, and demanding a publisher for
# it would be noise. Marks = value-encoded bars/lines/points or a chart lib.
CHART_MARK = re.compile(
    r"class=\"[^\"]*\b(?:bar|bars|bar-row|chart|plot|sparkline|histogram|"
    r"heat ?map|bubble|scatter|series|dataviz|data-?bar)\b|"
    r"<svg[^>]*class=\"[^\"]*(?:chart|plot|figure|graph)|"
    r"data-(?:value|measure|series|bar|axis)|"
    r"\b(?:Chart|Plotly|vega|echarts|d3)\.(?:js|min)?\b",
    re.I,
)

CHECKS = (check_bar_baseline, check_log_scale, check_process_notes,
          check_source, check_value_and_axis, check_3d, check_legend_labels)


def run(path: str) -> int:
    raw = open(path, encoding="utf-8", errors="replace").read()
    # strip HTML comments, CSS comments and {{PLACEHOLDER}} tokens: template
    # prose and the checks' own documentation must not trip the checks.
    raw = re.sub(r"<!--.*?-->", "", raw, flags=re.S)
    raw = re.sub(r"/\*.*?\*/", "", raw, flags=re.S)
    raw = re.sub(r"\{\{.*?\}\}", " ", raw)
    p = Page()
    p.feed(raw)
    is_chart = bool(CHART_MARK.search(raw))
    blocks: list[Block] = []
    for fn in CHECKS:
        if not is_chart and fn is not check_process_notes:
            continue   # not a chart page: only process notes still apply
        blocks.extend(fn(p, raw))
    if not blocks:
        what = "dataviz integrity clean" if is_chart else "no chart on this page (nothing to check)"
        print(f"visualize chartcheck: OK — {what} (provable from markup)")
        return 0
    print(f"visualize chartcheck: {len(blocks)} finding(s):")
    for b in dict.fromkeys(blocks):
        print(f"  {b.check} | {b.where} | {b.msg}")
    print("Severity: misleading=P0, point-doesn't-land=P1. This lints the *page*;")
    print("data-integrity rules (parts≠sum, prelim months) need the data — see references/chart-integrity.md.")
    return 1


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: chartcheck <file.html>", file=sys.stderr)
        return 2
    try:
        return run(sys.argv[1])
    except OSError as e:
        print(f"visualize chartcheck: {e}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
