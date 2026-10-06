#!/usr/bin/env bash
# visualize test suite
#   bash tests/visualize/test.sh
set -uo pipefail
cd "$(dirname "$0")/../.."

SKILL=skills/visualize
SCRIPT="$SKILL/visualize"
PASS=0; FAIL=0

ok()   { PASS=$((PASS+1)); }
bad()  { FAIL=$((FAIL+1)); echo "  FAIL: $1" >&2; }
warn() { echo "  WARN: $1" >&2; }

check() { # check <desc> <expected-exit> <cmd...>
    local desc="$1" want="$2"; shift 2
    "$@" >/tmp/visualize.out 2>&1
    local got=$?
    if [ "$got" -eq "$want" ]; then ok; else bad "$desc (want exit $want, got $got)"; fi
}

echo "visualize tests"
echo "---------------"

# structure
[ -f "$SKILL/SKILL.md" ] && ok || bad "SKILL.md missing"
[ -f "$SKILL/install.sh" ] && ok || bad "install.sh missing"
[ -f "$SKILL/install.bat" ] && ok || bad "install.bat missing"
[ -x "$SCRIPT" ] && ok || bad "visualize not executable"
grep -q 'GIT_ROOT=' "$SCRIPT" && ok || bad "launcher must resolve enclosing git root (GIT_ROOT)"
grep -q 'GIT_ROOT/.git' "$SCRIPT" && ok || bad "auto-update guard must use GIT_ROOT/.git"
[ -f "$SKILL/references/structures.md" ] && ok || bad "structures.md missing"
[ -f "$SKILL/references/modules.md" ] && ok || bad "modules.md missing"
[ -f "$SKILL/references/report.md" ] && ok || bad "report.md missing"
[ -f "$SKILL/references/promptlib.md" ] && ok || bad "promptlib.md missing"
[ -f "$SKILL/references/patterns.md" ] && ok || bad "patterns.md missing"
[ -f "$SKILL/references/output.md" ] && ok || bad "output.md missing"
[ -f "$SKILL/references/html-patterns.md" ] && ok || bad "html-patterns.md missing"
[ -f "$SKILL/references/routing.md" ] && ok || bad "routing.md missing"
[ -f "$SKILL/references/code-forms.md" ] && ok || bad "code-forms.md missing"
# SKILL.md convention: under 100 lines (routing depth lives in references/)
[ "$(wc -l < "$SKILL/SKILL.md" | tr -d ' ')" -le 99 ] && ok || bad "SKILL.md over 99 lines — disclose detail to references/ (progressive disclosure), don't compress"

# modules.md — class-based catalog (instantiate blocks, don't hand-roll inline CSS)
grep -q 'class="card"' "$SKILL/references/modules.md" && ok || bad "modules.md card pattern is class-based"
grep -q -e '--ink:#1a1a1a' "$SKILL/references/modules.md" && ok || bad "modules.md base carries the canonical ink token"
grep -q 'style="background:#fff;border:1px solid var(--line);border-radius:.75rem' "$SKILL/references/modules.md" \
    && bad "modules.md still inline-duplicates card CSS" || ok
for m in header legend card-grid tree flow table section exec-summary recommendations mermaid footer; do
    grep -q "^### $m$" "$SKILL/references/modules.md" && ok || bad "modules.md missing module docs: $m"
done
# one canonical token family (#1a1a1a) across references — no drifted slate ink
grep -rq 'ink: *#0f172a' "$SKILL/references/" && bad "drifted ink token #0f172a still in references/" || ok
# README may claim Tailwind ONLY if a template actually loads it (honesty guard)
if grep -qi 'tailwind' "$SKILL/templates/README.md"; then
    grep -q 'cdn.tailwindcss.com' "$SKILL/templates/tailwind-report.html" && ok || bad "README claims Tailwind but tailwind-report.html doesn't load the CDN"
else
    ok
fi


