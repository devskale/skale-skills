# Developing skills & extensions

How to work on skills/extensions in this repo **without** leaving conflicts for the git
package to trip over at startup. Read alongside [installation.md](installation.md) for the
precedence / dedup model — this doc is the *workflow* counterpart.

## The golden rule

> Edit in the working tree. Land changes **upstream** *before* removing any dev overrides.
> Then sync pi and delete the overrides.

Dev overrides (project-path packages, skill symlinks, loose extension files) are fine **while**
you work — they're how you get live feedback. The problem is leaving them in place after the
work ships: they then collide with the git package on every startup (see
[installation.md → Loose-file conflicts](installation.md#loose-file-conflicts)).

## Dev setups

> **Identity caveat (verified from pi source).** A local-path package and a git package are
> *different identities*, so they **both load** → `[conflicts]` at startup, resolved by
> precedence (project-local wins, so your working tree is served). The warning is noise,
> not breakage — but it appears on every startup while the override is in place. For
> conflict-free iteration prefer the **session-only flags** (setup A) over a persistent
> package entry (setup B). See the skaleshare guide §19 for the full precedence/identity
> model.

### A. Session-only override (preferred — zero persistent state)

Load the working tree for **one run** via a CLI flag. Nothing is written to settings, so
there is no leftover to clean up and no conflict on any other project. The right flag
depends on what you're dev'ing — **skills and extensions collide differently**:

```bash
cd ~/code/skale-skills

# Skill dev — soft collision (first wins), package skill is skipped, warning only:
pi --skill skills/d2/SKILL.md          # load one skill for this run (repeatable, additive)

# Extension dev — HARD collision: same tool name = load error, not a warning.
# Suppress the package's extensions first, then load yours:
pi -ne -e ./extensions/statusline.ts   # -ne = no package extensions; -e = load this one
```

Why the split: skills collide on **name** (soft — loser skipped with a `[conflicts]`
diagnostic, winner serves); extensions collide on **tool/command name** (hard — pi refuses
to load the second one and errors out). So `pi -e .` on a whole package that also ships
extensions will fail against an installed copy of the same package. `-ne` makes the
extension dev path work by silencing the package's extensions for that run.

Restart and the override is gone. Use this for iterating on a change you're about to ship.

### B. Project-path package (persistent — for long dev sessions on one repo)

```jsonc
// ~/code/skale-skills/.pi/settings.json  (project-scoped, gitignored)
{ "packages": ["."] }
```

Loads the working tree live in every session inside the repo. **Will emit `[conflicts]` at
startup** (different identity from the global git package) — the project-local entry wins
(rank 0) so your edits are served and the package copy is skipped. Fine functionally; noisy.
Remove the file when dev is done.

Never put a working-tree path in **global** settings while the git package is installed —
that collides on *every* project, not just the one under dev.

### C. Symlink a single skill (legacy — prefer setup A)

```bash
ln -s ~/code/skale-skills/skills/<name> ~/.pi/agent/skills/<name>
```

`pi --skill skills/<name>/SKILL.md` (setup A) does the same thing with **zero cleanup** and
no persistent symlink to forget. This symlink form is retained only for workflows that need
a skill live across many sessions without a settings file. **Must be removed before
shipping** (see [Cleanup](#cleanup) below).

> ⚠ Never register this repo's skills or extensions via **global** local-path entries in
> `settings.json` (e.g. `"extensions": ["~/code/skale-skills/.../statusline.ts"]` or
> `"skills": ["~/code/skale-skills/skills/d2"]`) while the git package is also installed.
> A local path and a git URL are **different identities** — pi loads both and emits
> `[Skill conflicts]` / `Tool "..." conflicts` at startup, even if the files are byte-identical.
> This is the same anti-pattern as hand-copying a `.ts` into `~/.pi/agent/extensions/`, or
> symlinking a skill into `~/.pi/agent/skills/`, next to a package install.
>
> For live dev use setup **A** (session-only flags) — nothing is written to settings, so there
> is no persistent override to collide. For a long dev session in one repo, setup **B** scopes
> the local identity to that repo's `.pi/settings.json` (still emits conflicts, but only there).

## The loop

1. **Edit** in `~/code/skale-skills`.
2. **Test** locally — setup A or B above, or run the skill's suite under `tests/<name>/`.
3. **Commit & push** from the working tree:
   ```bash
   cd ~/code/skale-skills
   git pull --rebase origin main        # stay current
   git add <explicit files>             # NEVER `git add -A` (untracked noise like package-lock.json)
   git commit -m \"...\"
   git push origin main
   ```
4. **Sync pi** to the new tip:
   ```bash
   pi update --extension git:github.com/devskale/skale-skills
   ```
5. **Clean up dev overrides** (the step everyone forgets — see below).

## Cleanup

After step 4 the git package has your changes. Remove the temporary overrides so the git
package is the sole source:

```bash
# Setup A (session-only): nothing to do — the override is gone on restart by design.

# Setup B (project-path package): remove the settings file when dev is done.
rm ~/code/skale-skills/.pi/settings.json

# Setup C (symlink): remove the symlink.
rm ~/.pi/agent/skills/<name>

# Any loose extension file you (or an old install) left behind:
rm ~/.pi/agent/extensions/<name>.ts
```

Then restart pi and confirm a **clean startup** — no `[Skill conflicts]` block.

## ⚠ The critical catch

> Never delete a dev override (step 5) **before** the fix is pushed (step 3) and
> pi-updated (step 4).

If the override routes the agent to a *fixed* version while the git package still has the *old*
one, removing the override early **silently regresses** the agent — the override is the only
thing carrying your fix until the package catches up.

## Sanity checks after cleanup

```bash
pi list                                                            # only declared packages
ls ~/.pi/agent/skills/                                             # empty (git package provides skills)
ls ~/.pi/agent/extensions/                                         # only files NOT in the git package
git -C ~/.pi/agent/git/github.com/devskale/skale-skills log --oneline -3
                                                                   # at the tip you just pushed
```
