#!/usr/bin/env python3
"""SVG box linter for visualize HTML pages — text must stay inside its box.

The bug class this catches is real and shipped: an animated auditflow figure
had its terminal text stick 5px past the viewBox, found by hand in a browser
(2026-11-12). This gate makes that measurement mechanical.

What it proves from markup alone (a self-contained page gives us no renderer):
for every ``<text>`` in every inline ``<svg>`` we estimate the text extent from
its CSS class (font-size, mono vs sans, letter-spacing — the house diagrams are
mono-first, advance ≈ 0.6em/char) and compare it against

  box        the union bbox of the shapes (rect/polygon/ellipse/circle) in the
             nearest enclosing ``<g>`` — a node group is its box
  viewBox    free texts (no enclosing shape group) must stay inside the canvas

Checks (exit 1 lists every violation, each with the numbers):
  text-out-of-box    estimated extent crosses the group's shape union (+2px tol)
  text-out-of-viewbox  extent crosses the svg viewBox (the shipped bug class)
  text-over-text      two texts overlap — any group; adjacent lines have ~6px air
  text-over-shape     a text drifts into ANOTHER node's shape union (shipped:
                      "sonst → PA" ran 41px into the KONTEXT box, 2026-11-12)
  text-over-edge      a text sits on an edge curve — sampled ON-curve (Bernstein
                      subdivision), because a curve's bbox flags labels the curve
                      never touches (the false-positive class that would make the
                      gate noise)

Honest scope (skipped is reported, never silently passed):
  foreignObject      svg blocks containing one are skipped wholesale (pele /
                     mermaid render rich labels there — different contract)
  transformed        text with a transformed ancestor is skipped (transforms
                     move geometry; estimating them here would guess twice)
  non-px coords      x/y in % or em are skipped (house SVGs use user units)

Best-effort like jscheck/chartcheck: no python3 → the launcher says so and
exits 0; a page is never blocked by a missing tool.
"""

from __future__ import annotations

import re
import sys
from html import unescape
from html.parser import HTMLParser
from typing import NamedTuple

SVG_BLOCK = re.compile(r"<svg\b([^>]*)>(.*?)</svg\s*>", re.S | re.I)
STYLE_BLOCK = re.compile(r"<style\b[^>]*>(.*?)</style\s*>", re.S | re.I)
RULE = re.compile(r"([^{}]+)\{([^{}]*)\}", re.S)
SHAPE_TAGS = {"rect", "circle", "ellipse", "polygon", "path"}
PATH_CMD = re.compile(r"([MLHVCSQTAZmlhvcsqtaz])|(-?\d*\.?\d+(?:[eE][-+]?\d+)?)")

MONO_HINT = re.compile(r"monospace|Menlo|Consolas|Courier|Roboto[ ,]?Mono", re.I)
TOL_BOX = 2.0        # px slack against the shape union — strokes + estimates
TOL_VB = 0.5         # px slack against the viewBox — the canvas is hard
TOL_OVERLAP = 1.0    # px slack for element-vs-element overlap — estimates breathe
CURVE_SAMPLES = 8    # bezier subdivision depth for text-over-edge sampling


class Style(NamedTuple):
    size: float | None
    mono: bool | None
    spacing: float  # px letter-spacing (0 if unset)


class Node:
    """Minimal DOM node — tag, attrs, parent, children, own text."""

    __slots__ = ("tag", "attrs", "parent", "children", "text")

    def __init__(self, tag: str, attrs: dict[str, str], parent: "Node | None"):
        self.tag = tag
        self.attrs = attrs
        self.parent = parent
        self.children: list[Node] = []
        self.text = ""
        if parent is not None:
            parent.children.append(self)

    def ancestors(self) -> "list[Node]":
        out, n = [], self.parent
        while n is not None:
            out.append(n)
            n = n.parent
        return out


class SvgParser(HTMLParser):
    """Build a Node tree for one svg block; keep text content on <text>."""

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.root = Node("root", {}, None)
        self.cur = self.root

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        a = {k: (v or "") for k, v in attrs}
        if tag in SHAPE_TAGS or tag in ("svg", "g", "text", "tspan", "foreignObject", "defs"):
            self.cur = Node(tag, a, self.cur)
        elif tag == "use":
            Node(tag, a, self.cur)  # leaf, no children

    def handle_startendtag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        a = {k: (v or "") for k, v in attrs}
        if tag in SHAPE_TAGS or tag in ("svg", "g", "text", "tspan", "foreignObject", "defs", "use"):
            Node(tag, a, self.cur)

    def handle_endtag(self, tag: str) -> None:
        n = self.cur
        while n is not None and n.tag != tag:
            n = n.parent
        if n is not None and n.parent is not None:
            self.cur = n.parent

    def handle_data(self, data: str) -> None:
        if self.cur.tag == "text":
            self.cur.text += data


