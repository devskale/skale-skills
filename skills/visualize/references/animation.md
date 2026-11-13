# Animation — Schritt-Wellen für Workflow-Diagramme

> **Opt-in, nie Default.** Die Haus-Regel „Static is the contract" gilt weiter: jede Seite
> muss ihre ganze Geschichte in einem Standbild erzählen. Animation ist ein *staged reveal*
> auf Bestellung — der Endzustand ist immer das vollständige Diagramm (`forwards`-Fill,
> Print und `prefers-reduced-motion` zeigen das Standbild, ohne JS bleibt alles sichtbar).

## Wann animieren

| Anlass | Animieren? |
|---|---|
| Workflow/Pipeline erklären, Präsentations-Charakter | **ja** — die Welle *ist* die Erklärung (Reihenfolge, Parallelität, Loops) |
| Report, Stats, Vergleich, Cheatsheet | nein — Statik ist der Vertrag |
| Diagramm mit >2 Verzweigungsebenen oder Cross-Lane-Kanten | erst vereinfachen, dann animieren (Nutzer-Regel 2026-11-12: „vereinfachen dass es gut passt") |

**Pfade trennen statt quetschen:** zwei unabhängige Pfade (z.B. Default + Spezial) werden
zwei eigene Figuren mit je eigener Welle — keine gemeinsame Doppelspur-Lane
(auditflow-Session 2026-11-12: gemeinsame Lane war unlesbar, getrennte Figuren sauber).

## Das Schritt-Wellen-Modell (step-wave)

Elemente gehören **Wellen** (`data-step="N"`, 1-basiert, docs-order = Stagger-Reihenfolge):

- **Knoten**: `<g class="n" data-step="N">` — eine Box samt Text/Punkten.
- **Logisch gruppieren, nicht flachklopfen** (Nutzer-Regel 2026-11-12): MinTasks (CLI-Aufruf,
  Routing-Check) gehören in EINE gestrichelte Container-Gruppe mit Mini-Boxen
  (`g.grp` + `g.mini`), Megaprozesse (die Phasen) bekommen volle Boxen — gleiche
  visuelle Ebene = gleiche logische Ebene. boxcheck kennt die Schachtelung: der
  Rahmen eines Ancestor-Containers ist nie „fremd".
- **Lieber 2 kurze Zeilen als 1 abgeschnittene** (Nutzer-Regel 2026-11-12): wenn ein Label
  die Box sprengt, zuerst splitten (Box ggf. höher ziehen), dann erst kürzen — boxcheck
  rechnet den Split vor („split into 2 lines (~Npx/line fits Mpx)"). Pipe `|` und `·`
  sind natürliche Bruchstellen.
- **Kante**: `<path class="edge" data-step="N" pathLength="1" d="…">` — **N = Welle des
  ZIELS** (die Kante zieht an, während ihr Ziel erscheint).
- **Loop/Feedback**: `class="edge loop"` + `data-step="end"` — gestrichelt, warn-Farbe,
  wipe-von-links, spielt nach der letzten Welle.
- **Freie Labels**: `<text class="sm n" data-step="N">` — Wellen-Text ohne Box
  (Kanten-Labels, Loop-Beschriftung). Niemals nacktes `<text>` ohne data-step lassen —
  es schwebt sonst ab t=0 im leeren Diagramm (echter Bug, 2026-11-12).

Timeline pro Welle `N` (Tokens, überschreibbar pro Seite):

```css
--ease-out: cubic-bezier(0.23, 1, 0.32, 1);   /* Entrances — Emil-Kowalski-Standard */
--ease-flow: cubic-bezier(0.65, 0, 0.35, 1);  /* Linienzug */
--t-node: 420ms;  --t-edge: 550ms;  --wave: 460ms;  --stag: 70ms;
```

- Kanten der Welle N starten bei `(N−1)·wave`, Knoten bei `+300ms` (LEAD — poppt, während
  die Kante ankommt), Parallel-Elemente staffeln um `--stag`.
- Fan-outs (1→n) sind einfach n Kanten/Knoten in derselben Welle — der Stagger macht die Fächerung.
- Gesamtlauf ≈ `(maxN−1)·wave + lead + node + tail`; Loops (`end`) nach `tail=260ms`.

### Auto-Distribute (`data-distribute`, opt-in)

Hand-authored x-Koordinaten klaffen ungleich (auditflow: 214px neben 10px Gaps).
`data-distribute` auf dem `<svg>` verteilt zur Laufzeit:

- **Lane-Clustering**: Knoten (g mit Shapes) werden nach vertikaler Überlappung zu
  Lanes gruppiert — mehrreihige Layouts (Fan-outs) bleiben unverändert.
- **Gleiche Gaps**: `(viewBox − 2·16 − Σbreiten) / (n−1)`, Minimum 24px — unterschritten
  wird LAUT geskippt (`console.warn`, authorierte Position bleibt).
- **Verdrahtung**: Knoten wandern in ein Wrapper-`<g transform="translate(dx 0)">`
  (die Pop-Animation sitzt im inneren Knoten — keine transform-Kollision). Kanten:
  Endpunkte an ihren Anker-Knoten, Kontrollpunkte an die Mitte der End-dx; freie
  Labels wandern mit ihrem nächsten Knoten.
- **SVG-Fallstrick**: `tagName` ist case-sensitiv — `'g'`, nie `'G'` (Realer Bug 2026-11-12:
  distribute filterte ins Leere und lief still vorbei).
- Der statische Markup bleibt gültig für boxcheck/print/no-JS — Distribution fügt
  nur Luft hinzu, nie Überlappungen (min-Gap-Guard).

## Technik (warum genau so)

| Mechanik | Grund |
|---|---|
| `pathLength="1"` + `stroke-dasharray:1; dashoffset:1→0` | Linie zeichnet sich in Pfadrichtung (links→right authoring) — keine Längenmessung nötig, reines CSS |
| Loops: `clip-path: inset(-12px 100% … )` → wipe | dashoffset-Kollidiert mit dem Dash-Muster; clip-path zeigt beliebige Formen richtungsgerecht |
| Pfeilspitzen **injiziert** (JS: Endpunkt + Tangente) | SVG-`marker-end` erscheint sofort — Pfeil ohne Linie. Die Engine setzt ein `<g class="ahg">` (Positionierung) + `path.ah` (Pop ums eigene Zentrum, `--d` vererbt) |
| Knoten: `opacity + translateY(8px) + scale(.97)` | GPU-only, nie `scale(0)` (Emil: „aus dem Nichts" wirkt falsch), `transform-box: fill-box` |
| `.pre`-Klasse synchron vor erstem Paint | No-JS/no-script-Fehler = vollständiges Standbild statt leerer Seite |
| Replay-Button je Figur (`data-replay`, `.flowblock`-scoped) | remove class → reflow → re-add startet CSS-Animationen neu |

## Verträge (alle gelten, alle getestet)

1. **Standbild-Vertrag**: letzter Frame = komplettes Diagramm. Print-CSS erzwingt ihn,
   `prefers-reduced-motion` ebenfalls (CSS `!important`-Overrides + JS nimmt `.pre` nie auf).
2. **Reihenfolge ist Bedeutung**: Die Welle zeigt Ausführungsreihenfolge/Parallelität —
   nie „nach Augenlust" wellen, sonst lügt die Animation.
3. **Boxcheck**: `visualize gate` läuft `boxcheck` mit — SVG-Text, der seine Box oder den
   viewBox verlässt, failt das Gate (Anlass: 5px-Überstand, von Hand gefunden, jetzt
   mechanisch). Passende Boxgröße gehört ins Authoring, nicht in die Nachsorge.
4. **Keine neuen Slop-Vektoren**: Animation ändert nichts an den Hard-Bans — Farbe bleibt
   Struktur (dot + Wert-Hue), Loops sind `--warn`, Terminal `--ok`.

## Quellen (SOTA, 2026-11)

- Emil Kowalski Skills (`emil-design-eng`, `review-animations`): Easing-/Dauer-Budgets,
  GPU-only, Stagger 30–80ms, reduced-motion-Gate — die Taste-Referenz.
- SVG-Draw via `pathLength`-Normalisierung: Standard-Technik der SVG-Path-Animation-Guides
  (svgai, iconstash, cssvg — 2026-Status).
- Motion.dev Stagger/Wave-Modelle: überlappende Wellen statt harter Sequenzen.
- CSS scroll-driven animations (90%+ Support) bewusst **nicht** genutzt: Workflow-Figuren
  sind ein Viewport groß — autoplay + replay ist der richtige Vertrag (Scroll-Timelines
  für lange Report-Seiten bleiben eine Option, wenn je gebraucht).

Beispiele: [../examples/workflow-animated.html](../examples/workflow-animated.html) (Mock,
Fan-out + Loop) · [../examples/auditflow-animated.html](../examples/auditflow-animated.html)
(zwei getrennte Figuren, Zylinder-Terminal, Replay-Loop). Template-Start:
[../templates/workflow-animated.html](../templates/workflow-animated.html).
