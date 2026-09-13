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
[ -f "$SKILL/references/structures.md" ] && ok || bad "structures.md missing"
[ -f "$SKILL/references/modules.md" ] && ok || bad "modules.md missing"
[ -f "$SKILL/references/report.md" ] && ok || bad "report.md missing"
[ -f "$SKILL/references/promptlib.md" ] && ok || bad "promptlib.md missing"
[ -f "$SKILL/references/patterns.md" ] && ok || bad "patterns.md missing"
[ -f "$SKILL/references/output.md" ] && ok || bad "output.md missing"
[ -f "$SKILL/references/html-patterns.md" ] && ok || bad "html-patterns.md missing"
[ -f "$SKILL/references/routing.md" ] && ok || bad "routing.md missing"
# SKILL.md convention: under 100 lines (routing depth lives in references/)
[ "$(wc -l < "$SKILL/SKILL.md" | tr -d ' ')" -le 99 ] && ok || bad "SKILL.md over 99 lines"

# templates
for t in cards repo-tree system-map report mermaid; do
    [ -f "$SKILL/templates/$t.html" ] && ok || bad "template $t.html missing"
done
[ -f "$SKILL/templates/README.md" ] && ok || bad "templates/README.md missing"

# templates must pass their own gates (house style + self-contained)
for t in cards repo-tree system-map report mermaid; do
    check "lint template $t.html → exit 0" 0 "$SCRIPT" lint "$SKILL/templates/$t.html"
    check "validate template $t.html → exit 0" 0 "$SCRIPT" validate "$SKILL/templates/$t.html"
done

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
check "lint AI-slop page → exit 1" 1 "$SCRIPT" lint "$TMP/ai-slop.html"
check "lint missing file → exit 2" 2 "$SCRIPT" lint /nonexistent.html

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
check "lint saturated teal accent → exit 1" 1 "$SCRIPT" lint "$TMP/teal.html"

# open (macOS `open` present) — just check it accepts a real file
if command -v open >/dev/null 2>&1; then
    check "open real file → exit 0" 0 "$SCRIPT" open "$TMP/good.html"
else
    echo "  (skipping open test: no opener found)"
fi

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
        out="$("$SCRIPT" share --dir "$TMP/dir" 2>/dev/null)"
        if printf '%s' "$out" | grep -qE '^https://(lubu\.)?skale\.dev/throway/' \
            && printf '%s' "$out" | grep -q '(3 files'; then
            ok
        else
            bad "share --dir did not return a throway dir URL with all 3 files (got: $out)"
        fi
    else
        echo "  (skipping share test: throway unreachable)"
    fi
else
    echo "  (skipping share test: curl not installed)"
fi

rm -rf "$TMP"

echo "---------------"
echo "PASS: $PASS  FAIL: $FAIL"
[ "$FAIL" -eq 0 ]
