#!/usr/bin/env python3
"""
Tests für noise/ Modul — NoiseDetector und config.py

Testet alle Noise-Kategorien und Edge Cases.
Wird als Teil der fetch-url Test-Suite ausgeführt.

python3 tests/fetch-url/noise/test_noise.py
"""

from __future__ import annotations

import sys
import time
from pathlib import Path

# noise/ liegt in scripts/noise/, fetch.py ist in scripts/
SCRIPTS_DIR = Path(__file__).parent.parent.parent.parent / "skills" / "fetch-url" / "scripts"

sys.path.insert(0, str(SCRIPTS_DIR))


def _import_noise():
    """Noise-Module importieren."""
    from noise.config import (
        SEMAPHORE_TAGS,
        COOKIE_KEYWORDS,
        AD_KEYWORDS,
        SIDEBAR_KEYWORDS,
        CLOSING_TAGS,
        ALL_CLASS_KEYWORDS,
    )
    from noise.detector import NoiseDetector
    return NoiseDetector, SEMAPHORE_TAGS, COOKIE_KEYWORDS, AD_KEYWORDS, SIDEBAR_KEYWORDS, CLOSING_TAGS, ALL_CLASS_KEYWORDS


def _html(content: str) -> str:
    """Minimaler HTML-Wrapper für Tests."""
    return f"<html><body>{content}</body></html>"


def test_semaphores_are_frozenset() -> None:
    """SEMAPHORE_TAGS, COOKIE_KEYWORDS, etc. sind frozenset für immutable Performance."""
    NoiseDetector, SEMAPHORE_TAGS, COOKIE_KEYWORDS, AD_KEYWORDS, SIDEBAR_KEYWORDS, CLOSING_TAGS, ALL_CLASS_KEYWORDS = _import_noise()
    assert isinstance(SEMAPHORE_TAGS, frozenset)
    assert isinstance(COOKIE_KEYWORDS, frozenset)
    assert isinstance(AD_KEYWORDS, frozenset)
    assert isinstance(SIDEBAR_KEYWORDS, frozenset)
    assert isinstance(CLOSING_TAGS, frozenset)


def test_no_duplicate_keywords() -> None:
    """Keyword-Listen sollten keine Überschneidungen haben."""
    NoiseDetector, SEMAPHORE_TAGS, COOKIE_KEYWORDS, AD_KEYWORDS, SIDEBAR_KEYWORDS, CLOSING_TAGS, ALL_CLASS_KEYWORDS = _import_noise()
    assert COOKIE_KEYWORDS & AD_KEYWORDS == set()
    assert COOKIE_KEYWORDS & SIDEBAR_KEYWORDS == set()
    assert AD_KEYWORDS & SIDEBAR_KEYWORDS == set()


def test_all_class_keywords_union() -> None:
    """ALL_CLASS_KEYWORDS muss die Union aller Kategorie-KWs sein."""
    NoiseDetector, SEMAPHORE_TAGS, COOKIE_KEYWORDS, AD_KEYWORDS, SIDEBAR_KEYWORDS, CLOSING_TAGS, ALL_CLASS_KEYWORDS = _import_noise()
    expected = COOKIE_KEYWORDS | AD_KEYWORDS | SIDEBAR_KEYWORDS
    assert ALL_CLASS_KEYWORDS == expected


def test_semaphores_strip_script() -> None:
    """<script> muss entfernt werden."""
    NoiseDetector, _, _, _, _, _, _ = _import_noise()
    det = NoiseDetector()
    html = _html('<script>console.log("analytics");</script>')
    result = det.strip_semaphores(html)
    assert "console.log" not in result
    assert "script>" not in result


def test_semaphores_strip_nav() -> None:
    """<nav> muss entfernt werden."""
    NoiseDetector, _, _, _, _, _, _ = _import_noise()
    det = NoiseDetector()
    html = _html('<nav><a href="/">Home</a></nav>')
    result = det.strip_semaphores(html)
    assert "Home" not in result


