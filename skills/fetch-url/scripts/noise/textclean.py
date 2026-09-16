"""TextNoiseCleaner — Post-Extraktions-Noise-Stripper für gerenderten Text.

Der NoiseDetector (detector.py) wirkt auf HTML VOR dem Rendering und wird
nur im Chrome-Pfad genutzt. w3m/lynx/jina/markdown liefern aber bereits
gerenderten TEXT, in dem zwei Rauschklassen durchlaufen (Issue
fetch-url-nav-cookie-noise):

  1. NAV-WIEDERHOLUNG — komplette Seitenmenüs als (nummerierte) Linklisten
     am Anfang oder Ende der Extraktion: ``[N]``-Marker, viele kurze
     Labels, Bullets, ``(BUTTON)``-Zeilen, kaum Fließtext.
  2. COOKIE/CONSENT-PRÄAMBEL — Cookie-Wall- und Consent-Bannertexte vor
     dem eigentlichen Content (Block mit mehreren Consent-Phrasen).

Zusätzlich wird die von w3m/lynx angehängte References-URL-Liste am Ende
entfernt (``References / Visible links: / Hidden links:``).

Alle Pattern und Schwellenwerte liegen in config.py. Die Detektion ist
konservativ: Jedes Gate (Mindestanzahl Nav-Zeilen, [N]-Marker-Dichte,
Maximalanteil des Cuts) muss erfüllt sein, sonst bleibt der Text
unangetastet — Seiten, deren Content legitim aus Listen besteht
(Changelogs, Verzeichnisse), werden so nicht angetastet.
"""

from __future__ import annotations

import re

from .config import (
    CONSENT_HEADING_MAX_CHARS,
    CONSENT_MAX_BLOCK_CHARS,
    CONSENT_MIN_HITS,
    CONSENT_PATTERNS,
    CONSENT_SCAN_BLOCKS,
    NAV_HEAD_MAX_FRACTION,
    NAV_MIN_DENSITY,
    NAV_MIN_LINES,
    NAV_MIN_MARKERS,
    NAV_MIN_REMAINING_PROSE,
    NAV_TAIL_MAX_FRACTION,
    NAV_TAIL_NEUTRAL_GAP,
    REF_MAX_FRACTION,
    REF_MIN_URL_LINES,
)

# Nummerierter Link-Marker wie [14] (w3m/lynx dump mit display_link_number).
_LINK_NUM_RE = re.compile(r"\[\d+\]")

# Nummerierte URL-Referenzzeile am Textende (w3m/lynx dump):
# "  200. https://example.com/" — auch mailto:/ftp://-Refs
_URL_REF_RE = re.compile(
    r"^\s*\d+[.)]\s+(?:(?:https?|ftp)://|mailto:)\S.*$"
)

# References-Block-Header (w3m/lynx hängen die Linkliste ans Ende).
_REF_HEADER_RE = re.compile(
    r"^\s*(references|visible links|hidden links)\s*:?\s*$", re.IGNORECASE
)

# Reine Markdown-Link-Bullets: "- [Label](url)" ohne weiteren Text.
_MD_BULLET_LINK_RE = re.compile(r"^\s*[*+\-]\s*\[[^\]]+\]\([^)]+\)\s*$")

# Markdown-Link inline: "[Label](url)" (für Link-Dichte in kurzen Zeilen).
_MD_LINK_RE = re.compile(r"\[[^\]]+\]\([^)]+\)")

# Blocktrenner: eine oder mehrere Leerzeilen.
_BLOCK_SPLIT_RE = re.compile(r"\n\s*\n")