def parse_css(html: str) -> dict[str, Style]:
    """class → font facts from every <style> block (flat rules, house subset)."""
    out: dict[str, Style] = {}
    for styles in STYLE_BLOCK.findall(html):
        for sel, body in RULE.findall(styles):
            size: float | None = None
            mono: bool | None = None
            spacing = 0.0
            for prop in body.split(";"):
                if ":" not in prop:
                    continue
                k, v = prop.split(":", 1)
                k, v = k.strip().lower(), v.strip()
                if k == "font-size" and v.endswith("px"):
                    try:
                        size = float(v[:-2])
                    except ValueError:
                        pass
                elif k == "font-family":
                    mono = bool(MONO_HINT.search(v))
                elif k == "letter-spacing":
                    m = re.fullmatch(r"([\d.]+)px", v) or re.fullmatch(r"([\d.]+)em", v)
                    if m:
                        base = float(m.group(1))
                        spacing = base if v.endswith("px") else base * (size or 16.0)
            for s in sel.split(","):
                for cls in re.findall(r"\.([\w-]+)", s):
                    prev = out.get(cls)
                    if prev is not None:  # later rules refine, keep known facts
                        out[cls] = Style(
                            size if size is not None else prev.size,
                            mono if mono is not None else prev.mono,
                            spacing if spacing else prev.spacing,
                        )
                    else:
                        out[cls] = Style(size, mono, spacing if spacing else 0.0)
    return out


def _f(attr: str | None) -> float | None:
    if attr is None:
        return None
    m = re.fullmatch(r"(-?[\d.]+)\s*(px)?", attr.strip())
    return float(m.group(1)) if m else None


def path_bbox(d: str) -> tuple[float, float, float, float] | None:
    """Conservative bbox for a path ``d`` — on-curve points plus control points.

    Arcs add their ry as vertical slack around the endpoints (caps bulge):
    overestimating is safe for a linter, underestimating fails honest text.
    """
    pairs = PATH_CMD.findall(d)
    toks = [a or b for a, b in pairs]
    if not toks:
        return None
    pts: list[tuple[float, float]] = []
    x = y = 0.0
    sx = sy = 0.0
    cmd = ""
    i = 0
    while i < len(toks):
        t = toks[i]
        if t.isalpha():
            cmd = t
            if cmd in "Zz":
                pts.append((sx, sy))
                x, y = sx, sy
            i += 1
            continue
        nums: list[float] = []
        while i < len(toks) and not toks[i].isalpha():
            nums.append(float(toks[i]))
            i += 1
        C = (cmd or "M").upper()
        rel = cmd.islower() and cmd.isalpha()
        if C == "M" and len(nums) >= 2:
            x, y = (x + nums[0], y + nums[1]) if rel else (nums[0], nums[1])
            sx, sy = x, y
            pts.append((x, y))
        elif C == "L" and len(nums) >= 2:
            x, y = (x + nums[0], y + nums[1]) if rel else (nums[0], nums[1])
            pts.append((x, y))
        elif C == "H" and nums:
            x = x + nums[0] if rel else nums[0]
            pts.append((x, y))
        elif C == "V" and nums:
            y = y + nums[0] if rel else nums[0]
            pts.append((x, y))
        elif C in "CS" and len(nums) >= 6:
            bx, by = (x, y) if rel else (0.0, 0.0)
            pts.extend([(bx + nums[0], by + nums[1]),
                        (bx + nums[2], by + nums[3])])
            x, y = bx + nums[4], by + nums[5]
            pts.append((x, y))
        elif C in "QT" and len(nums) >= 4:
            bx, by = (x, y) if rel else (0.0, 0.0)
            pts.append((bx + nums[0], by + nums[1]))
            x, y = bx + nums[2], by + nums[3]
            pts.append((x, y))
        elif C == "A" and len(nums) >= 7:
            ry = nums[1]
            x, y = (x + nums[5], y + nums[6]) if rel else (nums[5], nums[6])
            pts.append((x, y - ry))
            pts.append((x, y + ry))
    if not pts:
        return None
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    return (min(xs), min(ys), max(xs), max(ys))