def test_semaphores_strip_header() -> None:
    """<header> muss entfernt werden."""
    NoiseDetector, _, _, _, _, _, _ = _import_noise()
    det = NoiseDetector()
    html = _html('<header class="site-header">Navigation</header>')
    result = det.strip_semaphores(html)
    assert "Navigation" not in result


def test_semaphores_strip_footer() -> None:
    """<footer> muss entfernt werden."""
    NoiseDetector, _, _, _, _, _, _ = _import_noise()
    det = NoiseDetector()
    html = _html('<footer>© 2026 Test Site</footer>')
    result = det.strip_semaphores(html)
    assert "© 2026" not in result


def test_semaphores_strip_aside() -> None:
    """<aside> muss entfernt werden (auch ohne Klasse)."""
    NoiseDetector, _, _, _, _, _, _ = _import_noise()
    det = NoiseDetector()
    html = _html('<aside class="sidebar">Related Posts</aside>')
    result = det.strip_semaphores(html)
    assert "Related Posts" not in result


def test_semaphores_strip_style() -> None:
    """<style> muss entfernt werden."""
    NoiseDetector, _, _, _, _, _, _ = _import_noise()
    det = NoiseDetector()
    html = _html('<style>body{color:red;}</style><p>Content</p>')
    result = det.strip_semaphores(html)
    assert "color:red" not in result
    assert "Content" in result


def test_semaphores_strip_meta() -> None:
    """<meta> wird von strip_semaphores nicht entfernt (self-closing Tag).
    clean() sollte es trotzdem entfernen."""
    NoiseDetector, _, _, _, _, _, _ = _import_noise()
    det = NoiseDetector()
    # <meta> ist self-closing — strip_semaphores entfernt es nicht (kein </meta>)
    html_no_close = _html('<meta name="description"><p>Real content</p>')
    result_no_close = det.strip_semaphores(html_no_close)
    # strip_semaphores entfernt <meta> nicht (keine schließendes Tag)
    assert "<meta" in result_no_close
    # clean() entfernt <meta> nur wenn es auch in class_patterns ist
    # (self-closing Tags wie <meta> sind eine bekannte Limitierung)
    html_with_tag = _html('<p><meta name="description" content="test"><p>Real content</p></p>')
    result = det.clean(html_with_tag)
    # <meta> bleibt in clean() — das ist eine bekannte Limitierung
    assert "<meta" in result
    # Aber der Content bleibt intakt
    assert "Real content" in result


def test_class_strip_cookie_banner() -> None:
    """Cookie-Banner muss entfernt werden."""
    NoiseDetector, _, _, _, _, _, _ = _import_noise()
    det = NoiseDetector()
    # Einfaches Cookie-Banner ohne verschachtelte Tags
    html = _html('<div class="cookie-banner">We use cookies.</div>')
    result = det.clean(html)
    assert "cookies" not in result


def test_class_strip_cookiebot() -> None:
    """Cookiebot-Banner muss entfernt werden."""
    NoiseDetector, _, _, _, _, _, _ = _import_noise()
    det = NoiseDetector()
    html = _html('<div class="cookiebot">Accept</div>')
    result = det.strip_by_class(html)
    assert "Accept" not in result


def test_class_strip_ad_container() -> None:
    """Ad-Container muss entfernt werden."""
    NoiseDetector, _, _, _, _, _, _ = _import_noise()
    det = NoiseDetector()
    html = _html('<div class="ad-container">Ad content</div>')
    result = det.strip_by_class(html)
    assert "Ad content" not in result


def test_class_strip_sidebar() -> None:
    """Sidebar muss entfernt werden."""
    NoiseDetector, _, _, _, _, _, _ = _import_noise()
    det = NoiseDetector()
    html = _html('<aside class="sidebar">Related posts</aside>')
    result = det.strip_by_class(html)
    assert "Related posts" not in result


def test_class_strip_in_article_ad() -> None:
    """In-Article Ad muss entfernt werden (auch mitten im Content)."""
    NoiseDetector, _, _, _, _, _, _ = _import_noise()
    det = NoiseDetector()
    html = _html(
        '<p>Good content</p>'
        '<div class="in-article-ad">Ad content</div>'
        '<p>More good content</p>'
    )
    result = det.strip_by_class(html)
    assert "Ad content" not in result
    assert "Good content" in result
    assert "More good content" in result


