#!/usr/bin/env python3
"""
Tests für noise/textclean.py — TextNoiseCleaner (Post-Extraktion)

Testet die beiden Rauschklassen aus Issue fetch-url-nav-cookie-noise:
  1. NAV-WIEDERHOLUNG — Seitenmenüs als (nummerierte) Linklisten am
     Anfang/Ende (w3m/lynx dumps)
  2. COOKIE/CONSENT-PRÄAMBEL — Banner- und Wall-Texte vor dem Content

Dazu False-Positive-Schutz (Changelogs, legitime Listen, Prosa mit Links)
und die Live-Fixtures der beiden Review-Fälle von 2026-09-14.

python3 tests/fetch-url/noise/test_textclean.py
"""

from __future__ import annotations

import sys
from pathlib import Path

SCRIPTS_DIR = Path(__file__).parent.parent.parent.parent / "skills" / "fetch-url" / "scripts"
FIXTURES_DIR = Path(__file__).parent.parent / "fixtures"

sys.path.insert(0, str(SCRIPTS_DIR))


def _cleaner():
    """Frischen TextNoiseCleaner importieren."""
    from noise import TextNoiseCleaner
    return TextNoiseCleaner()


def _fixture(name: str) -> str:
    """Fixture laden (Live-Fälle, gekürzt)."""
    return (FIXTURES_DIR / name).read_text()


# ══════════════════════════════════════════════════════════════════════════
# Fixture 1: platform.claude.com/docs via w3m (Nav + Consent + References)
# ══════════════════════════════════════════════════════════════════════════

def test_fixture_claude_nav_head_stripped() -> None:
    """Live-Fall 1: komlettes Navigationsmenü am Anfang wird entfernt."""
    out = _cleaner().clean(_fixture("claude-docs-nav.txt"))
    assert "SearchCtrlK" not in out
    assert "[16]Messages" not in out
    assert "[27]Intro to Claude" not in out
    assert "alternate" not in out  # alternate-Language-Link-Suppe


def test_fixture_claude_consent_stripped() -> None:
    """Live-Fall 1: Cookie-Consent-Präambel wird entfernt."""
    out = _cleaner().clean(_fixture("claude-docs-nav.txt"))
    assert "We use cookies" not in out
    assert "Cookie settings" not in out
    assert "AcceptAccept All Cookies" not in out


def test_fixture_claude_content_kept() -> None:
    """Live-Fall 1: Content bleibt vollständig erhalten."""
    out = _cleaner().clean(_fixture("claude-docs-nav.txt"))
    assert "Learn how to write effective Skills" in out
    assert "context window is a public good" in out
    assert "Match the level of specificity" in out


def test_fixture_claude_inline_markers_kept() -> None:
    """Inline-[N]-Marker im Content bleiben (nur Nav-Blöcke werden entfernt)."""
    out = _cleaner().clean(_fixture("claude-docs-nav.txt"))
    assert "[101]context window" in out
    assert "[100]Skills" in out


def test_fixture_claude_content_bullets_kept() -> None:
    """Legitime Content-Bullets (Use when: ...) bleiben erhalten."""
    out = _cleaner().clean(_fixture("claude-docs-nav.txt"))
    assert "Multiple approaches are valid" in out
    assert "Configuration affects the approach" in out


def test_fixture_claude_footer_nav_stripped() -> None:
    """Footer-Menü (Learn/Help/Terms) am Ende wird entfernt."""
    out = _cleaner().clean(_fixture("claude-docs-nav.txt"))
    assert "[189]Blog" not in out
    assert "[203]Privacy policy" not in out
    assert "(BUTTON) Ask Docs" not in out


def test_fixture_claude_references_stripped() -> None:
    """References-URL-Liste (Visible/Hidden links) am Ende wird entfernt."""
    out = _cleaner().clean(_fixture("claude-docs-nav.txt"))
    assert "References" not in out
    assert "Hidden links" not in out
    assert "https://status.claude.com/" not in out


# ══════════════════════════════════════════════════════════════════════════
# Fixture 2: w3.org/WAI via lynx (Nav-Head + TOC + References)
# ══════════════════════════════════════════════════════════════════════════