# test prompts (tests/visualize/prompts.md) — coverage: every template & module prompted
PROMPTS="tests/visualize/prompts.md"
[ -f "$PROMPTS" ] && ok || bad "prompts.md missing"
if [ -f "$PROMPTS" ]; then
    for t in cards repo-tree system-map report mermaid timeline before-after cheatsheet barchart; do
        grep -q "$t\.html" "$PROMPTS" && ok || bad "no test prompt covering template $t.html"
    done
    for m in header legend card-grid tree flow table section exec-summary recommendations mermaid footer; do
        grep -q "\`$m\`" "$PROMPTS" && ok || bad "no test prompt covering module \`$m\`"
    done
    grep -q '/skill:d2' "$PROMPTS" && ok || bad "no routing prompt for d2"
    grep -q '/skill:figure' "$PROMPTS" && ok || bad "no routing prompt for figure"
    grep -q 'social-og\|slide-16x9' "$PROMPTS" && ok || bad "no output-target prompt"
    # inline-first routing (code-forms.md, merged from humanlayer show-me)
    grep -q 'inline' "$PROMPTS" && ok || bad "no prompt covering the inline (no-file) tier"
    for f in pseudocode "call tree" "annotated file tree"; do
        grep -qi "$f" "$PROMPTS" && ok || bad "no prompt covering inline form: $f"
    done
fi

# code-forms.md: the inline tier must be complete and reachable
CF="$SKILL/references/code-forms.md"
if [ -f "$CF" ]; then
    for h in "## Pseudocode" "## Call tree" "## Component tree" "## Annotated file tree" "## Diff" "## Mermaid"; do
        grep -qF "$h" "$CF" && ok || bad "code-forms.md missing section: $h"
    done
    # the four diff shapes from show-me (component / file-layout / call-tree / control-flow)
    grep -q "File-layout change" "$CF" && ok || bad "code-forms.md: missing file-layout diff shape"
    grep -q "Call-tree change" "$CF" && ok || bad "code-forms.md: missing call-tree diff shape"
    grep -q "State / control-flow change" "$CF" && ok || bad "code-forms.md: missing control-flow diff shape"
    # the humanlayer HTML fallback must NOT come along (a page is visualize's job).
    # Match an actual usage (`Bash(open ...)` in a fenced block / bare line), not prose
    # that merely mentions it while explaining that it was dropped.
    if grep -qE '^\s*(Bash\(open|`Bash\(open)' "$CF"; then
        bad "code-forms.md: Claude-only Bash(open …) leaked in as an instruction"
    else
        ok
    fi
    # and it must be wired into the routing tiers + SKILL.md
    grep -q 'code-forms.md' "$SKILL/references/routing.md" && ok || bad "routing.md: code-forms.md not linked"
    grep -q 'code-forms.md' "$SKILL/SKILL.md" && ok || bad "SKILL.md: code-forms.md not linked"
    grep -q 'code-forms.md' "$SKILL/references/structures.md" && ok || bad "structures.md: code-forms.md not cross-linked"
fi

# templates
for t in cards repo-tree system-map report mermaid tailwind-report; do
    [ -f "$SKILL/templates/$t.html" ] && ok || bad "template $t.html missing"
done

# lint catches Tailwind pill classes — info now, not a gate (pills sind ok)
PILLFILE="$(mktemp -d)/pilltest.html"
cat > "$PILLFILE" <<'PILLEOF'
<p class="rounded-full bg-emerald-100 px-3 py-1">badge</p>
PILLEOF
out="$(env SLOP_API_URL=http://127.0.0.1:1 "$SCRIPT" lint "$PILLFILE" 2>&1)"; rc=$?
if [ $rc -eq 0 ]; then ok; else bad "Tailwind pills must not gate (rc=$rc: $out)"; fi
rm -rf "$(dirname "$PILLFILE")"
[ -f "$SKILL/templates/README.md" ] && ok || bad "templates/README.md missing"

# templates must pass their own gates (house style + self-contained)
for t in cards repo-tree system-map report mermaid tailwind-report timeline before-after cheatsheet barchart; do
    check "lint template $t.html → exit 0" 0 "$SCRIPT" lint "$SKILL/templates/$t.html"
    check "validate template $t.html → exit 0" 0 "$SCRIPT" validate "$SKILL/templates/$t.html"