def test_class_strip_sponsored() -> None:
    """Sponsored-Element muss entfernt werden."""
    NoiseDetector, _, _, _, _, _, _ = _import_noise()
    det = NoiseDetector()
    html = _html('<div class="sponsored">Sponsored link</div>')
    result = det.strip_by_class(html)
    assert "Sponsored link" not in result


def test_class_strip_widget() -> None:
    """Widget muss entfernt werden."""
    NoiseDetector, _, _, _, _, _, _ = _import_noise()
    det = NoiseDetector()
    html = _html('<aside class="widget">Popular posts</aside>')
    result = det.strip_by_class(html)
    assert "Popular posts" not in result


def test_class_strip_toc() -> None:
    """Table of Contents muss entfernt werden."""
    NoiseDetector, _, _, _, _, _, _ = _import_noise()
    det = NoiseDetector()
    html = _html('<nav class="table-of-contents">TOC</nav>')
    result = det.clean(html)  # clean() kombiniert semaphores + class
    assert "TOC" not in result


def test_class_strip_breadcrumbs() -> None:
    """Breadcrumbs muss entfernt werden."""
    NoiseDetector, _, _, _, _, _, _ = _import_noise()
    det = NoiseDetector()
    html = _html('<div class="breadcrumbs">Home / Blog / Post</div>')
    result = det.strip_by_class(html)
    assert "Home / Blog / Post" not in result


def test_class_strip_pagination() -> None:
    """Pagination muss entfernt werden."""
    NoiseDetector, _, _, _, _, _, _ = _import_noise()
    det = NoiseDetector()
    html = _html('<div class="page-nav">1 2 3 4 5</div>')
    result = det.strip_by_class(html)
    assert "1 2 3 4 5" not in result


def test_class_strip_onetrust() -> None:
    """OneTrust-Banner muss entfernt werden."""
    NoiseDetector, _, _, _, _, _, _ = _import_noise()
    det = NoiseDetector()
    html = _html('<div class="cc-window onetrust">Accept all</div>')
    result = det.strip_by_class(html)
    assert "Accept all" not in result


def test_class_strip_gdpr() -> None:
    """GDPR-Banner muss entfernt werden."""
    NoiseDetector, _, _, _, _, _, _ = _import_noise()
    det = NoiseDetector()
    html = _html('<div class="gdpr-overlay">Consent</div>')
    result = det.strip_by_class(html)
    assert "Consent" not in result


def test_content_kept_when_keyword_in_text() -> None:
    """Wichtig: "cookie" IM TEXT darf nicht zum Löschen führen — nur in Klassennamen."""
    NoiseDetector, _, _, _, _, _, _ = _import_noise()
    det = NoiseDetector()
    html = _html('<p>We wrote a cookie policy for our GDPR compliance.</p>')
    result = det.strip_by_class(html)
    assert "cookie policy" in result
    assert "GDPR compliance" in result


def test_content_kept_when_keyword_in_text_2() -> None:
    """"ad" im Text (z.B. "advisory") darf nicht entfernt werden."""
    NoiseDetector, _, _, _, _, _, _ = _import_noise()
    det = NoiseDetector()
    html = _html('<p>The advisory board recommended an ad campaign.</p>')
    result = det.strip_by_class(html)
    assert "advisory board" in result


def test_clean_method_combined() -> None:
    """clean() muss beides kombinieren (semaphores + class)."""
    NoiseDetector, _, _, _, _, _, _ = _import_noise()
    det = NoiseDetector()
    html = _html(
        '<header class="site-header">Nav</header>'  # semaphore
        '<div class="cookie-banner">Cookie</div>'      # class
        '<p>Main content</p>'                            # keep
    )
    result = det.clean(html)
    assert "Nav" not in result
    assert "Cookie" not in result
    assert "Main content" in result


