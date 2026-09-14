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