def path_samples(d: str) -> list[tuple[float, float]]:
    """On-curve sample points for a path ``d`` — the text-over-edge truth.

    Lines contribute their endpoints, cubics/quadratics are subdivided
    (Bernstein), arcs contribute chord endpoints + midpoint. Control points
    stay out: a lint that flags the bounding box of a curve flags labels the
    curve never touches (shipped false positive, 2026-11-12).
    """
    pairs = PATH_CMD.findall(d)
    toks = [a or b for a, b in pairs]
    pts: list[tuple[float, float]] = []
    x = y = 0.0
    cmd = ""
    i = 0

    def bez(p0, p1, p2, p3, n=CURVE_SAMPLES) -> None:
        for k in range(n + 1):
            t = k / n
            u = 1 - t
            pts.append((
                u * u * u * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t * t * t * p3[0],
                u * u * u * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t * t * t * p3[1],
            ))

    while i < len(toks):
        t = toks[i]
        if t.isalpha():
            cmd = t
            if cmd in "Zz":
                pts.append((x, y))
            i += 1
            continue
        nums: list[float] = []
        while i < len(toks) and not toks[i].isalpha():
            nums.append(float(toks[i]))
            i += 1
        C = (cmd or "M").upper()
        rel = cmd.islower() and cmd.isalpha()
        bx, by = (x, y) if rel else (0.0, 0.0)
        if C == "M" and len(nums) >= 2:
            x, y = bx + nums[0], by + nums[1]
            pts.append((x, y))
        elif C == "L" and len(nums) >= 2:
            x, y = bx + nums[0], by + nums[1]
            pts.append((x, y))
        elif C == "H" and nums:
            x = bx + nums[0]
            pts.append((x, y))
        elif C == "V" and nums:
            y = by + nums[0]
            pts.append((x, y))
        elif C == "C" and len(nums) >= 6:
            p1 = (bx + nums[0], by + nums[1])
            p2 = (bx + nums[2], by + nums[3])
            p3 = (bx + nums[4], by + nums[5])
            bez((x, y), p1, p2, p3)
            x, y = p3
        elif C == "S" and len(nums) >= 4:  # reflected c1 unknown — degenerate cubic
            p2 = (bx + nums[0], by + nums[1])
            p3 = (bx + nums[2], by + nums[3])
            bez((x, y), (x, y), p2, p3)
            x, y = p3
        elif C == "Q" and len(nums) >= 4:
            p1 = (bx + nums[0], by + nums[1])
            p3 = (bx + nums[2], by + nums[3])
            for k in range(CURVE_SAMPLES + 1):
                t = k / CURVE_SAMPLES
                u = 1 - t
                pts.append((
                    u * u * x + 2 * u * t * p1[0] + t * t * p3[0],
                    u * u * y + 2 * u * t * p1[1] + t * t * p3[1],
                ))
            x, y = p3
        elif C == "T" and len(nums) >= 2:
            x, y = bx + nums[0], by + nums[1]
            pts.append((x, y))
        elif C == "A" and len(nums) >= 7:
            ex, ey = bx + nums[5], by + nums[6]
            pts.append(((x + ex) / 2, (y + ey) / 2))
            x, y = ex, ey
            pts.append((x, y))
    return pts


def shape_bbox(n: Node) -> tuple[float, float, float, float] | None:
    """(x0, y0, x1, y1) for a shape, None for anything we cannot measure."""
    a = n.attrs
    if n.tag == "rect":
        x, y, w, h = _f(a.get("x")), _f(a.get("y")), _f(a.get("width")), _f(a.get("height"))
        if None in (x, y, w, h):
            return None
        return (x, y, x + w, y + h)
    if n.tag == "circle":
        cx, cy, r = _f(a.get("cx")), _f(a.get("cy")), _f(a.get("r"))
        if None in (cx, cy, r):
            return None
        return (cx - r, cy - r, cx + r, cy + r)
    if n.tag == "ellipse":
        cx, cy, rx, ry = _f(a.get("cx")), _f(a.get("cy")), _f(a.get("rx")), _f(a.get("ry"))
        if None in (cx, cy, rx, ry):
            return None
        return (cx - rx, cy - ry, cx + rx, cy + ry)
    if n.tag == "polygon":
        nums = re.findall(r"-?[\d.]+", a.get("points", ""))
        if len(nums) < 4 or len(nums) % 2:
            return None
        xs = [float(v) for v in nums[0::2]]
        ys = [float(v) for v in nums[1::2]]
        return (min(xs), min(ys), max(xs), max(ys))
    if n.tag == "path":
        return path_bbox(n.attrs.get("d", ""))
    return None