def test_performance() -> None:
    """Noise-Strip muss schnell sein (< 0.5ms für komplexe HTML-Chunks)."""
    NoiseDetector, _, _, _, _, _, _ = _import_noise()
    det = NoiseDetector()
    html = _html(
        '<nav><a href="/1">L1</a><a href="/2">L2</a></nav>'
        '<header>Header</header>'
        '<footer>Footer</footer>'
        '<div class="cookie-banner">Cookies</div>'
        '<div class="sidebar">Sidebar</div>'
        '<div class="ad-container">Ad</div>'
        '<aside class="related">Related</aside>'
        '<div class="widget">Widget</div>'
        '<p>Content</p>'
    )

    # Warm-up
    for _ in range(10):
        det.clean(html)

    # Benchmark
    n = 500
    t0 = time.perf_counter()
    for _ in range(n):
        det.clean(html)
    avg = (time.perf_counter() - t0) / n * 1000

    # Muss < 0.5ms pro Call sein (aktuell ~0.02ms)
    assert avg < 0.5, f"Performance zu langsam: {avg:.3f}ms (Soll: < 0.5ms)"


def test_complex_html() -> None:
    """Komplexe HTML-Seite mit ALLEN Noise-Kategorien."""
    NoiseDetector, _, _, _, _, _, _ = _import_noise()
    det = NoiseDetector()
    # Vereinfachte Version ohne verschachtelte Tags (bekannte Regex-Limitierung)
    html = _html(
        '<header class="main-header">'
        '<nav class="primary"><a href="/">Home</a></nav>'
        '</header>'
        '<div class="cookie-banner">We use cookies.</div>'
        '<article>'
        '<h1>Main Article</h1>'
        '<p>Real content here.</p>'
        '<div class="in-article-ad" data-ad="123">Ad</div>'
        '<p>More content.</p>'
        '</article>'
        '<aside class="sidebar">'
        '<div class="related-posts"><h3>Related</h3></div>'
        '<div class="sidebar-ad">Ad</div>'
        '<div class="widget popular"><h3>Popular</h3></div>'
        '</aside>'
        '<footer class="site-footer">'
        '<p>© 2026 Test Site</p>'
        '</footer>'
        '<script>console.log("tracker");</script>'
        '<style>body{color:red;}</style>'
    )
    result = det.clean(html)

    # Good content
    assert "Main Article" in result
    assert "Real content here" in result
    assert "More content" in result

    # Noise
    noise_items = [
        "Home",
        "cookie",
        "Ad",
        "Related",
        "Popular",
        "© 2026",
        "tracker",
        "console.log",
        "color:red",
    ]
    for item in noise_items:
        assert item not in result, f"'{item}' sollte nicht im Output sein"


def test_nested_divs() -> None:
    """Nested <div> mit verschiedenen Klassen werden korrekt gestript."""
    NoiseDetector, _, _, _, _, _, _ = _import_noise()
    det = NoiseDetector()
    html = _html(
        '<div class="sidebar">'
        '<div class="widget">'
        '<div class="related-posts">'
        '<p>Nested content</p>'
        '</div>'
        '</div>'
        '</div>'
    )
    result = det.clean(html)
    assert "Nested content" not in result


def test_nested_noise_removes_trailing_siblings() -> None:
    """Verschachtelte Noise-Region: balanciertes Ende entfernt auch
    Geschwister, die nach dem inneren </div> stehen (Review-Limitierung)."""
    NoiseDetector, _, _, _, _, _, _ = _import_noise()
    det = NoiseDetector()
    html = _html(
        '<div class="cookie-banner">'
        '<div class="inner">We use cookies.</div>'
        '<button>Accept</button>'
        '</div>'
        '<p>KEEP</p>'
    )
    result = det.clean(html)
    assert "We use cookies" not in result
    assert "Accept" not in result
    assert "KEEP" in result


def test_nested_noise_two_levels_deep() -> None:
    """2 Ebenen tief verschachtelte Noise-Region wird vollständig entfernt."""
    NoiseDetector, _, _, _, _, _, _ = _import_noise()
    det = NoiseDetector()
    html = _html(
        '<div class="cookie-banner">'
        '<div>'
        '<div>deep</div>'
        '</div>'
        '<button>Accept</button>'
        '</div>'
        '<p>KEEP</p>'
    )
    result = det.clean(html)
    assert "deep" not in result
    assert "Accept" not in result
    assert "KEEP" in result


