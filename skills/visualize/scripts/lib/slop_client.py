#!/usr/bin/env python3
"""slop_client — the one seam to the slop gate.

Everything the launcher needs to talk to the slop API lives here: token
resolution, endpoint (SLOP_API_URL), request shape, report rendering, and
exit-code semantics. Callers (share, lint, --dir) map exit codes to flow
and print `--human` output as-is; none of them know the API contract.

  slop_client lint <file> [--human]
    stdout : report (--human) or JSON (default: findings/info/review/score)
    exit 0 : clean (no hardslop finding)
    exit 1 : hardslop found (card-accent family, confidence >= 0.7)
    exit 3 : unverified — could not check at all (file unreadable, client bug)

  Modes:
    online   API reachable + token   -> full engine (11 detectors)
    offline  API unreachable/no tok  -> local hard-ban subset (the SKILL.md
    bans, mirrored: edge stripes all 4 sides with var() resolution, violet
    fills incl. muted (#5a4a8a-family), circle badges >= 20px). Pills are
    info, never gated — offline too. The subset is the offline SHADOW of
    the engine's hard level; do not add engine rules here.

Exit-code semantics per review 2026-10: 0/1/3, never silently skip —
"hardslop is not allowed" needs an offline defense line, not a shrug.
"""

import argparse
import json
import os
import re
import subprocess
import sys
import urllib.request

API_DEFAULT = "https://amd.skale.dev/api/slop/lint"
FIND, REVIEW = 0.7, 0.3
TIMEOUT_S = 20


# ── auth ────────────────────────────────────────────────────────────────────

def resolve_token() -> str:
    tok = os.environ.get("SLOP_TOKEN", "").strip()
    if tok:
        return tok
    try:
        out = subprocess.run(
            ["credgoo", "FETCH_URL_BEARER"], capture_output=True,
            text=True, timeout=10)
        return (out.stdout or "").strip()
    except Exception:
        return ""


# ── API call ────────────────────────────────────────────────────────────────

