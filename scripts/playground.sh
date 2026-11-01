#!/usr/bin/env bash
# playground.sh — der saubere Playground-Roster für externe Skills.
#
# Regeln (docs/development.md Playgrounding-Regime, Nutzer-Regel 2026-11-01):
#   - Playground-Skills sind NIEMALS im pi-Roster (kein .pi/skills-Symlink,
#     kein ~/.agents/skills-Eintrag) — Play läuft über Session-Flag oder
#     read-and-follow, Adoption nur auf ausdrücklichen Wunsch.
#   - Clone-Farm: .clones/<name> (gitignored) — eine Maschine, ein Ort.
#   - Status/Verdicts leben in watchlist.jsonl (repo, geteilt).
#
# Usage:
#   scripts/playground.sh list           # Roster: was liegt bereit? + Play-Befehl
#   scripts/playground.sh play <name>    # fertigen Play-Befehl drucken
#   scripts/playground.sh doctor         # Roster-Pollution + tote Links finden
#   scripts/playground.sh clean <name>   # Clone entfernen + Strays melden
set -u

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FARM="$REPO_DIR/.clones"
WATCHLIST="$REPO_DIR/watchlist.jsonl"

# Status aus der watchlist (oder "—" wenn nicht geführt)
wl_status() {
    [ -f "$WATCHLIST" ] || { echo "—"; return; }
    local s
    s=$(grep "\"name\": *\"$1\"" "$WATCHLIST" 2>/dev/null | tail -1 \
        | sed -En 's/.*"status": *"([a-z-]+)".*/\1/p')
    echo "${s:-nicht in watchlist}"
}

# alle SKILL.md eines Clones (bis Tiefe 4; hidden-Duplikat-Bäume wie .openclaw/ überspringen).
# Von INNEN laufen lassen: der Farm-Pfad selbst enthält .clones — ein absolutes
# -not -path "*/.*" würde dort alles matchen (BSD-find-Falle, 2026-11-01).
clone_skills() {
    (cd "$1" 2>/dev/null && find . -maxdepth 4 -name SKILL.md -not -path "*/.*" -not -path "*/node_modules/*" 2>/dev/null | sort) \
        | while read -r rel; do printf '%s/%s\n' "$1" "${rel#./}"; done
}

# DER kanonische Einstiegs-Skill eines Clones: <farm>/<name>/skills/<name>/SKILL.md,
# sonst der erste nicht-hidden Treffer.
clone_main_skill() {
    local d="$1" name="$2"
    local exact; exact=$(clone_skills "$d" | grep -E "/$name/SKILL.md$" | head -1)
    [ -n "$exact" ] && { echo "$exact"; return; }
    clone_skills "$d" | head -1
}

# Frontmatter-description sauber extrahieren (ein- UND mehrzeilig, YAML '>')
skill_desc() {
    python3 - "$1" <<'PYEOF'
import sys, re
try:
    text = open(sys.argv[1], encoding="utf-8", errors="replace").read(4000)
except OSError:
    sys.exit(0)
m = re.match(r"^---\n(.*?)\n---", text, re.DOTALL)
if not m:
    sys.exit(0)
fm = m.group(1)
dm = re.search(r"^description:\s*(.*)$", fm, re.MULTILINE)
if not dm:
    sys.exit(0)
val = dm.group(1).strip()
if val in (">", "|-", "|", ">-"):  # mehrzeilig: eingerückte Zeilen bis zum nächsten Key
    lines = []
    for line in fm[dm.end():].splitlines():
        if line.startswith(("  ", "\t")):
            lines.append(line.strip())
        elif line.strip() == "":
            continue
        else:
            break
    val = " ".join(lines)
print(val[:100])
PYEOF
}

