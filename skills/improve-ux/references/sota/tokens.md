# Design tokens SOTA — DTCG & OKLCH

> Load for color/theming/token work.

## DTCG format (W3C Design Tokens Community Group)

The DTCG Format Module hit its **first stable spec `2025.10`** (Oct 28, 2025).
This is the SOTA way to express tokens: JSON with `$type`/`$value` metadata.
<https://www.w3.org/community/design-tokens/>

- Token adoption is ~84% across design systems (2025/26 surveys).
- Tokens are the **"AI prompt contract"** for a design system — the AI operates
  within defined component/token/interaction boundaries.
  <https://brenthaskins.com/blog/design-system-ai-prompt-contract>
- Re-verify the spec date when refreshing this file (community group, moves
  slowly but does move).

## Color spaces: prefer OKLCH

**OKLCH** is perceptually uniform, so lightness and contrast stay predictable
as you build palettes. Avoid HSL/RGB for ramps.

- <https://evilmartians.com/chronicles/oklch-in-css-why-quit-rgb-hsl>
- <https://lea.verou.me/blog/2024/contrast-color/>

Express system-wide values as design tokens (DTCG format), not hardcoded
literals.
