"""NoiseDetector — HTML-Noise-Stripper.

Entfernt Noise-Elemente aus HTML:
  - SEMAPHORE-Tags (script, nav, header, ...): komplette Tags, immer löschen
  - Klassen-/ID-Keywords (cookie, ad, sidebar, ...): Elemente mit
    passendem class=/id= Wert

Verschachtelte Noise-Regionen (div in div) werden korrekt bis zum
balancierten Ende entfernt: Der Start wird per Regex erkannt, das Ende
per Tag-Zählung gefunden (Python `re` kann kein rekursives Matching).

Die Regex-Patterns und Tag-Listen liegen in config.py (nicht im Code).
"""

from __future__ import annotations

import re

from .config import (
    SEMAPHORE_PATTERN,
    CLASS_START_PATTERN,
    BALANCE_TAGS,
)


class NoiseDetector:
    """Strippt Noise-Tags und Noise-Klassen aus HTML."""

    def __init__(self) -> None:
        self._semaphore_re = re.compile(
            SEMAPHORE_PATTERN, re.DOTALL | re.IGNORECASE
        )
        self._class_start_re = re.compile(
            CLASS_START_PATTERN, re.DOTALL | re.IGNORECASE
        )
        # Für die balancierte End-Findung: zählt öffnende/schließende
        # Container-Tags innerhalb einer Noise-Region.
        self._balance_tag_re = re.compile(
            r"<(/?)(" + "|".join(BALANCE_TAGS) + r")\b[^>]*>",
            re.DOTALL | re.IGNORECASE,
        )

    def strip_semaphores(self, html: str) -> str:
        """Löscht komplette Tags die immer rausgehören (script, nav, ...)."""
        return self._semaphore_re.sub("", html)

    def strip_by_class(self, html: str) -> str:
        """Löscht Elemente mit Noise-Kennzeichen (Cookie, Ad, Sidebar).

        Erkennt den Start einer Noise-Region per Regex, findet dann das
        balancierte Ende durch Zählung der Container-Tags. So werden auch
        verschachtelte Noise-Blöcke (div in div) vollständig entfernt.
        """
        out: list[str] = []
        i = 0
        n = len(html)
        while i < n:
            m = self._class_start_re.search(html, i)
            if not m:
                out.append(html[i:])
                break
            out.append(html[i : m.start()])
            end = self._find_balanced_end(html, m.start(), n)
            if end is None:
                # Kein balanciertes Ende gefunden — Rest konservativ behalten.
                out.append(html[m.start() :])
                i = n
                break
            i = end

        return "".join(out)

    def _find_balanced_end(self, html: str, start: int, n: int) -> int | None:
        """Findet das balancierte Ende einer Noise-Region ab `start`.

        Zählt öffnende/schließende Container-Tags (div, section, ...).
        Gibt den Index direkt nach dem schließenden Tag des Start-Elements
        zurück, oder None wenn kein balanciertes Ende existiert.
        """
        depth = 0
        k = start
        while k < n:
            tm = self._balance_tag_re.search(html, k)
            if not tm:
                return None
            k = tm.end()
            if tm.group(1) == "/":  # schließendes Tag
                depth -= 1
                if depth <= 0:
                    return k
            else:  # öffnendes Tag
                depth += 1
        return None

    def clean(self, html: str) -> str:
        """Vollständiger Noise-Strip (semaphores → class)."""
        return self.strip_by_class(self.strip_semaphores(html))
