---
name: issues
description: Manage the cross-machine shared issue kanban (.handoff/<project>/issues/). Create, triage, start, review, cancel, archive, or purge work items. One synced dir per project (.handoff/ → ~/code/handoffs/<project>/), shared across machines and repos. Use when creating, reading, picking up, triaging, cleaning up, or asking about tickets, tasks, issues, the backlog, kanban, or the board — or when handing work off / passing tasks to another machine, repo, or person. Triggers on mentions of issue, ticket, task, backlog, kanban, board, triage, assign to, pass to, hand off, cleanup done tasks.
metadata:
  author: skale
  version: "1.2.0"
---

## What this is

Every project has **one synced kanban** at `.handoff/<project>/issues/`,
reachable from every repo in the project via a `.handoff` symlink. One
markdown file per issue. One CLI manages everything:

```bash
issues --help      # ← all detail functions, config keys, troubleshooting
```

`issues` is a **machine-global** command (on PATH). It works from any repo
because it resolves the project by walking up from `$PWD` to the `.handoff`
link. Setting up a NEW project board is one command, from any repo checkout:

```bash
issues init <project>          # board (5 columns) + .handoff symlink, idempotent
issues init <project> --local  # degraded: real local dir, gitignored + WARN
```

New machine? `issues install.sh` (this skill dir) puts the CLI on PATH
(`~/.local/bin/issues`) — or, from a checkout of this repo:
`skills/issues/install.sh`.

> The synced dir keeps the historical name `.handoff` (existing symlinks keep
> resolving). This skill + CLI manage only the `issues/` subfolder of the
> current project; other shared subfolders (`docs/`, …) are just files.

## Quick Start

```bash
issues board                 # overview
issues doctor                # setup check (new machine? start here)
issues new <slug> [to]       # create (from = me@<repo>)
issues todo                  # what's waiting on you
issues start <slug> → work → issues review <slug> → issues done <slug>
```
(New project? `issues init <project>` first — see above.)

**New machine?** `issues doctor` checks the whole setup (synced root, transport,
identity, `.handoff` link, board columns) and `issues doctor --fix` applies the
safe fixes (create root, pin `~/.handoff-me`, create missing columns).

**As a worker:** `issues todo` → `issues start <slug>` → work → `issues review <slug>`.
**As a requester:** `issues mine review` → review → `issues done <slug>` (sets DONE → archive/).

`issues done <slug>` is the short form of `set <slug> DONE`. `issues archive` does NOT set DONE — it only sweeps stray DONE-state files into `archive/`.

## Gotchas

- **A slug lives in EXACTLY ONE live column.** Duplicates are a broken board
  state — `show`/`set` refuse loudly rather than guess. Merge into one file,
  delete the stray.
- **`archive/` + `cancelled/` are history.** Terminal copies may coexist with a
  revived live copy; commands resolve to the LIVE copy. Don't hand-edit
  terminal columns — use `purge` to remove, or move back to a live column to
  reopen.
- **`purge` deletes the live file everywhere.** The synced root has no git —
  but the local auto-commit history (LaunchAgent, hourly, per-machine) is a
  recovery net: `git -C ~/code/handoffs log`. History is NOT synced; a purged
  file is recoverable only on machines with local history. Double-check before
  purging.
- **Project-specific values** (version, module, triage vocabulary) come from
  `<project>/.issues/config`, NOT from the code — see `issues --help` §CONFIG.

## References

- Full command list, config keys, troubleshooting: `issues --help`
- Triage role labels (`needs-triage` … `wontfix`): config `triage` key, see `--help`