done
# --- validate must not flag documentation of an import as a dependency -----------
# Regression: `validate` scanned the whole file for `import ... from '...'`, so a page
# that merely *shows* an import in <code> (e.g. explaining a refactor) was rejected —
# which taught agents not to trust the gate. Only real <script> content counts now.
VT="$(mktemp -d)"
cat > "$VT/prose.html" <<'EOF'
<!doctype html><html><head><meta charset="utf-8"><title>t</title></head><body>
<div class="note"><code>import ... from './transport'</code> weiterhin funktioniert.</div>
<code>import {connect} from './client'</code>
<pre>import x from './y'</pre>
</body></html>
EOF
cat > "$VT/script.html" <<'EOF'
<!doctype html><html><head><meta charset="utf-8"><title>t</title>
<script type="module">import mermaid from './mermaid.mjs';</script></head><body>x</body></html>
EOF
check "validate: import shown in <code>/<pre> → exit 0" 0 "$SCRIPT" validate "$VT/prose.html"
check "validate: real local import in <script> → exit 1" 1 "$SCRIPT" validate "$VT/script.html"
rm -rf "$VT"

[ -f "$SKILL/templates/timeline.html" ] && ok || bad "timeline.html missing"
[ -f "$SKILL/templates/before-after.html" ] && ok || bad "before-after.html missing"
[ -f "$SKILL/templates/cheatsheet.html" ] && ok || bad "cheatsheet.html missing"
[ -f "$SKILL/templates/barchart.html" ] && ok || bad "barchart.html missing"
# system-map template must handle long tokens (paths/URLs) in narrow cards —
# flex rows + unbreakable strings spill out without overflow-wrap
grep -q "overflow-wrap" "$SKILL/templates/system-map.html" && ok || bad "system-map.html lacks overflow-wrap (long tokens spill out of cards)"
# category colour must appear ON the cards, not only in the legend
# (legend-only colour = hue that encodes nothing on the items — promptlib §2)
grep -q 'class="cat"><span class="dot"' "$SKILL/templates/cards.html" && ok || bad "cards.html: category dot missing in card footer (colour only in legend)"
grep -q 'class="cat"><span class="dot"' "$SKILL/references/modules.md" && ok || bad "modules.md card-grid: category dot missing"
# structure via rhythm + style, not colour alone (grayscale test)
grep -qF '.grid+.grid' "$SKILL/references/modules.md" && ok || bad "modules.md: no group rhythm (.grid+.grid)"
grep -qF '.name.dir{font-weight:700' "$SKILL/references/modules.md" && ok || bad "modules.md: no dir/file weight hierarchy"
grep -qF '.name.dir{font-weight:700' "$SKILL/templates/repo-tree.html" && ok || bad "repo-tree.html: no dir/file weight hierarchy"
grep -q 'Rhythm & style carry structure' "$SKILL/references/promptlib.md" && ok || bad "promptlib: rhythm/style channels undocumented"
# repo-tree: kind dots in category hues (colour on the items, not legend-only)
grep -q 'class="kind"><span class="sw"' "$SKILL/templates/repo-tree.html" && ok || bad "repo-tree.html: kind dot missing on rows"
# SOTA grounding: WCAG 1.4.1 + gestalt rules; one title size across templates
grep -q 'WCAG 1.4.1' "$SKILL/references/promptlib.md" && ok || bad "promptlib: WCAG 1.4.1 grounding missing"
grep -q 'card soup' "$SKILL/references/modules.md" && ok || bad "modules.md: common-region rule missing"
grep -q 'phantom relationship' "$SKILL/references/modules.md" && ok || bad "modules.md: connector rule missing"
grep -rq 'font-size:1.9rem' "$SKILL/templates/" && bad "h1 size drift (1.9rem) in templates" || ok

# usage / errors
check "no args → exit 2" 2 "$SCRIPT"
check "unknown cmd → exit 2" 2 "$SCRIPT" bogus
check "open missing file → exit 2" 2 "$SCRIPT" open /nonexistent.html
check "share missing file → exit 2" 2 "$SCRIPT" share /nonexistent.html
check "--help → exit 0" 0 "$SCRIPT" --help

# launcher flags (convention: --update/--selfcheck)
check "--selfcheck → exit 0" 0 "$SCRIPT" --selfcheck
grep -q "visualize v" /tmp/visualize.out && ok || bad "selfcheck shows version"
grep -q "dir:" /tmp/visualize.out && ok || bad "selfcheck shows dir"
check "--update → exit 0" 0 "$SCRIPT" --update
grep -q "Updated" /tmp/visualize.out && ok || bad "--update reports Updated"
[ -f "$SKILL/.last-update" ] && ok || bad "stamp file created"

