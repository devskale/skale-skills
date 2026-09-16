"""Noise-Konfiguration — alle Pattern und Regex-Bausteine an EINER Stelle.

Enthält nur Daten (keine Logik). Die fertigen Regex-Patterns werden hier
als mehrzeilige Strings definiert, damit im Code (detector.py) keine langen
Regex-Schlangen stehen. detector.py compiliert diese Patterns nur noch.
"""

from __future__ import annotations

# ══════════════════════════════════════════════════════════════════════════
# 1. SEMAPHORE-Tags — komplette Tags, die immer gelöscht werden
#    (kein Klassen-Check nötig)
# ══════════════════════════════════════════════════════════════════════════
SEMAPHORE_TAGS: frozenset[str] = frozenset({
    "script", "style", "noscript", "svg", "meta", "link", "head",
    "header", "nav", "footer", "aside", "menu", "toolbar",
})

# Regex: <tag ...> ... </tag> (DOTALL für mehrzeilige Inhalte)
SEMAPHORE_PATTERN: str = (
    r"<({tags})[^>]*>.*?</\1>"
).format(tags="|".join(SEMAPHORE_TAGS))


# ══════════════════════════════════════════════════════════════════════════
# 2. Klassen-/ID-Keywords — Elemente, deren class=/id= ein Keyword enthält
# ══════════════════════════════════════════════════════════════════════════

# Cookie/Consent-Banner
COOKIE_KEYWORDS: frozenset[str] = frozenset({
    "cookie", "consent", "cookiebot", "gdpr", "popup", "overlay",
    "iab", "cc-window", "onetrust", "cmp",
})

# Werbung / Affiliate (inkl. In-Article Ads)
AD_KEYWORDS: frozenset[str] = frozenset({
    "ad-container", "ad-banner", "advertisement", "promo", "affiliate",
    "in-article-ad", "sponsored", "ad-slot", "adsbygoogle",
})

# Sidebar / Widget / Navigation
SIDEBAR_KEYWORDS: frozenset[str] = frozenset({
    "sidebar", "widget", "related-posts", "table-of-contents",
    "toc", "breadcrumbs", "breadcrumb", "page-nav", "pagination",
})

# Kombinierte Liste aller Klassen-Keywords
ALL_CLASS_KEYWORDS: frozenset[str] = (
    COOKIE_KEYWORDS | AD_KEYWORDS | SIDEBAR_KEYWORDS
)

# Schließ-Tags, die als "Ende" einer Noise-Region gelten
# (semantische Referenz; das balancierte Zählen nutzt BALANCE_TAGS)
CLOSING_TAGS: frozenset[str] = frozenset({
    "</div>", "</section>", "</aside>",
    "</main>", "</article>", "</li>", "</p>", "</span>",
})

# Regex-Baustein: Keyword muss in einem class=/id= Wert als ganzes Wort
# vorkommen. Begrenzt durch Anführungszeichen, Leerzeichen, '-' oder '_'.
# Verhindert Over-match auf:
#   - data-gdpr, data-cookie  (Attribut-NAME, nicht class=/id=)
#   - midwidget → widget      (Teilwort)
#   - promotion → promo       (Teilwort)
_CLASS_COMPONENT_BOUNDARY: str = r'(?<=["\s\'_-])(?:{keywords})(?=["\s\'_-])'

# Start-Pattern einer Noise-Region: <tag ... class/id="...keyword...">
# Erkennt den Anfang; das balancierte Ende findet der Detector per
# Tag-Zählung (Regex kann kein rekursives Matching).
CLASS_START_PATTERN: str = (
    r'<[^>]*?(?:class|id)\s*=\s*["\'][^"\']*'
    + _CLASS_COMPONENT_BOUNDARY.format(keywords="|".join(ALL_CLASS_KEYWORDS))
    + r'[^"\']*["\'][^>]*>'
)

# Tags, die bei der balancierten End-Findung einer Noise-Region gezählt
# werden (öffnend/schließend). Nur Container-Tags, die verschachtelt
# vorkommen können.
BALANCE_TAGS: frozenset[str] = frozenset({
    "div", "section", "aside", "main", "article", "li", "p", "span",
})


# ══════════════════════════════════════════════════════════════════════════
# 3. TEXT-LEVEL NOISE — Nav-Wiederholung & Cookie/Consent (Post-Extraktion)
#
# Der HTML-Detector (oben) wirkt VOR dem Rendering (Chrome-Pfad).
# w3m/lynx/jina/markdown liefern aber bereits gerenderten TEXT, in dem
# zwei Rauschklassen auftauchen (Issue fetch-url-nav-cookie-noise):
#   - NAV-WIEDERHOLUNG: komplette Seitenmenüs als (nummerierte) Linklisten
#     am Anfang/Ende — [N]-Marker, kurze Labels, wenig Fließtext
#   - COOKIE/CONSENT-PRÄAMBEL: Banner- und Wall-Texte vor dem Content
# Alle Schwellenwerte sind konservativ: wird ein Gate nicht bestanden,
# bleibt der Text unangetastet (False-Positive-Schutz für Listen-Content
# wie Changelogs).
# ══════════════════════════════════════════════════════════════════════════

# Consent-Phrasen (Regex-Bausteine, case-insensitive). Ein Block zählt als
# Consent-Block bei >= CONSENT_MIN_HITS VERSCHIEDENEN Treffern.
CONSENT_PATTERNS: frozenset[str] = frozenset({
    r"we use cookies",
    r"our use of cookies",
    r"cookies? (?:policy|notice|preferences|settings|consent)",
    r"accept (?:all )?cookies",
    r"reject (?:all )?cookies",
    r"manage (?:your )?cookies",
    r"cookie choices",
    r"consent to .{0,30}cookies",
    r"by (?:clicking|continuing|using).{0,40}(?:accept|agree)",
})

# Consent nur in der Head-Region scannen (Banner sitzen oben) und nur in
# kurzen Blöcken (langer Fließtext über Cookies = legitimer Artikel).
CONSENT_SCAN_BLOCKS: int = 30
CONSENT_MAX_BLOCK_CHARS: int = 600
CONSENT_MIN_HITS: int = 2
# Einzeilige Consent-Überschriften ("Cookie settings") direkt am Block.
CONSENT_HEADING_MAX_CHARS: int = 45

# Nav-Detektion: Gates für Head-/Tail-Cuts (alles muss erfüllt sein)
NAV_MIN_LINES: int = 6        # min. nav-artige Zeilen im Cut-Block
NAV_MIN_MARKERS: int = 8      # min. [N]-Linkmarker im Cut-Block
NAV_MIN_DENSITY: float = 0.5  # nav-artige / nicht-leere Zeilen im Block
NAV_HEAD_MAX_FRACTION: float = 0.4   # Head-Cut max. 40% der Zeilen (schützt Link-Verzeichnisse)
NAV_MIN_REMAINING_PROSE: int = 3   # nach dem Cut müssen ≥3 Prosa-Zeilen bleiben (Nav impliziert Folge-Content)
NAV_TAIL_MAX_FRACTION: float = 0.4  # Tail-Cut max. 40% der Zeilen (Footer kann auf kurzen Seiten viel ausmachen)
NAV_TAIL_NEUTRAL_GAP: int = 1 # max. 1 neutrale Zeile (Footer-Kategorie-Heading) zwischen Nav-Gruppen — mehr tunnelt in Content-Listen

# References-Tail: w3m/lynx hängen ans Ende eine nummerierte URL-Liste
# ("References / Visible links: / Hidden links:").
REF_MIN_URL_LINES: int = 5
REF_MAX_FRACTION: float = 0.7
