# Chart integrity on a page

Adapted from [evident-charts](https://github.com/rhiever/evident-charts) (MIT,
Randy Olson), reduced to what a **self-contained HTML page** can prove.

## The boundary — read this first

evident-charts lints the **chart script** against the **data**. You are holding
a **page**. So the split is:

| Provable from the page | Needs the data — do it before you build |
|---|---|
| bars imply a zero origin, a declared floor breaks it | does the total equal the sum of its parts |
| a log scale the copy never mentions | duplicate rows, sentinel codes (0/888/999) |
| text addressed to you ("TODO", "confirm", "inferred") | preliminary months, partial periods |
| a file name standing in for a publisher | per-capita normalization, weighting |
| a legend *and* direct labels on the same marks | whether the takeaway survives a longer window |
| 3D/perspective on 1D data | a one-period swing that reverses (method change) |

`visualize chartcheck <file.html>` automates the left column. The right column
is your job as the author — a chart that passes every check can still lie if
the numbers were wrong before the page was built.

## The checks

**bar-baseline** — bars drawn as `width: N%` are `value/max` and start at
zero, which is honest. The page breaks it by *declaring* a non-zero origin
(`data-axis-min`, `ymin`, `baseline`, `domain`) or by saying so in text
("truncated axis", "bars start above 0"). Fix: drop the floor, or switch to
dots/points, where a non-zero origin is legitimate.

> A CSS-only bar chart cannot lie on this axis — `width` is always measured
> from the container edge. The check fires on SVG axes, chart-library configs,
> or a stated truncation. That is a real limit, not a gap in the check.

**log-unlabeled** — a log scale in the markup with no "log" in the visible text.
A log axis changes the meaning of every distance on the page; it must be
labelled. Fix: "log scale" in the axis label, and real-value ticks (1, 10, 100).

**process-note** — chart text addressed to the user (`TODO`, `confirm`,
`inferred`, `placeholder`) or a data file name (`sales_2022.csv`) standing in
for a source. Fix: move the note into your reply; cite the publisher.

**missing-source** — no `Source:`/`Data:` line. Name the **publisher and
dataset**, not the file.

**value-and-axis** — value labels on marks *and* a numeric value axis: the
number is on screen twice. Fix: labels replace the axis, never both.

**redundant-legend** — a legend next to direct labels on the same marks. Fix:
label directly, drop the legend.

**equal-height-3d** — `perspective`, `rotateX/Y` on bar containers. Depth
distorts value in a way the reader cannot undo. Fix: 2D, or encode the third
variable with color, size, or small multiples.

## Severity

- **P0 — misleads or states a wrong number.** `bar-baseline`, a wrong source.
- **P1 — the point does not land.** `redundant-legend`, `value-and-axis`.
- **P2 — polish.** Tick crowding, heavy default styling.

`chartcheck` exits 1 on any finding (block), 0 when clean. Severity is the
reviewer's call, not the script's.

## When to run it

After building any page whose main content is a chart, comparison, or
distribution — alongside `visualize validate` (one file) and `visualize lint`
(decorative AI-tells). All three are packaging and honesty gates, not
substitutes for reading the chart yourself.