cmd_list() {
    echo "Playground-Roster — Clone-Farm $FARM"
    echo "(gitignored; Play = Session-Flag, nie im Roster; Verdicts → watchlist.jsonl)"
    echo
    local found=0
    for d in "$FARM"/*/; do
        [ -d "$d" ] || continue
        found=1
        local name; name="$(basename "$d")"
        local n; n=$(clone_skills "$d" | wc -l | tr -d ' ')
        printf '▸ %s — %s SKILL.md — watchlist: %s\n' "$name" "$n" "$(wl_status "$name")"
        clone_skills "$d" | while read -r f; do
            local skill; skill="$(basename "$(dirname "$f")")"
            local desc; desc=$(skill_desc "$f")
            printf '    · %-22s %s\n' "$skill" "$desc"
        done
    done
    [ "$found" -eq 0 ] && echo "  (leer — Clone mit: git clone <url> .clones/<name>)"
    echo
    echo "Play:   scripts/playground.sh play <clone-name>"
}

cmd_play() {
    local name="${1:-}"
    [ -z "$name" ] && { echo "usage: playground.sh play <clone-name>" >&2; exit 2; }
    local d="$FARM/$name"
    [ -d "$d" ] || { echo "error: kein Clone '$name' in $FARM" >&2; exit 1; }
    local first; first=$(clone_main_skill "$d" "$name")
    [ -z "$first" ] && { echo "error: keine SKILL.md in $d gefunden" >&2; exit 1; }
    echo "# Play (Session-Flag — unslop & co sind NICHT im Roster):"
    echo "cd ~/code/kontext.one/klark0   # oder wo der Play hingehört"
    echo "pi --skill '$first'"
    echo
    echo "# Alternative in einer LAUFENDEN Session (read-and-follow, spurlos):"
    echo "#   'Read $first und befolge es gegen <ziel>'"
}

cmd_doctor() {
    local problems=0
    echo "Playground-Doctor — Roster-Pollution & tote Links"
    # 1. Links, die IN die Clone-Farm zeigen (dürfen nur nach .clones resolved: ok
    #    für ~/.pi/agent/skills wäre POLLUTION — dort liegen sie standardmäßig nicht)
    for dir in "$HOME/.pi/agent/skills" "$HOME/.agents/skills" \
               "$HOME/code/kontext.one/klark0/.pi/skills"; do
        [ -d "$dir" ] || continue
        for l in "$dir"/*; do
            [ -L "$l" ] || continue
            local t; t="$(readlink "$l")"
            case "$t" in
                */.clones/*)
                    echo "  ⚠ POLLUTION: $l → $t (Playground-Skill im Roster — entfernen)"
                    problems=$((problems+1)) ;;
            esac
            [ -e "$l" ] || { echo "  ✗ TOT: $l → $t"; problems=$((problems+1)); }
        done
    done
    # 2. Farm-Check: tote clones (keine SKILL.md)
    for d in "$FARM"/*/; do
        [ -d "$d" ] || continue
        [ -z "$(clone_skills "$d")" ] && {
            echo "  ⚠ FARM: $d enthält keine SKILL.md (falscher Clone?)"; problems=$((problems+1)); }
    done
    [ "$problems" -eq 0 ] && echo "  ✓ sauber — keine Pollution, keine toten Links, Farm ok"
    return "$problems"
}

cmd_clean() {
    local name="${1:-}"
    [ -z "$name" ] && { echo "usage: playground.sh clean <clone-name>" >&2; exit 2; }
    local d="$FARM/$name"
    [ -d "$d" ] || { echo "error: kein Clone '$name'" >&2; exit 1; }
    echo "Strays, die nach $d zeigen (bitte selbst entfernen falls listed):"
    cmd_doctor | grep -F "$d" || echo "  (keine)"
    rm -rf "$d"
    echo "✓ $d entfernt. Verdict in watchlist.jsonl pflegen (falls noch offen)."
}

case "${1:-list}" in
    list)  cmd_list ;;
    play)  shift; cmd_play "$@" ;;
    doctor) cmd_doctor ;;
    clean) shift; cmd_clean "$@" ;;
    *) echo "usage: playground.sh list|play <name>|doctor|clean <name>" >&2; exit 2 ;;
esac