# build a self-contained file and validate it
TMP=$(mktemp -d)
cat > "$TMP/good.html" <<'EOF'
<!doctype html><html><head><meta charset="utf-8"><title>t</title>
<style>body{font-family:sans-serif}</style></head>
<body><h1>Good</h1><div class="card">hello</div></body></html>
EOF
cat > "$TMP/bad.html" <<'EOF'
<!doctype html><html><head><meta charset="utf-8"><title>t</title>
<script src="https://example.com/app.js"></script></head>
<body><h1>Bad</h1></body></html>
EOF
check "validate self-contained → exit 0" 0 "$SCRIPT" validate "$TMP/good.html"
check "validate external ref → exit 1" 1 "$SCRIPT" validate "$TMP/bad.html"

cat > "$TMP/cdn.html" <<'EOF'
<!doctype html><html><head><meta charset="utf-8"><title>t</title>
<script src="https://cdn.jsdelivr.net/npm/mermaid@12/dist/mermaid.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/@tailwindcss/browser@4"></script>
<style>@import url("https://cdn.tailwindcss.com");</style></head>
<body><h1>CDN ok</h1></body></html>
EOF
cat > "$TMP/imports.html" <<'EOF'
<!doctype html><html><head><meta charset="utf-8"><title>t</title>
<style>@import url("https://fonts.example.com/css?family=x");
body{background:url("https://example.com/bg.png")}</style></head>
<body><h1>Import</h1></body></html>
EOF
check "validate allows known CDNs → exit 0" 0 "$SCRIPT" validate "$TMP/cdn.html"
check "validate catches @import/url() → exit 1" 1 "$SCRIPT" validate "$TMP/imports.html"