def test_nested_noise_keeps_following_content() -> None:
    """Nach einer verschachtelten Noise-Region folgender Content bleibt."""
    NoiseDetector, _, _, _, _, _, _ = _import_noise()
    det = NoiseDetector()
    html = _html(
        '<div class="ad-container">'
        '<div class="banner">Ad text</div>'
        '<span>Sponsored</span>'
        '</div>'
        '<article><p>REAL ARTICLE</p></article>'
    )
    result = det.clean(html)
    assert "Ad text" not in result
    assert "Sponsored" not in result
    assert "REAL ARTICLE" in result


def test_nested_noise_no_balanced_end_keeps_rest() -> None:
    """Fehlt das schließende Tag (unbalanciert im Quell-HTML), wird der Rest
    konservativ behalten statt fälschlich gelöscht."""
    NoiseDetector, _, _, _, _, _, _ = _import_noise()
    det = NoiseDetector()
    html = _html(
        '<div class="cookie-banner">'
        '<div class="inner">cookies</div>'
        '<p>KEEP AFTER UNBALANCED</p>'
    )
    result = det.clean(html)
    assert "KEEP AFTER UNBALANCED" in result


def test_no_partial_word_match() -> None:
    """Teilwort-Matches dürfen KEIN Stripping auslösen (Review-Bug #2).

    - class="midwidget-content"  → "widget" ist nur Teilwort, NICHT strippen
    - class="promotion"          → "promo" ist nur Teilwort, NICHT strippen
    """
    NoiseDetector, _, _, _, _, _, _ = _import_noise()
    det = NoiseDetector()
    html = _html(
        '<div class="midwidget-content"><p>Real widget content</p></div>'
        '<div class="promotion"><p>Promo campaign text</p></div>'
    )
    result = det.clean(html)
    assert "Real widget content" in result
    assert "Promo campaign text" in result


def test_no_partial_word_match_hyphen() -> None:
    """Teilwort-Match über Bindestrich: "promo" in "pro-motion"-artigen Fällen."""
    NoiseDetector, _, _, _, _, _, _ = _import_noise()
    det = NoiseDetector()
    # "widget" in "my-widgets" (Plural, kein exaktes Komponenten-Match)
    html = _html('<div class="my-widgets"><p>Widgets plural</p></div>')
    result = det.clean(html)
    assert "Widgets plural" in result


def test_class_keyword_in_attribute_value() -> None:
    """Keyword in data-* Attribut (Attribut-NAME) darf NICHT zum Strippen führen.

    Nur class=/id= Werte lösen ein Stripping aus. data-cookie, data-gdpr
    etc. sind häufige Attribute auf legitimen Seiten — ein Over-match
    würde echten Content löschen (Review-Bug #1).
    """
    NoiseDetector, _, _, _, _, _, _ = _import_noise()
    det = NoiseDetector()
    html = _html('<article data-cookie="true" data-gdpr="compliant"><p>Real content</p></article>')
    result = det.strip_by_class(html)
    # Content bleibt erhalten (data-* Attribute lösen KEIN Stripping aus)
    assert "Real content" in result

    # Gegenprobe: class= mit Keyword wird weiterhin gestrippt
    html2 = _html('<div class="cookie-banner">Cookie consent</div>')
    result2 = det.strip_by_class(html2)
    assert "Cookie consent" not in result2


def test_empty_html() -> None:
    """Leeres HTML wird korrekt behandelt."""
    NoiseDetector, _, _, _, _, _, _ = _import_noise()
    det = NoiseDetector()
    # Leeres HTML bleibt leer
    assert det.clean("") == ""
    # Whitespace-only bleibt whitespace-only (clean() entfernt nur HTML-Noise, nicht Whitespace)
    # Das ist korrekt — die eigentliche Text-Cleanup-Funktion (_html_to_text) behandelt das
    assert det.clean("   ") == "   "


