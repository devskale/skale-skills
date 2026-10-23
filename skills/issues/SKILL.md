---
disable-model-invocation: true
name: issues
description: Manage the cross-machine shared issue kanban (works/<project>/issues/). Create, triage, start, review, cancel, archive, or purge work items. One synced dir per project (repo .work → ~/code/skaleshare/works/<project>/), shared across machines and repos. Use when creating, reading, picking up, triaging, cleaning up, or asking about tickets, tasks, issues, the backlog, kanban, or the board — or when handing work off / passing tasks to another machine, repo, or person. Triggers on mentions of issue, ticket, task, backlog, kanban, board, triage, assign to, pass to, hand off, cleanup done.
metadata:
  author: skale
  version: "1.5.1"
---

## What this is

Every project has **one synced kanban** at the shared works root
(`~/code/skaleshare/works/<project>/issues/`), reachable from every repo in the
project via a container symlink — **`.work`** by default (`ISSUES_LINK_NAME` to
override; legacy `.handoff` links keep resolving). One markdown file per issue.
One CLI manages everything:

```text
the chain (one line, top to bottom):

<repo>/.work  →  ~/code/skaleshare/works/<project>/issues/{backlog,active,review,archive,cancelled}
  symlink         shared works root (Syncthing)      one .md file per issue
```

```bash
issues --help      # ← all detail functions, config keys, troubleshooting
```

`issues` is a **machine-global** command (on PATH). It resolves the project by
**walking up** from `$PWD`: at each directory level it checks for the container
link — `.work` first (configurable via `ISSUES_LINK_NAME`), then legacy names
(`.handoff`) — until it finds one. A symlink target is the shared project dir;
a real dir is a local board (`init --local`). Nothing found → run `issues init`.
Setting up a NEW project board is one command, from any repo checkout:

```bash
issues init <project>          # board (5 columns) + .work container link, idempotent
issues init <project> --local  # degraded: real local dir, gitignored + WARN
```

New machine? `issues install.sh` (this skill dir) puts the CLI on PATH
(`~/.local/bin/issues`) — or, from a checkout of this repo:
`skills/issues/install.sh`. The skill manages only `<project>/issues/`;
other shared subfolders (`docs/`, …) are just files.

## Transports — every repo can have the board

The works root syncs by whatever the machine has; the CLI adapts:
**Syncthing** or **network mount** (pi5/CIFS) = automatic · **throway-
virtualisiert** (nothing shared): `init` bootstraps from the `skale.dev/throway`
snapshot, changes auto-push, `issues pull` fetches (last push wins) ·
**`--local`** = offline board in-repo, gitignored, WARNed. Legacy `handoffs`
roots migrate automatically (`init` / `doctor --fix`).

## Quick Start

```bash
issues board                 # overview
issues doctor [--fix]        # setup check; --fix migrates legacy roots + safe fixes
issues new <slug> [to]       # create (from = me@<repo>)
issues todo                  # what's waiting on you
issues start <slug> → work → issues review <slug> → issues done <slug>
```

**As a worker:** `issues todo` → `issues start <slug>` → work → `issues review <slug>`.
**As a requester:** `issues mine review` → review → `issues done <slug>` (sets DONE → archive/).

**Commit referencing an issue ⇒ update the issue in the same session** (check off the step, note the hash). A stale issue claiming "uncommitted" while the work is pushed sends the next session re-verifying done work (retro 2026-10-08: `ai-chat-2b-sse-finish` described a `3fecaff9`-already-landed state as uncommitted).

`issues done <slug>` is the short form of `set <slug> DONE`. `issues archive` does NOT set DONE — it only sweeps stray DONE-state files into `archive/`.

## Gotchas

- **A slug lives in EXACTLY ONE live column.** Duplicates are a broken board
  state — `show`/`set` refuse loudly rather than guess. Merge into one file,
  delete the stray.
- **Rebase orphans hashes.** Issues cite commit hashes; a `pull --rebase`
  rewrites them and the next session chases a dead hash (retro 2026-10-08:
  an issue cited pre-rebase hashes, costing the agent a verification
  detour). After rebasing, re-check hashes you cited
  (`git cat-file -e <hash>^{commit}`) and update the issue.
- **`archive/` + `cancelled/` are history.** Terminal copies may coexist with a
  revived live copy; commands resolve to the LIVE copy. Don't hand-edit
  terminal columns — use `purge` to remove, or move back to a live column to
  reopen.
- **`purge` deletes the live file everywhere — and there is NO recovery net.**
  2026-10-21 decision: NO auto-commit timer on any machine (an hourly
  `git add -A` on the Syncthing-synced `.git` corrupted the repo 2× — see
  `~/configs/machines/skaleshare-works-no-autocommit.md`). Recovery exists
  only via manual commits that happened to run earlier
  (`git -C ~/code/skaleshare/works log`). Double-check before purging.
- **Project-specific values** (version, module, triage vocabulary) come from
  `<project>/.issues/config`, NOT from the code — see `issues --help` §CONFIG.

## References

- Full command list, config keys, troubleshooting: `issues --help`
- Triage role labels (`needs-triage` … `wontfix`): config `triage` key, see `--help`