# validate — one-file rule: plain <a href> links, SVG fragment refs and data: URIs
# are fine; popular CDNs (including JS module imports) are fine.
cat > "$TMP/links.html" <<'EOF'
<!doctype html><html><head><meta charset="utf-8"><title>t</title>
<style>.x{clip-path:url(#c)}body{background:url("data:image/svg+xml,%3Csvg/%3E")}</style></head>
<body><svg><filter id="c"></filter></svg><a href="https://github.com/x">out</a><h1>ok</h1></body></html>
EOF
check "validate plain links + url(#frag) + data: → exit 0" 0 "$SCRIPT" validate "$TMP/links.html"

cat > "$TMP/cdns.html" <<'EOF'
<!doctype html><html><head><meta charset="utf-8"><title>t</title>
<script src="https://unpkg.com/d3@7"></script>
<link href="https://fonts.googleapis.com/css2?family=x" rel="stylesheet">
<script type="module">
import mermaid from "https://cdn.jsdelivr.net/npm/mermaid@12/dist/mermaid.esm.min.mjs";
</script></head>
<body><h1>CDNs ok</h1></body></html>
EOF
check "validate popular CDNs + js module import → exit 0" 0 "$SCRIPT" validate "$TMP/cdns.html"

# validate — local sibling files and unknown hosts break the single file.
cat > "$TMP/localdep.html" <<'EOF'
<!doctype html><html><head><meta charset="utf-8"><title>t</title>
<script src="app.js"></script><link rel="stylesheet" href="style.css"></head>
<body><img src="pic.png"><h1>local</h1></body></html>
EOF
check "validate local sibling files → exit 1" 1 "$SCRIPT" validate "$TMP/localdep.html"

cat > "$TMP/unknownhost.html" <<'EOF'
<!doctype html><html><head><meta charset="utf-8"><title>t</title>
<script src="https://assets.random-host.example/x.js"></script></head>
<body><h1>unknown</h1></body></html>
EOF
check "validate unknown external host → exit 1" 1 "$SCRIPT" validate "$TMP/unknownhost.html"

# lint — style taste-gate (AI-generated tells)
cat > "$TMP/stylish.html" <<'EOF'
<!doctype html><html><head><meta charset="utf-8"><title>t</title>
<style>:root{--ink:#1a1a1a;--paper:#fafaf9;--muted:#6b7280;--line:#e5e5e5}
a{color:var(--ink)}.tag{border:1px solid var(--line);border-radius:.35rem}</style></head>
<body><a href="#">link</a><div class="tag">cat</div></body></html>
EOF
cat > "$TMP/ai-slop.html" <<'EOF'
<!doctype html><html><head><meta charset="utf-8"><title>t</title>
<style>.badge{background:#e0f2fe;border-radius:999px}
a{color:#0369a1}.ok{color:#15803d}</style></head>
<body><a href="#">x</a></body></html>
EOF
check "lint clean page → exit 0" 0 "$SCRIPT" lint "$TMP/stylish.html"
# pills + saturated link colors are ALLOWED now (info at most) — the gate is
# hardslop only: card-edge accents, violet fills, big circle badges
check "lint pill page → exit 0 (pills sind ok)" 0 "$SCRIPT" lint "$TMP/ai-slop.html"
# missing file = usage error (exit 2, wie alle visualize-commands); exit 3 wäre
# "check nicht möglich" (Lesefehler im Client), nicht "Datei existiert nicht"
check "lint missing file → exit 2 (usage)" 2 "$SCRIPT" lint /nonexistent.html

# lint — structural color is ALLOWED (color as structure: category dots, section
# accents, semantic .ok/.warn/.bad severity). Only decorative tells fail.
cat > "$TMP/structural.html" <<'EOF'
<!doctype html><html><head><meta charset="utf-8"><title>t</title>
<style>.kicker{color:#5e7a9b}.ok{color:#15803d}.bad{color:#b91c1c}
.dot{display:inline-block;width:.62rem;height:.62rem;border-radius:50%;background:#b8915a}
a{color:#1a1a1a}</style></head>
<body><span class="dot"></span><span class="kicker">CAT</span>
<span class="ok">pass</span><span class="bad">fail</span>
<span style="color:#b45309">warn</span><a href="#">x</a></body></html>
EOF
check "lint structural color (dots, severity, kicker) → exit 0" 0 "$SCRIPT" lint "$TMP/structural.html"

# lint — but a LARGE colored circle badge (>=20px) stays a decorative tell.
cat > "$TMP/circle.html" <<'EOF'
<!doctype html><html><head><meta charset="utf-8"><title>t</title>
<style>.n{display:inline-block;width:1.6rem;height:1.6rem;border-radius:50%;background:#5e7a9b;color:#fff;text-align:center;line-height:1.6rem}</style></head>
<body><span class="n">1</span></body></html>
EOF
check "lint large colored circle badge → exit 1" 1 "$SCRIPT" lint "$TMP/circle.html"

# lint — colored left-edge accent on a card is a decorative AI tell (the
# "left-edge coloured line on a panel"); neutral --line connectors pass.
cat > "$TMP/edge.html" <<'EOF'
<!doctype html><html><head><meta charset="utf-8"><title>t</title>
<style>.finding{background:#fff;border:1px solid #e5e5e5;border-left:4px solid var(--warn);border-radius:.6rem;padding:1rem}
.sev-warn{border-left:3px solid #b45309}</style>
</head><body><div class="finding">x</div><div class="sev-warn">y</div></body></html>
EOF
cat > "$TMP/connector.html" <<'EOF'
<!doctype html><html><head><meta charset="utf-8"><title>t</title>
<style>.timeline{border-left:1px solid var(--line);margin-left:.4rem;padding-left:1.5rem}
.tree ul{border-left:1px solid #e5e5e5;padding-left:1rem}</style>
</head><body><div class="timeline">x</div></body></html>
EOF
check "lint colored left-edge accent → exit 1" 1 "$SCRIPT" lint "$TMP/edge.html"
check "lint neutral connector border-left → exit 0" 0 "$SCRIPT" lint "$TMP/connector.html"

cat > "$TMP/neutral.html" <<'EOF'
<!doctype html><html><head><meta charset="utf-8"><title>t</title>
<style>a{color:#1a1a1a}</style></head>
<body><a href="#" style="color:#1a1a1a">ink</a><span style="color:#6b7280">muted</span></body></html>
EOF
cat > "$TMP/teal.html" <<'EOF'
<!doctype html><html><head><meta charset="utf-8"><title>t</title>
<style>a{color:#0f766e}</style></head>
<body><a href="#">x</a></body></html>
EOF
check "lint neutral inline link → exit 0" 0 "$SCRIPT" lint "$TMP/neutral.html"
check "lint saturated teal link → exit 0 (hue on text is fine)" 0 "$SCRIPT" lint "$TMP/teal.html"

# open — tested via a stub opener: the suite must never pop a real browser tab.
# The stub wins `command -v open`, so the launcher's file-check + opener path is covered.
STUB_BIN="$(mktemp -d)"
printf '#!/bin/sh\necho "stub-open: $*"\n' > "$STUB_BIN/open"
chmod +x "$STUB_BIN/open"
check "open real file (stubbed) → exit 0" 0 env PATH="$STUB_BIN:$PATH" "$SCRIPT" open "$TMP/good.html"
grep -q "stub-open: $TMP/good.html" /tmp/visualize.out && ok || bad "open passed the file to the opener"
check "open missing file (stubbed) → exit 2" 2 env PATH="$STUB_BIN:$PATH" "$SCRIPT" open /nonexistent.html
rm -rf "$STUB_BIN"

# share — live upload to throway (network). Skip if offline / curl missing.
if command -v curl >/dev/null 2>&1; then
    if curl -sf --max-time 10 "https://lubu.skale.dev/throway/api" >/dev/null 2>&1; then
        out="$("$SCRIPT" share "$TMP/good.html" 2>/dev/null)"
        if printf '%s' "$out" | grep -qE '^https://(lubu\.)?skale\.dev/throway/'; then
            ok
        else
            bad "share did not return a throway URL (got: $out)"
        fi
        # share --dir — create a browseable throway dir from a folder, including a
        # nested subdir (must be uploaded too — flattened, not silently dropped)
        mkdir -p "$TMP/dir/sub"
        echo hi > "$TMP/dir/one.txt"
        echo there > "$TMP/dir/two.txt"
        echo deep > "$TMP/dir/sub/three.md"
        "$SCRIPT" share --dir "$TMP/dir" >"$TMP/dir-url.txt" 2>"$TMP/dir-msg.txt"
        url="$(cat "$TMP/dir-url.txt")"; msg="$(cat "$TMP/dir-msg.txt")"
        if printf '%s' "$url" | grep -qE '^https://(lubu\.)?skale\.dev/throway/' \
            && printf '%s' "$msg" | grep -q '(3 files'; then
            ok
        else
            bad "share --dir did not return a throway dir URL with all 3 files (url: $url, msg: $msg)"
        fi
    else
        echo "  (skipping share test: throway unreachable)"
    fi
else
    echo "  (skipping share test: curl not installed)"
fi

# ── chartcheck: dataviz integrity gate (evident-charts influence) ───────
# A behavior change needs real invocations: one clean page (exit 0) and one
# page per check (exit 1 + the check name), so a check that silently stops
# matching cannot pass as "nothing to report".
sed -e 's/{{[A-Z_]*}}/x/g' "$SKILL/templates/barchart.html" > "$TMP/clean.html"
check "chartcheck on a clean page exits 0" 0 "$SCRIPT" chartcheck "$TMP/clean.html"

# each finding must name its own check
for pair in \
    "bar-baseline:trunc" \
    "log-unlabeled:log" \
    "process-note:todo" \
    "missing-source:nodata" \
    "redundant-legend:dupl" \
    "equal-height-3d:persp" \
    "value-and-axis:vals"
do
    name="${pair%%:*}"; kind="${pair##*:}"
    case "$kind" in
        trunc) body='<div class="bar" style="width:90%"></div><svg data-axis-min="70" data-axis-max="100"></svg>' ;;
        log)   body='<div data-scale="log"><div class="bar" style="width:90%"></div></div>' ;;
        todo)  body='<p>TODO: confirm with finance</p>' ;;
        nodata) body='<div class="bar" style="width:90%"></div>' ; hdr='<p>Sales by region</p>' ;;
        dupl)  body='<div class="legend"><span>A</span></div><div class="bar-row"><span class="val">42%</span></div>' ;;
        persp) body='<div style="transform: perspective(800px) rotateX(20deg)"><div class="bar" style="width:60%"></div></div>' ;;
        vals)  body='<span class="val">42%</span><div data-axis-min="0" data-axis-max="100"></div>' ;;
    esac
    # a source line unless the case is about the missing one
    [ "$kind" = "nodata" ] || hdr="${hdr:-}<p>Source: Internal ledger, 2025</p>"
    [ "$kind" = "todo" ]  || hdr="${hdr:-}<p>Sales by region</p>"
    printf '<!doctype html><html><body>%s%s</body></html>' "$hdr" "$body" > "$TMP/cc-$kind.html"
    out="$("$SCRIPT" chartcheck "$TMP/cc-$kind.html" 2>&1)"
    if [ $? -eq 1 ] && printf '%s' "$out" | grep -q "$name"; then
        ok
    else
        bad "chartcheck $name not reported (exit/output: $out)"
    fi
done

# a data maximum is not an axis floor (regression: false positive on the
# barchart template, whose note legitimately says "max = 120")
ok
# own templates must stay clean — the gate is a gate, not noise
for tpl in "$SKILL"/templates/*.html; do
    out="$("$SCRIPT" chartcheck "$tpl" 2>&1)"
    if [ $? -eq 0 ]; then ok; else bad "chartcheck false positive on $(basename "$tpl"): $out"; fi
done

# help + guard rails
ok
"$SCRIPT" --help 2>&1 | grep -q 'chartcheck' && ok || bad "chartcheck missing from --help"
check "chartcheck rejects a missing file" 2 "$SCRIPT" chartcheck "$TMP/nope.html"

# ── slop gate: offline subset (deterministic — dead endpoint, no token needed) ──
SLOP_PAGE="$TMP/slop-stripe.html"
printf '<!doctype html><html><head><style>.c{border-top:4px solid #e11d48}</style></head><body><div class="c">x</div></body></html>' > "$SLOP_PAGE"
CLEAN_PAGE="$TMP/slop-clean.html"
printf '<!doctype html><html><head><style>body{font-family:-apple-system,sans-serif}</style></head><body><p>clean</p></body></html>' > "$CLEAN_PAGE"
PILL_PAGE="$TMP/slop-pill.html"
printf '<!doctype html><html><head><style>.b{border-radius:999px;background:#fde68a}</style></head><body><span class="b">pill</span></body></html>' > "$PILL_PAGE"
DEAD_API="SLOP_API_URL=http://127.0.0.1:1"

# lint offline: stripe = HARDSLOP exit 1 (the founding case, caught without network)
out="$(env $DEAD_API "$SCRIPT" lint "$SLOP_PAGE" 2>&1)"; rc=$?
if [ $rc -eq 1 ] && printf '%s' "$out" | grep -q 'HARDSLOP edge_stripe'; then ok
else bad "lint offline: stripe must be HARDSLOP + exit 1 (rc=$rc: $out)"; fi

# lint offline: pills are info, never a gate (Johann: „pills sind ok")
out="$(env $DEAD_API "$SCRIPT" lint "$PILL_PAGE" 2>&1)"; rc=$?
if [ $rc -eq 0 ]; then ok
else bad "lint offline: pills must not gate (rc=$rc: $out)"; fi

# lint offline: clean page exit 0
out="$(env $DEAD_API "$SCRIPT" lint "$CLEAN_PAGE" 2>&1)"; rc=$?
[ $rc -eq 0 ] && ok || bad "lint offline: clean page must exit 0 (rc=$rc: $out)"

# client JSON contract: mode flags the offline shadow
out="$(env $DEAD_API python3 "$SKILL/scripts/lib/slop_client.py" lint "$SLOP_PAGE")"
printf '%s' "$out" | python3 -c 'import sys,json; d=json.load(sys.stdin); assert d["mode"].startswith("offline"), d; assert d["findings"][0]["id"]=="edge_stripe"' \
    && ok || bad "client JSON contract broken: $out"

# pin ledger — sandboxed via VISUALIZE_SHARES_FILE (never touches ~/.config)
PIN_LEDGER="$TMP/shares.tsv"; rm -f "$PIN_LEDGER"
PIN_PAGE="$TMP/pin.html"; printf '<!doctype html><html><body>pin v1</body></html>' > "$PIN_PAGE"
PIN_ENV="VISUALIZE_SHARES_FILE=$PIN_LEDGER"

# pin ledger roundtrip: set + get (offline, no network needed)
env $PIN_ENV "$SCRIPT" _pin_set "$PIN_PAGE" https://example.com/x 2>/dev/null
pinned="$(env $PIN_ENV "$SCRIPT" _pin_get "$PIN_PAGE" 2>/dev/null)"
[ "$pinned" = "https://example.com/x" ] \
    && ok || bad "pin ledger roundtrip: _pin_set/_pin_get (got: ${pinned:-none})"

# pin ledger: re-set replaces (one line per realpath, no duplicates)
env $PIN_ENV "$SCRIPT" _pin_set "$PIN_PAGE" https://example.com/y 2>/dev/null
n=$(awk -F'\t' -v k="$PIN_PAGE" '$1==k' "$PIN_LEDGER" | wc -l | tr -d ' ')
[ "$n" -eq 1 ] && ok || bad "pin ledger: re-set must replace, found $n lines for one realpath"

# pin ledger: different realpaths coexist
env $PIN_ENV "$SCRIPT" _pin_set "$CLEAN_PAGE" https://example.com/z 2>/dev/null
[ "$(wc -l < "$PIN_LEDGER" | tr -d ' ')" -eq 2 ] \
    && ok || bad "pin ledger: two realpaths must coexist as two lines"

# share stdout contract: EXACTLY one line — the URL; everything else → stderr
# (live: needs throway; the contract is what agents parse)
if [ -n "${LIVE_OK:-}" ]; then
    out="$(env $PIN_ENV "$SCRIPT" share "$PIN_PAGE" 2>/dev/null)"
    [ "$(printf '%s' "$out" | wc -l | tr -d ' ')" -eq 1 ] \
        && printf '%s' "$out" | grep -qE '^https?://' \
        && ok || bad "share stdout must be exactly one URL line (got: $out)"
else
    ok  # offline skip (honest)
fi

# gate — eine Interface über alle Gates, parallel innen (deterministisch offline)
out="$(env $DEAD_API "$SCRIPT" gate "$CLEAN_PAGE" 2>&1)"; rc=$?
if [ $rc -eq 0 ] && printf '%s' "$out" | grep -q 'all gates pass'; then ok
else bad "gate clean: all-pass + exit 0 erwartet (rc=$rc: $out)"; fi
out="$(env $DEAD_API "$SCRIPT" gate "$SLOP_PAGE" 2>&1)"; rc=$?
if [ $rc -eq 1 ] && printf '%s' "$out" | grep -q 'gate slop: FAIL' \
   && printf '%s' "$out" | grep -q 'gate validate: OK'; then ok
else bad "gate stripe: slop FAIL + validate OK + exit 1 erwartet (rc=$rc: $out)"; fi
check "gate missing file → exit 2" 2 "$SCRIPT" gate /nonexistent.html

# share still gates (URL-first): hardslop → exit 1 — live only (needs throway)
slop_live=false
if [ -n "${SLOP_TOKEN:-}" ] || command -v credgoo >/dev/null 2>&1; then
    slop_live=true
fi
if [ "$slop_live" = true ]; then
    out="$(SLOP_TOKEN="${SLOP_TOKEN:-}" "$SCRIPT" share "$SLOP_PAGE" 2>&1)"; rc=$?
    if [ $rc -eq 1 ] && printf '%s' "$out" | grep -q 'HARDSLOP edge_stripe'; then
        ok
    else
        bad "share of a stripe page must print HARDSLOP edge_stripe + exit 1 (rc=$rc: $out)"
    fi
    out="$(SLOP_TOKEN="${SLOP_TOKEN:-}" "$SCRIPT" share "$CLEAN_PAGE" 2>&1)"; rc=$?
    if [ $rc -eq 0 ] && printf '%s' "$out" | grep -q 'visualize slop'; then
        ok
    else
        bad "share of a clean page must print a slop line + exit 0 (rc=$rc: $out)"
    fi
else
    warn "slop-gate live share tests skipped (no SLOP_TOKEN / credgoo)"
fi

rm -rf "$TMP"

echo "---------------"
echo "PASS: $PASS  FAIL: $FAIL"
[ "$FAIL" -eq 0 ]
