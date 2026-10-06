# Ideas & Sketches

Material that is **thought through but deliberately not implemented**. Nothing here is
installed, loaded, or depended on by any skill — these are decisions and open directions,
not deliverables.

> **Status convention:** every file in this folder opens with its status, so a reader never
> mistakes a sketch for shipped behaviour:
>
> ```markdown
> Status: **idea/sketch** — not implemented. …
> ```

## What an idea is here

**An idea is a well-developed issue.** Not a vague note, not a wishlist — the same thing
you'd file as a ticket, except the decision has already been reasoned through and the
answer recorded, and nobody is waiting on it.

That makes this folder the *slow lane* of the issue tracker:

| | Issue board (`.handoff/`) | `docs/` (here) |
|---|---|---|
| State | open, being worked | settled direction, not being worked |
| Needs a decision | yes | no — the decision is written down |
| Next step | someone picks it up | it sits until someone wants it |
| Shape | acceptance criteria, repro, status | rationale, alternatives, why-now-or-why-not |

If a doc here needs a decision to proceed, it is still an issue, not an idea — move it to
the board.

## When something belongs here (and when it does not)

Put it here when the design is clear enough to be worth writing down, **but**:

- it depends on something outside this repo's install path — a third-party app, an
  upstream API, another agent's plugin model, or
- implementing it now would be premature until someone actually wants it.

Do **not** put it here if it can be shipped with a test suite in this repo. That is a PR,
not an idea — see [CODING_RULES.md](../CODING_RULES.md).

## The sketches

| Doc | Sketch |
|-----|--------|
| [zcode-plugin.md](zcode-plugin.md) | skale-skills as a first-class zcode extension (plugin) — not implemented, but test-guarded |
| [tldraw-offline.md](tldraw-offline.md) | tldraw Desktop as an agent-driven canvas — editable diagram state instead of one-shot artifacts |

## Related: deprecated, not deleted

A sketch is *not started*; a deprecated entry is *finished but retired*. Both are kept for
the same reason — the reasoning outlives the code — but they are different states:

| State | Folder | Shipped to users? |
|-------|--------|-------------------|
| Idea / sketch | [`ideas/`](.) | No |
| Deprecated (retired, kept for archaeology) | [`skills/deprecated/`](../deprecated/), [`deprecated/`](../deprecated/) | No |
| Under review | [`under-review/`](../under-review/) | No — see its README |