def test_fixture_w3c_nav_head_stripped() -> None:
    """Live-Fall 2: Nav-Kopf (Skip links, TOC) wird entfernt."""
    out = _cleaner().clean(_fixture("w3c-wcag-nav.txt"))
    assert "[1]Skip to content" not in out
    assert "Page Contents" not in out
    assert "[12]Related Resources" not in out


def test_fixture_w3c_content_heading_kept() -> None:
    """Live-Fall 2: Content-Heading mit inline [14]-Marker bleibt.

    'Understanding [14]SC 1.4.1 Use of Color (Level A)' ist nav-ÄHNLICH
    (1 Marker, kurz) aber kein Soup-Bestandteil (kein Bullet/Button) —
    es muss erhalten bleiben (Heading-Kandidat).
    """
    out = _cleaner().clean(_fixture("w3c-wcag-nav.txt"))
    assert "Understanding [14]SC 1.4.1 Use of Color (Level A)" in out


def test_fixture_w3c_deflist_labels_kept() -> None:
    """Definitionslisten-Labels (Goal/What to do) bleiben erhalten."""
    out = _cleaner().clean(_fixture("w3c-wcag-nav.txt"))
    assert "Goal" in out
    assert "What to do" in out
    assert "Color is not the only way of distinguishing information." in out


def test_fixture_w3c_references_stripped() -> None:
    """Live-Fall 2: References-Liste (inkl. mailto-Refs) wird entfernt."""
    out = _cleaner().clean(_fixture("w3c-wcag-nav.txt"))
    assert "References" not in out
    assert "Hidden links" not in out


# ══════════════════════════════════════════════════════════════════════════
# Nav-Detektion: Einheiten
# ══════════════════════════════════════════════════════════════════════════

def test_nav_line_classification() -> None:
    """Zeilen-Klassifikation: Nav vs. Prosa vs. neutral."""
    c = _cleaner()
    assert c._is_nav_line("* [16]Messages")
    assert c._is_nav_line("[27]Intro to Claude[28]Get your API key")
    assert c._is_nav_line("  200. https://status.claude.com/")
    assert c._is_nav_line("(BUTTON) Ask Docs")
    assert c._is_nav_line("- [Overview](https://example.com/docs)")
    assert c._is_nav_line("[15]")  # einzelner Marker, sehr kurz
    assert not c._is_nav_line(
        "The [101]context window is a public good. Your Skill shares the context"
    )
    assert not c._is_nav_line("")
    assert c._is_prose_line(
        "The [101]context window is a public good. Your Skill shares the context"
    )
    assert c._is_prose_line("x" * 100)  # lange Zeile = Prosa
    assert not c._is_prose_line("[15]")


def test_soup_vs_heading_candidate() -> None:
    """Soup-Zeilen (Bullets/Buttons/Mehrfach-Marker) vs. Heading-Kandidat."""
    c = _cleaner()
    assert c._is_soup_line("* [16]Messages")
    assert c._is_soup_line("[27]Intro to Claude[28]Get your API key")
    assert c._is_soup_line("(BUTTON) Ask Docs")
    assert c._is_soup_line("  200. https://status.claude.com/")
    # Heading-Kandidat: nav-artig, aber kein Soup-Bestandteil
    assert not c._is_soup_line("Understanding [14]SC 1.4.1 Use of Color (Level A)")
    assert not c._is_soup_line("")


def test_markdown_nav_list_head_stripped() -> None:
    """Markdown-Nav (reine Link-Bullets, ≥8 Einträge) am Anfang wird erkannt."""
    entries = ["Home", "Blog", "Docs", "Pricing", "About", "Contact", "Careers", "Legal"]
    prose = [
        "Welcome to our documentation portal for all things related to the",
        "product and its capabilities in depth.",
        "This section explains everything you need to know about the product",
        "and how to use it effectively in your daily work and workflows.",
        "The following chapters cover setup, configuration and advanced use.",
        "Each chapter builds on the previous one with worked examples.",
    ] * 4  # realistische Proportion: Content dominiert, Nav ist klein
    text = "\n".join(
        [f"- [{e}](https://example.com/{e.lower()})" for e in entries]
        + [""] + prose
    )
    out = _cleaner().clean(text)
    assert "[Pricing]" not in out
    assert "Welcome to our documentation portal" in out


# ══════════════════════════════════════════════════════════════════════════
# Consent-Detektion: Einheiten + False Positives
# ══════════════════════════════════════════════════════════════════════════

