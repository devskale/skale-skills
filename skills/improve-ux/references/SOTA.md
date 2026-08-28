# UI/UX SOTA baseline (research notes)

> Ground truth for "what good looks like" — concrete, citable standards and
> numbers to back every improvement. Fetched from primary sources (W3C,
> Material, DTCG) — not vibes. Cite these in change comments.

## Accessibility — WCAG 2.2 (W3C, Oct 2023)

The skill's a11y rules should be **numeric and testable**, not vague. Primary
source: <https://www.w3.org/TR/WCAG22/> and the "Understanding" docs.

| Criterion | Number | Source |
|-----------|--------|--------|
| **Target size (minimum)** 2.5.8 | ≥ 24×24 CSS px, OR 24px circle around each undersized target doesn't intersect another | <https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html> |
| **Target size (enhanced)** 2.5.5 | ≥ 44×44 CSS px (best practice for important controls) | <https://www.w3.org/WAI/WCAG22/Understanding/target-size-enhanced.html> |
| **Focus appearance** 2.4.13 | indicator ≥ area of a 2px-thick perimeter of the component, AND ≥ 3:1 contrast vs unfocused | <https://www.w3.org/WAI/WCAG22/Understanding/focus-appearance.html> |
| **Contrast (text)** 1.4.3 | 4.5:1 normal, 3:1 large text (≥18pt / 14pt bold) | <https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html> |
| **Non-text contrast** 1.4.11 | 3:1 for UI components / graphical objects | <https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html> |

Key implementation notes:
- Use `:focus-visible` (not `:focus`) so focus rings show for keyboard users but
  stay clean on mouse click. Never `outline: none` without a replacement.
  <https://inclaria.com/en/blog/focus-visible-outline-none>
- Honor `prefers-reduced-motion`; scale durations to 0 or minimal.

## Design tokens — DTCG (W3C Design Tokens Community Group)

The DTCG Format Module hit its **first stable spec `2025.10`** (Oct 28, 2025).
This is the SOTA way to express tokens: JSON with `$type`/`$value` metadata.
<https://www.w3.org/community/design-tokens/>

- Token adoption is ~84% across design systems (2025/26 surveys).
- Tokens are the **"AI prompt contract"** for a design system — the AI operates
  within defined component/token/interaction boundaries.
  <https://brenthaskins.com/blog/design-system-ai-prompt-contract>
- **Color spaces:** prefer **OKLCH** — perceptually uniform, so lightness and
  contrast stay predictable as you build palettes. Avoid HSL/RGB for ramps.
  <https://evilmartians.com/chronicles/oklch-in-css-why-quit-rgb-hsl>
  <https://lea.verou.me/blog/2024/contrast-color/>

## Motion — durations & easing

Material Design motion (primary source <https://m1.material.io/motion/duration-easing.html>)
and community validation (<https://designmotionhq.com/patterns/animation-timing>):

- **Desktop:** 150–200ms. **Mobile:** ~300ms (large full-screen up to 390ms).
- **Entrances:** land best at 200–300ms with a cubic **ease-out**.
- **Exits:** should be **faster than entrances** (~150ms vs ~250ms) — fast out
  feels responsive, slow out feels stuck.
- Small UI feedback (button press): 50–150ms, near-instant.
- Use easing tokens (ease-out / ease-in-out / spring), never linear for motion.

### Frequency-of-use heuristic (emilkowal.ski)

Decide *whether* to animate by how often a user sees it:
- **Hundreds of times/day** (command palettes, toggles): minimal or no animation.
- **Rarely** (feedback morph, delight moments): animation is a pleasant surprise.
- Purpose first: an animation must explain, orient, or give feedback — else cut it.
  <https://emilkowal.ski/ui/you-dont-need-animations>

## Empty states

Empty states are design opportunities, not afterthoughts (2–5% of users hit them,
so they must *help* on first impression). Good empty states: explain what belongs
here, give a single clear next action, avoid dead-end "nothing here" messages.
<https://uxplanet.org/empty-state-design-a-practical-guide-94ad0adbda45>
<https://www.northbase.design/patterns/empty-states>

## Automated a11y verification

Pair manual review with automation to catch concrete failures:
- **axe-core** — precise, rule-based WCAG checks; the standard for CI gating.
  <https://github.com/dequelabs/axe-core>
- **Lighthouse** — holistic score, but a 100 a11y score does NOT prove WCAG
  conformance (it's a weighted subset of axe rules). Don't gate on it alone.
  <https://www.wcag-audit.org/automated-accessibility-dynamic-content-ingestion/scanner-tool-selection-and-benchmarking/axe-core-vs-lighthouse-for-ci-accessibility/>

## Reference sites worth adding to SITES.md

- **Material Design 3** — Google's open-source system, tokens & components.
  <https://m3.material.io/>
- **Mobbin** — real-world app/web UI patterns (1000+ apps, 200 sites).
  <https://mobbin.com/>
- **easings.net** — easing function picker for natural motion.
  <https://easings.net/>