class TextNoiseCleaner:
    """Strippt Nav-Wiederholung, Consent-Präambeln und References-Listen
    aus bereits extrahiertem Text (w3m/lynx/jina/markdown Output)."""

    def __init__(self) -> None:
        self._consent_res = [
            (pattern, re.compile(pattern, re.IGNORECASE))
            for pattern in sorted(CONSENT_PATTERNS)
        ]

    # ── Zeilen-Klassifikation ─────────────────────────────────────────

    def _is_nav_line(self, line: str) -> bool:
        """Nav-artige Zeile: Link-Marker-Dichte oder kurze Link-Labels."""
        s = line.strip()
        if not s:
            return False
        n_links = len(_LINK_NUM_RE.findall(s))
        length = len(s)
        if n_links >= 2:
            return True
        if _URL_REF_RE.match(s):
            return True
        if "(BUTTON)" in s and length <= 45:
            return True
        if _MD_BULLET_LINK_RE.match(s):
            return True
        if len(_MD_LINK_RE.findall(s)) >= 2 and length <= 60:
            return True
        if n_links == 1 and length <= 50:
            return True
        return False

    def _is_soup_line(self, line: str) -> bool:
        """Echte Nav-Suppe: Bullets, Buttons, Mehrfach-Marker, URL-Refs.

        Eine nav-artige Zeile OHNE diese Merkmale (genau ein [N]-Marker,
        kein Bullet, kein Button) ist ein Heading-Kandidat — z.B.
        "Understanding [14]SC 1.4.1 Use of Color (Level A)" — und gehört
        zum Content.
        """
        s = line.strip()
        if not s:
            return False
        if "(BUTTON)" in s:
            return True
        if len(_LINK_NUM_RE.findall(s)) >= 2:
            return True
        if _URL_REF_RE.match(s):
            return True
        if _MD_BULLET_LINK_RE.match(s):
            return True
        if s.lstrip().startswith(("*", "+", "-")):
            return True
        return False

    def _is_prose_line(self, line: str) -> bool:
        """Fließtext-Zeile: lang und (fast) ohne Link-Marker."""
        s = line.strip()
        length = len(s)
        n_links = len(_LINK_NUM_RE.findall(s))
        if length >= 100:
            return True
        return length >= 60 and n_links <= 1

    def _nav_stats(self, lines: list[str]) -> tuple[int, int, int]:
        """(nav-artige Zeilen, Link-Marker gesamt, nicht-leere Zeilen).

        Marker = [N]-Nummern (w3m/lynx) ODER Markdown-Links (jina/md) —
        beide sind die Signatur einer Nav-Zeile.
        """
        non_empty = [l for l in lines if l.strip()]
        nav_count = sum(1 for l in non_empty if self._is_nav_line(l))
        markers = sum(
            len(_LINK_NUM_RE.findall(l)) + len(_MD_LINK_RE.findall(l))
            for l in lines
        )
        return nav_count, markers, len(non_empty)

    # ── 1. Cookie/Consent-Präambel ────────────────────────────────────

    def strip_consent(self, text: str) -> str:
        """Entfernt Consent-Banner-Blöcke aus der Head-Region.

        Ein Block gilt als Consent-Block wenn er
          - mindestens CONSENT_MIN_HITS VERSCHIEDENE Consent-Phrasen
            enthält (Banner-Texte kombinieren immer mehrere), oder
          - eine einzeilige kurze Consent-Überschrift ist
            ("Cookie settings").
        Langer Fließtext (> CONSENT_MAX_BLOCK_CHARS) bleibt immer stehen —
        ein Artikel ÜBER Cookies soll nicht gelöscht werden.
        """
        if not text.strip():
            return text
        blocks = _BLOCK_SPLIT_RE.split(text)
        scan_end = min(len(blocks), CONSENT_SCAN_BLOCKS)
        drop: set[int] = set()
        for idx in range(scan_end):
            block = blocks[idx]
            stripped = block.strip()
            if not stripped or len(stripped) > CONSENT_MAX_BLOCK_CHARS:
                continue
            hits = {
                pattern
                for pattern, rx in self._consent_res
                if rx.search(block)
            }
            single_line = len([l for l in block.split("\n") if l.strip()]) == 1
            if len(hits) >= CONSENT_MIN_HITS or (
                single_line
                and len(stripped) <= CONSENT_HEADING_MAX_CHARS
                and hits
            ):
                drop.add(idx)
        if not drop or len(drop) >= len(blocks):
            return text
        kept = [b for i, b in enumerate(blocks) if i not in drop]
        result = "\n\n".join(kept)
        return result if result.strip() else text

    # ── 2. Nav-Wiederholung am Anfang ─────────────────────────────────

    def strip_nav_head(self, text: str) -> str:
        """Schneidet einen nav-dominierten Block am Textanfang ab.

        Cut-Punkt = erste Fließtext-Zeile; darüber werden kurze neutrale
        Labels (Definitionslisten wie "Goal", Abschnitts-Labels)
        zurückrollend mitgenommen. Der Cut wird
        nur ausgeführt, wenn der Head nav-dominiert ist (Gates aus
        config.py) — Changelogs & Co. bleiben unberührt.
        """
        lines = text.split("\n")
        total = len(lines)
        prose_idx = next(
            (i for i, l in enumerate(lines) if self._is_prose_line(l)), None
        )
        if prose_idx is None:
            return text

        cut = prose_idx
        # Backup über den Cut: kurze neutrale Labels und Heading-Kandidaten
        # gehören zum Content und bleiben erhalten. Einzige Ausnahme:
        # echte Nav-Suppe (Bullets/Buttons/Mehrfach-Marker) beendet das
        # Backup — darüber beginnt der Head. Kein Cap: mehr behalten ist
        # die sichere Richtung, der Gate-Check unten schützt weiterhin.
        j = cut - 1
        while j >= 0:
            line = lines[j]
            if not line.strip():  # Leerzeilen überspringen
                j -= 1
                continue
            if self._is_prose_line(line):
                cut = j  # Fließtext bleibt bestehen
                break
            if self._is_nav_line(line):
                if self._is_soup_line(line):
                    cut = j + 1  # Ende der Nav-Suppe
                    break
                cut = j  # Heading-Kandidat (1 Marker, kein Bullet) bleibt
                j -= 1
                continue
            if len(line.strip()) <= 60:
                cut = j  # kurzes neutrales Label ("Goal", "In Brief") bleibt
                j -= 1
                continue
            cut = j  # langes neutrales = Content-Anfang, bleibt
            break
        if cut <= 0:
            return text

        nav_count, markers, non_empty = self._nav_stats(lines[:cut])
        if non_empty == 0:
            return text
        remaining_prose = sum(
            1 for l in lines[cut:] if self._is_prose_line(l)
        )
        if (
            nav_count < NAV_MIN_LINES
            or markers < NAV_MIN_MARKERS
            or nav_count / non_empty < NAV_MIN_DENSITY
            or cut > NAV_HEAD_MAX_FRACTION * total
            or remaining_prose < NAV_MIN_REMAINING_PROSE
        ):
            return text

        result = "\n".join(lines[cut:]).lstrip("\n")
        return result if result.strip() else text

    # ── 3. Nav-Wiederholung am Ende (Footer-Menüs) ────────────────────

    def strip_nav_tail(self, text: str) -> str:
        """Schneidet einen nav-dominierten Block am Textende ab.

        Läuft von unten, toleriert Leerzeilen und bis NAV_TAIL_NEUTRAL_GAP
        neutrale Zeilen (Footer-Kategorie-Überschriften wie "Learn"),
        stoppt an der ersten Fließtext-Zeile. Gleiche Gates wie beim Head.
        """
        lines = text.split("\n")
        total = len(lines)
        start = len(lines)
        nav_count = 0
        markers = 0
        gap = 0
        j = total - 1
        while j >= 0:
            if not lines[j].strip():
                j -= 1
                continue
            if self._is_prose_line(lines[j]):
                break
            if self._is_nav_line(lines[j]):
                start = j
                nav_count += 1
                markers += len(_LINK_NUM_RE.findall(lines[j]))
                gap = 0
                j -= 1
                continue
            gap += 1
            if gap > NAV_TAIL_NEUTRAL_GAP:
                break
            start = j  # neutrale Kategorie-Überschrift mitnehmen
            j -= 1

        if start >= total:
            return text
        tail_lines = total - start
        if (
            nav_count < NAV_MIN_LINES
            or markers < NAV_MIN_MARKERS
            or tail_lines > NAV_TAIL_MAX_FRACTION * total
        ):
            return text

        result = "\n".join(lines[:start]).rstrip()
        return result if result.strip() else text

    # ── 4. References-URL-Liste am Ende ───────────────────────────────

    def strip_references_tail(self, text: str) -> str:
        """Entfernt die angehängte Linkliste (w3m/lynx dump).

        Erkennt einen abschließenden Block aus nummerierten URL-Zeilen
        plus "References"/"Visible links:"/"Hidden links:"-Headern. Nur
        am Textende, nur ab REF_MIN_URL_LINES URL-Zeilen, und nur wenn
        höchstens REF_MAX_FRACTION des Textes entfernt würde.
        """
        lines = text.split("\n")
        total = len(lines)
        start = total
        url_count = 0
        saw_url = False
        j = total - 1
        while j >= 0:
            s = lines[j].strip()
            if not s:
                j -= 1
                continue
            if _URL_REF_RE.match(s):
                url_count += 1
                saw_url = True
                start = j
                j -= 1
                continue
            if saw_url and _REF_HEADER_RE.match(s):
                start = j
                j -= 1
                continue
            break

        if url_count < REF_MIN_URL_LINES:
            return text
        if total - start > REF_MAX_FRACTION * total:
            return text

        result = "\n".join(lines[:start]).rstrip()
        return result if result.strip() else text

    # ── Pipeline ──────────────────────────────────────────────────────

    def clean(self, text: str) -> str:
        """Vollständiger Text-Noise-Strip.

        Reihenfolge ist wichtig: Consent zuerst (sein Fließtext wäre
        sonst die "erste Prosa-Zeile" und würde den Nav-Cut stoppen),
        dann Head-Nav, dann References-Tail, dann Footer-Nav.
        """
        if not text or not text.strip():
            return text
        result = self.strip_consent(text)
        result = self.strip_nav_head(result)
        result = self.strip_references_tail(result)
        result = self.strip_nav_tail(result)
        return result
