# Under review

Work that is **built far enough to judge, but not yet decided about**. Nothing here ships to
users — no manifest entry, no settings entry, nothing symlinked by the installer.

> This folder is currently **empty**. It exists so the state has a name: a decided direction
> goes to [`docs/ideas.md`](../docs/ideas.md), a retirement goes to
> [`skills/deprecated/`](../deprecated/), and finished work lands as a PR.
> See [LAYOUT.md](../LAYOUT.md) for how the three states differ.

## What "under review" means here

A PR is open, feedback is unresolved, or a skill/extension is implemented but the decision
to ship it is still open. The bar for *moving it in*:

- It has a `SKILL.md` (skills) or registers a tool/command (extensions).
- It has a `tests/<name>/test.sh` that passes — **an unreviewed thing with no test is just
  unreviewed code**, and belongs in a branch, not here.
- It is not referenced by `package.json`'s `pi` manifest, nor by `install.sh`, nor by
  `scripts/link-agents.sh`.

The bar for *moving it out*:

- **Shipped** → PR to `main`, then it leaves this folder for `skills/` or `extensions/`.
- **Not worth shipping** → the reasoning goes to `docs/ideas.md` (as a well-developed
  issue); the code is deleted.
- **Finished but superseded** → `skills/deprecated/` with a row saying what replaced it.

## Why a folder at all

Without a home for this state, work-in-review lives in a branch and quietly rots, or gets
committed straight into `skills/` and shipped by accident — `pi install` takes whatever the
manifest globs, and `skills/` is one of those globs. A named folder makes "not shipped yet"
visible in the tree instead of living in a checkout.

## Adding an entry

Give it its own folder with a short `README.md` stating:

1. **What it is** — one paragraph.
2. **Why it is not shipped yet** — the open question, not "needs polish".
3. **What would settle it** — the concrete decision or test that ends the review.
