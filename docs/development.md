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

## Two supported dev setups

### A. Project-path package (preferred — scoped, conflict-free)

Point a **project** setting at your local checkout, only under the repo dir. See
[installation.md → Live dev setup](installation.md#live-dev-setup-optional) for the full
rationale. In short:

```jsonc
// ~/code/.pi/settings.json  (project-scoped, NOT global)
{ "packages": ["~/code/skale-skills"] }
```

This local-path identity loads **only** under `~/code`. Everywhere else the global git package
wins. No conflict, live edits under the checkout, and pushes flow to the package after
`pi update`.

### B. Symlink a single skill (quick check of one skill)

```bash
ln -s ~/code/skale-skills/skills/<name> ~/.pi/agent/skills/<name>
```

Use this to test one skill against the live agent. **Must be removed before shipping** (see
[Cleanup](#cleanup) below), otherwise it conflicts with the git package.

> ⚠ Never hand-copy an extension's `.ts` into `~/.pi/agent/extensions/` to test it. That leaves
> a loose-file conflict. Use setup **A** instead.

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
# Setup A: nothing to do if you still want live dev.
#           Remove ~/code/.pi/settings.json only when you're done developing this repo.

# Setup B: remove the symlink
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