def api_lint(html: str):
    """POST the page; returns the report dict or None (unreachable/no auth)."""
    tok = resolve_token()
    if not tok:
        return None
    url = os.environ.get("SLOP_API_URL", API_DEFAULT)
    body = json.dumps({"html": html}).encode()
    req = urllib.request.Request(
        url, data=body, method="POST",
        headers={"Authorization": f"Bearer {tok}",
                 "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT_S) as resp:
            return json.load(resp)
    except Exception:
        return None


# ── offline hard-ban subset (the SKILL.md bans, mirrored) ──────────────────

_HEX = re.compile(r'^#([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})$')


def parse_hsl(value: str):
    """css color -> (h, s, l); None if unknown (never flag unknowns)."""
    v = value.strip().lower()
    m = _HEX.match(v)
    if not m:
        return None
    r, g, b = (int(c, 16) / 255 for c in m.groups())
    import colorsys
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    return (h * 360, s, l)


def is_neutral(hsl) -> bool:
    return hsl is not None and hsl[1] < 0.12


def is_violet(hsl) -> bool:
    return hsl is not None and 235 <= hsl[0] <= 295 and hsl[1] >= 0.25


def offline_lint(html: str) -> dict:
    """Hard-bans only: edge stripes (4 sides), violet fills, circle badges.

    Mirrors the engine's hard level. Deliberately NOT the full engine —
    pills/gradients/glass/fonts are info upstream and absent here.
    """
    findings = []
    src = re.sub(r'<!--.*?-->', '', html, flags=re.S)
    rules, props = [], {}
    for m in re.finditer(r'<style[^>]*>(.*?)</style>', src, flags=re.S):
        css = re.sub(r'/\*.*?\*/', '', m.group(1), flags=re.S)
        for rm in re.finditer(r'([^{}]+)\{([^{}]*)\}', css):
            sel, decls = rm.group(1).strip(), rm.group(2)
            rules.append((sel, decls))
            for cm in re.finditer(r'(--[a-z0-9-]+)\s*:\s*([^;]+)', decls):
                props.setdefault(cm.group(1), cm.group(2).strip())
    for m in re.finditer(r'<([a-zA-Z][a-zA-Z0-9]*)((?:[^>"]|"[^"]*")*)>', src):
        attrs = m.group(2)
        sm = re.search(r'\sstyle="([^"]*)"', attrs)
        if not sm:
            continue
        cm = re.search(r'\sclass="([^"]*)"', attrs)
        classes = cm.group(1).split() if cm else []
        rules.append((m.group(1) + ('.' + '.'.join(classes) if classes else ''),
                      sm.group(1)))

    def resolve(c):
        m = re.fullmatch(r'\s*var\(\s*(--[a-z0-9-]+)\s*\)\s*', c)
        return props.get(m.group(1), c) if m else c

    for sel, decls in rules:
        hsl_bg = None
        bm = re.search(r'background(?:-color)?\s*:\s*([^;]+)', decls)
        if bm:
            hsl_bg = parse_hsl(resolve(bm.group(1)))
        # edge stripe: any side, >=2px, non-neutral
        for side in ('left', 'top', 'right', 'bottom'):
            bm2 = re.search(
                r'border-' + side + r'\s*:\s*([\d.]+)(px|rem)\s+solid\s+([^;]+)',
                decls)
            if not bm2:
                continue
            w = float(bm2.group(1)) * (16 if bm2.group(2) == 'rem' else 1)
            raw = bm2.group(3).strip()
            if w < 2 or re.search(r'var\(\s*--(line|muted|soft|ink)\s*\)', raw):
                continue
            hsl = parse_hsl(resolve(raw))
            if hsl is None or is_neutral(hsl):
                continue
            conf = 0.85 if w >= 3 else 0.6
            findings.append(dict(
                id='edge_stripe', level='hard', confidence=conf,
                evidence=f'border-{side}:{w:g}px solid {resolve(raw)} on "{sel[:40]}"',
                fix='put the hue on content (label/dot/value), not on the card edge'))
        # violet fill (muted counts) — small dots excluded by size
        if hsl_bg is not None and is_violet(hsl_bg):
            sizes = [float(x) * (16 if u == 'rem' else 1) for x, u in re.findall(
                r'(?:^|[;\s])(?:width|height)\s*:\s*([\d.]+)(px|rem)', decls)]
            cls_size = None
            for part in sel.split('.')[1:]:
                for s2, d2 in rules:
                    if re.search(r'\.' + re.escape(part) + r'(?![\w-])', s2):
                        m3 = re.findall(
                            r'(?:width|height)\s*:\s*([\d.]+)(px|rem)', d2)
                        if m3:
                            cls_size = max(float(x) * (16 if u == 'rem' else 1)
                                           for x, u in m3)
            size = max(sizes) if sizes else cls_size
            if size is None or size > 14:
                findings.append(dict(
                    id='purple_cta', level='hard', confidence=0.85,
                    evidence=f'vibe purple fill on "{sel[:40]}"',
                    fix='violet/indigo fills read as AI default — pick another hue'))
        # circle badge: 50% radius + colored bg + >=20px
        if (re.search(r'border-radius\s*:\s*50%', decls) and hsl_bg is not None
                and not is_neutral(hsl_bg)):
            sizes = [float(x) * (16 if u == 'rem' else 1) for x, u in re.findall(
                r'(?:width|height)\s*:\s*([\d.]+)(px|rem)', decls)]
            if sizes and max(sizes) >= 20:
                findings.append(dict(
                    id='circle_badge', level='hard', confidence=0.8,
                    evidence=f'circle badge ({max(sizes):g}px) on "{sel[:40]}"',
                    fix='square swatch or text label instead of a big colored circle'))

    hard = [f for f in findings if f['confidence'] >= FIND]
    return {
        'score': round(sum(f['confidence'] * 5 for f in hard), 1),
        'tier': 'Offline' if findings else 'Clean',
        'mode': 'offline (hard-bans only)',
        'findings': hard,
        'info': [f for f in findings if f['confidence'] < FIND],
        'review': [],
        'definitions_version': 'offline-shadow',
    }


# ── report rendering ────────────────────────────────────────────────────────

def render_human(d: dict) -> str:
    fs, rv, info = d.get('findings', []), d.get('review', []), d.get('info', [])
    score, tier, mode = d.get('score'), d.get('tier'), d.get('mode')
    prefix = 'visualize slop'
    mode_tag = f' · {mode}' if mode else ''
    lines = []
    if not fs and not rv and not info:
        lines.append(f'{prefix}: Clean (score {score}) — no AI-tells{mode_tag}')
    elif not fs:
        lines.append(f'{prefix}: no hard slop (score {score}, {tier}){mode_tag}'
                     f' — {len(info)} info, {len(rv)} to review:')
    else:
        lines.append(f'{prefix}: {len(fs)} hardslop (score {score})'
                     f'{mode_tag} — fix and re-share with --update:')
    for f in fs:
        lines.append(f"  HARDSLOP {f['id']}: {f['evidence']}")
        lines.append(f"    fix: {f['fix']}")
    for f in info:
        lines.append(f"  info    {f['id']}: {f['evidence']}")
    for f in rv:
        lines.append(f"  review  {f['id']}: {f['evidence']} — you decide")
    return '\n'.join(lines)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('cmd', choices=['lint'])
    ap.add_argument('file')
    ap.add_argument('--human', action='store_true')
    ap.add_argument('--json', action='store_true', dest='as_json')
    args = ap.parse_args()

    try:
        html = open(args.file, encoding='utf-8', errors='replace').read()
    except OSError as e:
        print(f'slop_client: cannot read {args.file}: {e}', file=sys.stderr)
        return 3

    d = api_lint(html)
    if d is None:
        d = offline_lint(html)

    findings = d.get('findings', [])
    if args.human:
        print(render_human(d))
    else:
        print(json.dumps(d))

    return 1 if any(f.get('confidence', 1) >= FIND for f in findings) else 0


if __name__ == '__main__':
    sys.exit(main())