def group_box(text_node: Node) -> tuple[float, float, float, float] | None:
    """Union bbox of shapes that are direct children of the nearest shape-g."""
    for anc in text_node.ancestors():
        if anc.tag != "g":
            continue
        boxes = [b for c in anc.children if (b := shape_bbox(c)) is not None]
        if boxes:
            xs0, ys0, xs1, ys1 = zip(*boxes)
            return (min(xs0), min(ys0), max(xs1), max(ys1))
    return None


def text_extent(n: Node, css: dict[str, Style]) -> tuple[float, float, float, float] | None:
    """Estimated (x0, top, x1, bottom) for a <text>, None if unmeasurable."""
    x, y = _f(n.attrs.get("x")), _f(n.attrs.get("y"))
    if x is None or y is None:
        return None
    style = Style(None, None, 0.0)
    for cls in (n.attrs.get("class") or "").split():
        if (c := css.get(cls)) is not None:
            style = Style(
                c.size if style.size is None else style.size,
                c.mono if style.mono is None else style.mono,
                style.spacing or c.spacing,
            )
    size = style.size if style.size is not None else 16.0
    mono = style.mono if style.mono is not None else False
    content = unescape(n.text).strip()
    if not content:
        return None
    advance = size * (0.60 if mono else 0.52)
    w = len(content) * advance + max(0, len(content) - 1) * style.spacing
    anchor = (n.attrs.get("text-anchor") or "").strip()
    if anchor == "middle":
        x0 = x - w / 2.0
    elif anchor == "end":
        x0 = x - w
    else:
        x0 = x
    return (x0, y - size * 0.78, x0 + w, y + size * 0.24)


