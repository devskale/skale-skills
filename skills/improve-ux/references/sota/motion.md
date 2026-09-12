# Motion SOTA — durations & easing

> Load for any animation/transition work. Numbers originate from Material's
> motion guidance (<https://m1.material.io/motion/duration-easing.html> — M1
> page, still the community baseline; current system:
> <https://m3.material.io/styles/motion>) and community validation
> (<https://designmotionhq.com/patterns/animation-timing>).

- **Desktop:** 150–200ms. **Mobile:** ~300ms (large full-screen up to 390ms).
- **Entrances:** land best at 200–300ms with a cubic **ease-out**.
- **Exits:** **faster than entrances** (~150ms vs ~250ms) — fast out feels
  responsive, slow out feels stuck.
- Small UI feedback (button press): 50–150ms, near-instant.
- Use easing tokens (ease-out / ease-in-out / spring), never linear for motion.
- Easing curves worth picking visually: <https://easings.net>.

## Frequency-of-use heuristic (emilkowal.ski)

Decide *whether* to animate by how often a user sees it:
- **Hundreds of times/day** (command palettes, toggles): minimal or no animation.
- **Rarely** (feedback morph, delight moments): animation is a pleasant surprise.
- Purpose first: an animation must explain, orient, or give feedback — else cut
  it. <https://emilkowal.ski/ui/you-dont-need-animations> — read before adding
  ANY animation.
