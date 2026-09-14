# rodney process-management scripts

These scripts inspect and clean up rodney's Chrome/Chromium processes and temp files.
They are **utilities layered on top of the rodney Go CLI** — not rodney commands themselves.

## Why the process filter matters

rodney drives a **headless Chromium** that it downloads itself (via go-rod) into
`~/.cache/rod/browser/...`. Its process name is `Chromium` (not `chrome`), and it launches
with `--remote-debugging-port=0` (an ephemeral port). So a naive filter like
`grep 'chrome.*--remote-debugging-port'` **never matches** rodney's browser.

The reliable signature is the **`--user-data-dir`** flag, which always points at a `.rodney`
directory:
- global session → `~/.rodney/chrome-data`
- local session  → `./.rodney/chrome-data`

All scripts detect rodney processes via `user-data-dir=.*\.rodney`.

## Modes

| Command | Mode | Behavior |
|---------|------|----------|
| `rodney-cleanup` | inspect | Show managed + orphan processes (safe, no changes) |
| `rodney-cleanup --clean` | clean | Remove stale state, kill orphans, purge old /tmp dirs (non-interactive) |
| `rodney-cleanup --json` | json | Machine-readable summary `{managed_pid, total, orphans}` |
| `rodney-ps` | ps | Alias for inspect (selected by the `ps` symlink name) |

`--clean` is **non-interactive** on purpose: these scripts are meant to be called by agents
and scripts, where a `read -p` prompt would hang on stdin. `--clean` only ever touches
rodney-owned processes (identified by `.rodney` user-data-dir) and `/tmp/chrome-*` dirs
older than 24h — it never kills unrelated Chrome.

## Install (symlinks into ~/.local/bin)

```bash
ln -sf <repo>/skills/rodney/scripts/rodney-cleanup.sh ~/.local/bin/rodney-cleanup
ln -sf <repo>/skills/rodney/scripts/rodney-ps.sh        ~/.local/bin/rodney-ps
```

`rodney-ps` is a wrapper that execs `rodney-cleanup.sh`; the `ps` in the symlink name is
what flips it into ps/inspect mode, so flags like `--json` still work through it.

## Agent usage

```bash
rodney-cleanup --json    # is a rodney browser running? how many orphans?
rodney-cleanup --clean   # clean up before/after a session
```