def test_consent_banner_stripped() -> None:
    """Typischer Consent-Banner-Block wird entfernt."""
    text = (
        "We value your privacy\n\n"
        "We use cookies to improve your experience. By continuing you agree\n"
        "to our cookie policy. Accept All Cookies\n\n"
        "This is the actual article content with a decent amount of text that\n"
        "goes on for a while and represents real prose."
    )
    out = _cleaner().clean(text)
    assert "We use cookies" not in out
    assert "actual article content" in out


def test_consent_heading_only_stripped() -> None:
    """Einzeilige Consent-Überschrift ('Cookie settings') wird entfernt."""
    text = "Cookie settings\n\nWe store minimal data.\n\n" + (
        "The real content starts here and contains actual prose sentences "
        "that are long enough to be recognized as flowing text."
    )
    out = _cleaner().clean(text)
    assert "Cookie settings" not in out
    assert "real content starts here" in out


def test_consent_false_positive_article_kept() -> None:
    """Artikel ÜBER Cookies (langer Fließtext) wird NICHT gelöscht."""
    text = (
        "We wrote a cookie policy for our GDPR compliance and documented\n"
        "every detail of it. " + "This article discusses the legal background "
        "of consent management in depth and explains all the nuances. " * 5
    )
    out = _cleaner().clean(text)
    assert "cookie policy" in out
    assert "GDPR compliance" in out


def test_consent_deep_text_ignored() -> None:
    """Consent-artiger Text tief im Dokument (Block > 30) bleibt."""
    filler = "\n\n".join(f"Section {i} with some prose content here." for i in range(35))
    text = filler + "\n\nWe use cookies and you must accept all cookies now."
    out = _cleaner().clean(text)
    assert "We use cookies" in out  # außerhalb der Head-Region


# ══════════════════════════════════════════════════════════════════════════
# False Positives: legitimer Listen-Content (Acceptance-Kriterium)
# ══════════════════════════════════════════════════════════════════════════

def test_changelog_untouched() -> None:
    """Changelog (legit aus Listen bestehend) wird NICHT angetastet."""
    text = "\n".join(
        [
            "# Changelog",
            "",
            "## 2.7.3 — 2026-09-14",
            "",
            "* Fixed w3m display on GitHub",
            "* Updated fallback order",
            "* Fixed lynx config path",
            "",
            "## 2.7.2 — 2026-09-01",
            "",
            "* Added site tool hints",
            "* Improved error page detection",
            "* Refactored noise detector",
            "",
            "See the full history on our releases page for more details about",
            "previous versions and their changes.",
        ]
    )
    out = _cleaner().clean(text)
    assert out == text  # komplett unangetastet


def test_list_heavy_directory_page_untouched() -> None:
    """Verzeichnis-Seite (viele kurze Zeilen, kein Nav-Gate erfüllt) bleibt."""
    text = "\n".join(
        ["Directory of tools:"] + [f"{name} — a tool for {purpose}"
                                   for name, purpose in [
                                       ("w3m", "browsing"), ("lynx", "browsing"),
                                       ("jina", "reading"), ("curl", "fetching"),
                                       ("wget", "fetching"), ("trafilatura", "extraction"),
                                   ]]
    )
    out = _cleaner().clean(text)
    assert "trafilatura" in out
    assert "Directory of tools" in out


def test_prose_with_links_untouched() -> None:
    """Prosa mit inline Links wird nicht als Nav abgeschnitten."""
    text = (
        "This guide provides practical authoring decisions to help you write\n"
        "Skills that Claude can discover and use effectively. See the\n"
        "[overview](https://example.com/overview) for background and the\n"
        "[checklist](https://example.com/checklist) for details."
    )
    out = _cleaner().clean(text)
    assert "practical authoring decisions" in out
    assert "[overview]" in out


def test_url_directory_tail_partially_kept() -> None:
    """Legitime URL-Liste am Ende: nur Reference-Signatur (N. url),\n    beschriebene URL-Zeilen (N. url — Beschreibung) bleiben."""
    text = "\n".join(
        [
            "Recommended reading list for this course module, curated by the",
            "teaching team and updated every semester with new material.",
            "",
            "1. https://example.com/basics — Introduction to the fundamentals",
            "2. https://example.com/advanced — Advanced topics in depth",
            "3. https://example.com/practice — Practice exercises",
            "4. https://example.com/reference — Reference documentation",
        ]
    )
    out = _cleaner().clean(text)
    # Zeilen haben Beschreibungen hinter der URL → kein bare-URL-Ref-Match
    assert "Introduction to the fundamentals" in out


