# Plan: dedupe skale-skills skill/extension installs (canonical = git package)

**Date:** 2026-06-22
**Author:** pi5 session (verified state, not yet executed)
**Goal:** Eliminate the pi `[Skill conflicts]` warning and the loose `statusline.ts` override — **without regressing functionality** — by making the `git:github.com/devskale/skale-skills` package the single canonical source (per the repo's own `docs/installation.md`).

---

## TL;DR

`~/.pi/agent/settings.json` already declares the git package as canonical:

```json
"packages": ["npm:@ff-labs/pi-fff", "git:github.com/devskale/skale-skills"]
```

But two **leftover manual installs** duplicate it and cause the noise:

1. `~/.pi/agent/skills/{fetch-url,web-search}` — **symlinks** into `~/code/skale-skills/skills/` → collide with the git-package skills → the `[Skill conflicts]` warning.
2. `~/.pi/agent/extensions/statusline.ts` — a **loose hand-copied file** that shadows the package's statusline (differs only in a rewritten doc-comment header).

**⚠ The catch:** blindly removing the `web-search` symlink **regresses** the agent — the symlink currently routes it to the *working clone*, which has uncommitted fixes the package lacks. Must land those fixes upstream first.

---

## Verified state (as of 2026-06-22)

### Three copies of the repo

| Copy | Path | Remote | HEAD | Role |
|------|------|--------|------|------|
| Working clone | `~/code/skale-skills/` | `git@github.com:devskale/skale-skills.git` | `828e8ba` (1 behind origin) | active dev tree |
| pi-managed clone | `~/.pi/agent/git/github.com/devskale/skale-skills/` | https | `d6c6360` | auto-managed by `pi install` |
| origin/main | github.com/devskale/skale-skills | — | `d6c6360` | canonical |

- **`origin/main = d6c6360`** (re-verified via both `git ls-remote` and `git fetch`). An earlier transient `ls-remote` showed `541260d` — ignore; `d6c6360` is authoritative.
- **`d6c6360` only touches `skiller/`** ("retire crawler/search" = skiller's crawler/search subcommands, **not** the `web-search` skill). It does NOT touch `skills/web-search/` or `extensions/statusline.ts`. Rebase is clean.

### Uncommitted work in the working clone (valuable, NOT on origin)

```
 M skills/web-search/install.sh
 M skills/web-search/search
```

- `search` launcher: the **committed** version hardcodes `cd "/Users/johannwaldherr/.pi/agent/skills/web-search"` (a **macOS path, broken on this Linux box**). The local edit replaces it with symlink resolution + adds `--update`, `--selfcheck`, 7-day auto-update, and a credgoo health check.
- `install.sh`: switches the global launcher from a generated script to a **symlink** (same pattern as `fetch-url`).
- `git diff HEAD..origin/main -- skills/web-search/install.sh skills/web-search/search` = **0 lines** → `d6c6360` didn't touch these → `git pull --rebase` applies cleanly, no conflict.

### The loose statusline override

- `~/.pi/agent/extensions/statusline.ts` (399 lines) vs package/working-clone (392 lines): **only the doc-comment header differs** — zero code changes. The header rewrite is nicer (documents the 3 intentional changes + the `(auto)` caveat). Not committed anywhere.
- `git diff origin/main -- extensions/statusline.ts` = **0** → clean to land.

### Precedence reference
`~/.pi/agent/git/github.com/devskale/skale-skills/docs/installation.md` — *"The git package is canonical. Declare it once globally… Never add the same resources again under a different identity."*

---

## The plan

### Phase 1 — land the real work upstream (`~/code/skale-skills`)

```bash
cd ~/code/skale-skills

# 1. Get current (clean rebase — verified)
git pull --rebase origin main

# 2. Bring the better statusline header into the tracked file.
#    (loose file == working file EXCEPT for the header; verified.)
cp ~/.pi/agent/extensions/statusline.ts extensions/statusline.ts
git diff -- extensions/statusline.ts   # REVIEW: should show ONLY header doc lines

# 3. Commit the web-search launcher fix (2 files)
git add skills/web-search/install.sh skills/web-search/search
git commit -m "web-search: portable symlink launcher + --update/--selfcheck/auto-update

Replace hardcoded macOS path (broken on Linux) with symlink resolution.
install.sh now symlinks ~/.local/bin/web-search to the tracked 'search'
launcher, matching fetch-url's pattern. Adds --update, --selfcheck,
7-day auto-update, and credgoo health check."

# 4. Commit the statusline header doc improvement (1 file)
git add extensions/statusline.ts
git commit -m "statusline: improve header doc (parity + skip + auto caveat)"

# 5. Push
git push origin main
```

### Phase 2 — sync pi + remove the duplicates

```bash
# 6. Pull the new commits into the pi-managed clone
pi update --extension git:github.com/devskale/skale-skills

# 7. Remove the loose statusline override (canonical now has the same header)
rm ~/.pi/agent/extensions/statusline.ts

# 8. Remove the stale skill symlinks (conflict source)
rm ~/.pi/agent/skills/fetch-url ~/.pi/agent/skills/web-search

# 9. Restart pi and confirm a CLEAN startup (no [Skill conflicts] line)
```

---

## ⚠ Warnings / gotchas

- **Do NOT remove the `web-search` skill symlink (Phase 2 step 8) before Phase 1 is pushed + pi-updated.** Until then, the symlink routes the agent to the *fixed* launcher; the package version still has the broken hardcoded macOS path. Removing early = silent regression.
- **Do NOT `git add -A`.** There are untracked `package-lock.json` files (in the managed clone, possibly the working clone too). Only add the 3 intended files explicitly.
- **Identity, not content, decides dedup.** A git package + a local-path entry are *different identities* → both load → conflict. This is why the loose files must be deleted, not just made byte-identical. (See `docs/installation.md`.)
- `~/.pi/agent/extensions/herdr-agent-state.ts` is also a loose file — **out of scope** here; only `statusline.ts` and the two skills are the active conflicts.

---

## How to verify it worked

After Phase 2, restart pi. The startup banner should have **no `[Skill conflicts]` block**, and `fetch-url` / `web-search` / `statusline` should all still load (now from the git package).

Sanity checks:

```bash
# git-managed clone is at the new tip (has the web-search fix + statusline header)
git -C ~/.pi/agent/git/github.com/devskale/skale-skills log --oneline -3

# loose files gone
ls ~/.pi/agent/skills/ ~/.pi/agent/extensions/statusline.ts   # should error / be empty

# the fixed launcher no longer has the macOS path
grep -n johannwaldherr ~/.pi/agent/git/github.com/devskale/skale-skills/skills/web-search/search
# (expect: no match)
```

---

## Re-verify state before starting (git may have moved)

```bash
cd ~/code/skale-skills
git fetch origin
git log --oneline HEAD..origin/main          # should be empty or small
git status -sb                               # confirm only web-search + statusline intended changes
git diff HEAD..origin/main -- skills/web-search/ extensions/statusline.ts  # expect 0 (clean rebase)
git ls-remote origin refs/heads/main         # confirm origin tip
```
