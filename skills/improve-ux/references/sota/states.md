# States SOTA — empty & loading

> Load when designing empty, loading, or error states.

## Empty states

Empty states are design opportunities, not afterthoughts. Good empty states:
explain what belongs here, give a **single clear next action**, avoid dead-end
"nothing here" messages.

- <https://uxplanet.org/empty-state-design-a-practical-guide-94ad0adbda45>
- <https://www.northbase.design/patterns/empty-states>
- Real-world examples: <https://mobbin.com> (filter by empty states).

## Loading states

Prefer skeletons that match the final layout over spinners for content areas
(layout doesn't jump); spinners are fine for short, bounded waits (<300ms
needs no indicator at all). Never block interaction without feedback.