# ══════════════════════════════════════════════════════════════════════════
# Gates & Robustheit
# ══════════════════════════════════════════════════════════════════════════

def test_too_few_nav_lines_untouched() -> None:
    """Wenige Nav-Zeilen (< NAV_MIN_LINES) → kein Strip (Gate)."""
    text = "\n".join(
        ["[1]Home [2]About", "[3]Contact", "", "Short page.", "That is all."]
    )
    out = _cleaner().clean(text)
    assert "[1]Home" in out


def test_empty_and_short_input() -> None:
    """Leere/kurze Eingaben bleiben unangetastet."""
    c = _cleaner()
    assert c.clean("") == ""
    assert c.clean("   ") == "   "
    assert c.clean("Just one line.") == "Just one line."


def test_never_returns_empty() -> None:
    """Der Cleaner liefert nie ein leeres Ergebnis zurück."""
    nav_only = "\n".join([f"[{i}]Link{i}" for i in range(1, 40)])
    out = _cleaner().clean(nav_only)
    assert out.strip()  # konservativ: alles Nav → unverändert zurückgeben


def test_pipeline_order_consent_before_nav() -> None:
    """Consent muss VOR Nav-Head laufen (Consent-Fließtext wäre sonst\n    'erste Prosa-Zeile' und würde den Nav-Cut blockieren)."""
    nav_lines = [
        "[1]Home [2]Docs [3]Blog",
        "[4]About [5]Contact",
        "[6]Pricing [7]Careers",
        "[8]Legal [9]Status",
        "[10]Changelog [11]Search",
        "[12]API [13]Support",
    ]
    prose = [
        "The actual article begins here with real prose content that is",
        "long enough to trigger the prose detection in the head pass.",
        "And a third prose line so the remaining-prose gate is satisfied.",
        "Plus a fourth line of genuine flowing text without any links.",
    ] * 6  # realistische Proportion: Content dominiert
    text = "\n".join(
        nav_lines
        + [
            "",
            "Cookie settings",
            "",
            "We use cookies to improve your experience. Read our cookie policy",
            "and manage cookies in the settings. Accept All Cookies",
            "",
        ] + prose
    )
    out = _cleaner().clean(text)
    assert "We use cookies" not in out
    assert "[1]Home" not in out
    assert "actual article begins here" in out


def run_all_tests() -> int:
    """Alle Tests ausführen und Ergebnisse printen."""
    tests = [
        test_fixture_claude_nav_head_stripped,
        test_fixture_claude_consent_stripped,
        test_fixture_claude_content_kept,
        test_fixture_claude_inline_markers_kept,
        test_fixture_claude_content_bullets_kept,
        test_fixture_claude_footer_nav_stripped,
        test_fixture_claude_references_stripped,
        test_fixture_w3c_nav_head_stripped,
        test_fixture_w3c_content_heading_kept,
        test_fixture_w3c_deflist_labels_kept,
        test_fixture_w3c_references_stripped,
        test_nav_line_classification,
        test_soup_vs_heading_candidate,
        test_markdown_nav_list_head_stripped,
        test_consent_banner_stripped,
        test_consent_heading_only_stripped,
        test_consent_false_positive_article_kept,
        test_consent_deep_text_ignored,
        test_changelog_untouched,
        test_list_heavy_directory_page_untouched,
        test_prose_with_links_untouched,
        test_url_directory_tail_partially_kept,
        test_too_few_nav_lines_untouched,
        test_empty_and_short_input,
        test_never_returns_empty,
        test_pipeline_order_consent_before_nav,
    ]

    passed = 0
    failed = 0

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

    return passed, failed


if __name__ == "__main__":
    print("=== Text Noise Cleaner Tests ===\n")
    passed, failed = run_all_tests()

    print(f"\n=== Results ===")
    print(f"  Passed: {passed}")
    print(f"  Failed: {failed}")

    if failed > 0:
        print(f"\n❌ {failed} tests failed!")
        sys.exit(1)
    else:
        print(f"\n✅ All {passed} tests passed!")
        sys.exit(0)