def test_noise_tags_dont_affect_article_content() -> None:
    """Noise-Strip darf keinen Content-Text zerstören."""
    NoiseDetector, _, _, _, _, _, _ = _import_noise()
    det = NoiseDetector()
    html = _html(
        '<p>The cookie recipe includes a variety of ingredients.</p>'
        '<div class="ad-container">Advertisement for a recipe book.</div>'
    )
    result = det.clean(html)
    # "cookie" im Text sollte bleiben
    assert "cookie recipe" in result
    # "Advertisement" als eigenes Element sollte entfernt werden
    assert "Advertisement" not in result


def test_multiple_noise_tags() -> None:
    """Mehrere Noise-Tags im selben HTML werden alle entfernt."""
    NoiseDetector, _, _, _, _, _, _ = _import_noise()
    det = NoiseDetector()
    html = _html(
        '<script>js1</script>'
        '<script>js2</script>'
        '<style>css1</style>'
        '<style>css2</style>'
        '<p>Content</p>'
    )
    result = det.clean(html)
    assert "js1" not in result
    assert "js2" not in result
    assert "css1" not in result
    assert "css2" not in result
    assert "Content" in result


def test_noise_preserves_article_structure() -> None:
    """Article-Content bleibt strukturell erhalten."""
    NoiseDetector, _, _, _, _, _, _ = _import_noise()
    det = NoiseDetector()
    html = _html(
        '<article>'
        '<h1>Title</h1>'
        '<p>Paragraph 1</p>'
        '<h2>Subtitle</h2>'
        '<p>Paragraph 2</p>'
        '</article>'
    )
    result = det.clean(html)
    assert "Title" in result
    assert "Subtitle" in result
    assert "Paragraph 1" in result
    assert "Paragraph 2" in result


def run_all_tests() -> int:
    """Alle Tests ausführen und Ergebnisse printen."""
    tests = [
        test_semaphores_are_frozenset,
        test_no_duplicate_keywords,
        test_all_class_keywords_union,
        test_semaphores_strip_script,
        test_semaphores_strip_nav,
        test_semaphores_strip_header,
        test_semaphores_strip_footer,
        test_semaphores_strip_aside,
        test_semaphores_strip_style,
        test_semaphores_strip_meta,
        test_class_strip_cookie_banner,
        test_class_strip_cookiebot,
        test_class_strip_ad_container,
        test_class_strip_sidebar,
        test_class_strip_in_article_ad,
        test_class_strip_sponsored,
        test_class_strip_widget,
        test_class_strip_toc,
        test_class_strip_breadcrumbs,
        test_class_strip_pagination,
        test_class_strip_onetrust,
        test_class_strip_gdpr,
        test_content_kept_when_keyword_in_text,
        test_content_kept_when_keyword_in_text_2,
        test_clean_method_combined,
        test_performance,
        test_complex_html,
        test_nested_divs,
        test_nested_noise_removes_trailing_siblings,
        test_nested_noise_two_levels_deep,
        test_nested_noise_keeps_following_content,
        test_nested_noise_no_balanced_end_keeps_rest,
        test_no_partial_word_match,
        test_no_partial_word_match_hyphen,
        test_class_keyword_in_attribute_value,
        test_empty_html,
        test_noise_tags_dont_affect_article_content,
        test_multiple_noise_tags,
        test_noise_preserves_article_structure,
    ]

    passed = 0
    failed = 0
    warnings = []

    for test_fn in tests:
        try:
            test_fn()
            print(f"  ✓ {test_fn.__name__}")
            passed += 1
        except AssertionError as e:
            print(f"  ❌ {test_fn.__name__}: {e}")
            failed += 1
        except Exception as e:
            print(f"  ❌ {test_fn.__name__}: {type(e).__name__}: {e}")
            failed += 1

    return passed, failed, warnings


if __name__ == "__main__":
    print("=== Noise Module Tests ===\n")
    passed, failed, warnings = run_all_tests()

    print(f"\n=== Results ===")
    print(f"  Passed: {passed}")
    print(f"  Failed: {failed}")
    print(f"  Warned: {len(warnings)}")

    if failed > 0:
        print(f"\n❌ {failed} tests failed!")
        sys.exit(1)
    else:
        print(f"\n✅ All {passed} tests passed!")
        sys.exit(0)
