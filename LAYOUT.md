# Repo layout — the three "not shipped" states

This repo keeps three categories of material out of what users get. They are easy to
confuse and must stay distinct, because **they are excluded from the pi package in
different ways**.

| Folder | State | Shipped? | What it holds |
|--------|-------|----------|---------------|
| [`docs/ideas.md`](docs/ideas.md) → `docs/*.md` | **Idea** — a well-developed issue | No | Rationale, alternatives, decision already made |
| [`under-review/`](under-review/) | **Under review** — built, decision open | No | Implemented but unshipped skills/extensions |
| [`skills/deprecated/`](skills/deprecated/), [`deprecated/`](deprecated/) | **Deprecated** — finished, retired | No | Retired code kept for archaeology |

The difference that matters:

- An **idea** is an issue that has been *reasoned through*: the decision is written down and
  nobody is waiting on it. It was never code. This is the slow lane of the issue board —
  if a doc here still needs a decision, it is an issue and belongs on the board.
- **Under review** is real code with tests, awaiting a shipping decision.
- **Deprecated** is shipped-then-retired code, kept so the reasoning survives.

## Why there are TWO deprecated folders

They look like a duplication and are not. The exclusion mechanics force the split:

- **`skills/deprecated/`** sits *inside* the `"./skills"` discovery glob, so pi would find
  those `SKILL.md` files if it were not for the explicit `!skills/deprecated/**` exclude in
  `package.json` → `pi.skills`. Everything here **is a skill** and must stay excluded by
  manifest (plus the redundant `!skills/deprecated/**` entry in the user's `settings.json`).
  pi discovers `SKILL.md` **recursively**, so the extra directory depth alone does *not*
  hide them — the glob exclude is what actually does it. Use `!` (minimatch glob), never
  `-` (exact match, silently ignores `**`).

- **`deprecated/`** sits at the repo top level, **outside** `pi.skills` (`["./skills",
  "./extensions/*.ts", "./prompts"]`), so it needs no exclusion at all. This is where
  non-skill retirements live — e.g. `skiller/`, a Python CLI with no `SKILL.md`, which
  could never live under `skills/` without being mistaken for (or promoted into) a skill.

Moving `skiller/` into `skills/deprecated/` would put a `SKILL.md`-less directory inside a
discovery root. Keep the split.

## Invariants to preserve when adding or moving anything

1. A new skill under `skills/deprecated/` **must** still be covered by
   `!skills/deprecated/**` in `package.json` and by the settings filter — check
   `scripts/skill-filter.sh list`.
2. `tests/docs/test.sh` fails on `docs/` files no hub references. Sketches therefore need a
   row in `docs/ideas.md`; that page is the single hub for that folder (AGENTS.md links to
   the page, not to individual sketches, so the table does not grow there).
3. `under-review/` content must never gain a manifest, installer, or `link-agents.sh`
   entry — that is what makes it "not shipped".