def lint(html: str) -> tuple[list[str], int, int]:
    """Return (violations, texts checked, texts skipped) for one page."""
    violations: list[str] = []
    checked = skipped = 0
    css = parse_css(html)

    for m in SVG_BLOCK.finditer(html):
        attrs_raw, inner = m.group(1), m.group(2)
        if "foreignObject" in inner.lower():
            violations.append(
                "skip  svg contains <foreignObject> — rich-label contract, not linted"
            )
            continue
        parser = SvgParser()
        parser.feed(inner)
        vb = [_f(v) for v in re.search(
            r'viewBox\s*=\s*"([^"]+)"', attrs_raw).group(1).split()] if 'viewBox' in attrs_raw else None
        if vb is None or len(vb) != 4 or None in vb:
            vb = [0.0, 0.0, 0.0, 0.0]

        def walk(n: Node, texts: list, groups: list, curves: list) -> None:
            nonlocal checked, skipped
            for c in n.children:
                if c.tag == "defs":
                    continue  # pattern/grid geometry is background, not content
                if c.tag == "g":
                    boxes = [b for ch in c.children if (b := shape_bbox(ch)) is not None]
                    if boxes:
                        xs0, ys0, xs1, ys1 = zip(*boxes)
                        groups.append((c, (min(xs0), min(ys0), max(xs1), max(ys1))))
                    walk(c, texts, groups, curves)
                    continue
                if c.tag == "path":
                    samples = path_samples(c.attrs.get("d", ""))
                    if samples:
                        curves.append((c, samples))
                    continue
                if c.tag == "text":
                    if any("transform" in a.attrs for a in c.ancestors()):
                        skipped += 1
                        continue
                    ext = text_extent(c, css)
                    if ext is None:
                        skipped += 1
                        continue
                    checked += 1
                    texts.append((c, ext, unescape(c.text).strip()[:38] or "(empty)"))
                walk(c, texts, groups, curves)

        texts: list = []
        groups: list = []
        curves: list = []
        walk(parser.root, texts, groups, curves)

        def own_group(node: Node):
            for anc in node.ancestors():
                if anc.tag == "g" and any(shape_bbox(ch) is not None for ch in anc.children):
                    return anc
            return None

        for c, (x0, top, x1, bot), label in texts:
            box = None
            for g, gb in groups:
                if g is own_group(c):
                    box = gb
                    break
            if box is not None:
                bx0, by0, bx1, by1 = box
                for edge, got, limit in (
                    ("left", x0, bx0), ("top", top, by0),
                    ("right", x1, bx1), ("bottom", bot, by1),
                ):
                    over = got - limit if edge in ("right", "bottom") else limit - got
                    if over > TOL_BOX:
                        msg = (
                            f"text-out-of-box    \"{label}\" crosses {edge} edge "
                            f"by {over:.0f}px (text {got:.0f} vs box {limit:.0f})"
                        )
                        if edge == "right":
                            # zwei kurze Zeilen erhalten mehr Bedeutung als eine
                            # abgeschnittene — der Hinweis rechnet es vor
                            need, avail = x1 - x0, bx1 - bx0
                            if need > 1.5 * avail:
                                msg += (
                                    f" — split into 2 lines (~{need / 2:.0f}px/line "
                                    f"fits {avail:.0f}px)"
                                )
                        violations.append(msg)
            else:
                # free text: the viewBox is the box
                vx1, vy1 = vb[0] + vb[2], vb[1] + vb[3]
                for edge, got, limit in (
                    ("left", x0, vb[0]), ("top", top, vb[1]),
                    ("right", x1, vx1), ("bottom", bot, vy1),
                ):
                    over = got - limit if edge in ("right", "bottom") else limit - got
                    if over > TOL_VB:
                        violations.append(
                            f"text-out-of-viewbox  \"{label}\" crosses {edge} edge "
                            f"by {over:.0f}px (text {got:.0f} vs canvas {limit:.0f})"
                        )

        # ── lint harder: overlays, not just containment ──────────────────
        # text on text (any group — adjacent lines have ~6px real air)
        for i in range(len(texts)):
            ca, (ax0, atop, ax1, abot), la = texts[i]
            for j in range(i + 1, len(texts)):
                cb, (bx0, btop, bx1, bbot), lb = texts[j]
                ox = min(ax1, bx1) - max(ax0, bx0)
                oy = min(abot, bbot) - max(atop, btop)
                if ox > TOL_OVERLAP and oy > TOL_OVERLAP:
                    violations.append(
                        f"text-over-text      \"{la}\" overlaps \"{lb}\" "
                        f"by {ox:.0f}×{oy:.0f}px"
                    )
        # text over a foreign group's shape union (labels drifting into nodes).
        # Ancestor containers are NOT foreign: a group frame legitimately
        # surrounds its nested minitasks (ENTRY grouping, 2026-11-12).
        for c, (x0, top, x1, bot), label in texts:
            ancestors = set(id(a) for a in c.ancestors())
            for g, (gx0, gy0, gx1, gy1) in groups:
                if g is own_group(c) or id(g) in ancestors:
                    continue
                ox = min(x1, gx1) - max(x0, gx0)
                oy = min(bot, gy1) - max(top, gy0)
                if ox > TOL_OVERLAP and oy > TOL_OVERLAP:
                    violations.append(
                        f"text-over-shape     \"{label}\" overlaps another node's box "
                        f"by {ox:.0f}×{oy:.0f}px"
                    )
        # text over an edge curve — sampled on-curve, bbox would lie
        for c, (x0, top, x1, bot), label in texts:
            sx0, sop, sx1, sbot = x0 + TOL_OVERLAP, top + TOL_OVERLAP, x1 - TOL_OVERLAP, bot - TOL_OVERLAP
            if sx1 <= sx0 or sbot <= sop:
                continue
            for p, samples in curves:
                og = own_group(p)
                if og is not None and og is own_group(c):
                    continue
                for px, py in samples:
                    if sx0 <= px <= sx1 and sop <= py <= sbot:
                        violations.append(
                            f"text-over-edge      \"{label}\" sits on an edge curve "
                            f"(at {px:.0f},{py:.0f})"
                        )
                        break
    return violations, checked, skipped


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: boxcheck <file.html>", file=sys.stderr)
        return 2
    try:
        html = open(sys.argv[1], encoding="utf-8", errors="replace").read()
    except OSError as e:
        print(f"visualize boxcheck: {e}", file=sys.stderr)
        return 2

    violations, checked, skipped = lint(html)
    for v in violations:
        print(v, file=sys.stderr)
    real = [v for v in violations if not v.startswith("skip ")]
    if real:
        print(
            f"visualize boxcheck: ✗ {len(real)} text(s) outside their box — "
            f"split the label across lines, shorten it, widen the box, or move the text",
            file=sys.stderr,
        )
        return 1
    print(
        f"visualize boxcheck: OK — {checked} svg text(s) measured, "
        f"{skipped} skipped (transformed/non-px), all inside their boxes",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
