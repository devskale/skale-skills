# statusline

Built-in pi footer + **machine name always first on line 1**, **Z.ai quota** (with time-to-window), and progressive narrow-terminal compaction.

```
jMacAir ~/code/my-project (main) • session-name
↑102k ↓20k R2.0M W50.3k CH80.2% $0.042 28.5%/205k (auto)     zai 6% (4h09m) glm-5.1 • low
```

## What it shows

### Line 1 — `machineName` always first
- `machineName` (accent) — **never dropped, even on narrow terminals**.
- `~/cwd (git-branch) • sessionName`
- On narrow terminals, progressively drops `sessionName → branch`, then truncates cwd. Machine name stays.

### Line 2 left — token/context stats
- `↑in ↓out RcacheRead WcacheWrite CHhitRate% $cost (sub)`
- Context `%`/window, colored: **warning >70%**, **error >90%**
- `xp` marker when `PI_EXPERIMENTAL=1` (parity with built-in, pi ≥ 0.79.5)
- On narrow terminals, progressively skips: `(auto) → CH → R`

### Line 2 right — model + Z.ai quota
- `zai {pct}% ({time-to-window-reset})` — **leads the cluster so it survives truncation**, color-coded: **accent <50%**, **warning ≥50%**, **error ≥80%**.
- Model + thinking level. The redundant `(zai)` provider prefix is dropped when Z.ai quota is shown.
- Example: `zai 6% (4h09m) glm-5.1 • low`

### Line 3 — extension statuses (via `ctx.ui.setStatus()`)

## Narrow-terminal behavior

Two independent compaction layers keep the important things visible as the terminal shrinks:

| Layer | Drop order (most expendable first) | Always kept |
|-------|------------------------------------|-------------|
| Line 1 | `sessionName → branch → cwd…` | **machineName** |
| Line 2 left | `(auto) → CH → R` | `↑ ↓ W $ ctx%` |
| Line 2 right | model truncates from the right | **zai %/time** (leads) |

## Z.ai quota refresh

- Fetched on `session_start`, every `model_select`, and after each `turn_end`.
- A periodic background poll every **3 min** keeps the time-to-window fresh while idle (timer is `.unref()`'d so it never keeps the process alive; cleared on `session_shutdown`).
- 30 s cooldown between fetches; 8 s request timeout; on error the previous cached value is kept.

> Only active when the current model's provider starts with `zai` (e.g. `glm-5.x`). Requires a `zai` API key in `auth.json` / credgoo.

## Install

Add to pi settings:

**Global** (`~/.pi/agent/settings.json`):
```json
{
  "extensions": ["~/.pi/agent/extensions/skale-skills/extensions/statusline.ts"]
}
```

**Project** (`.pi/settings.json`):
```json
{
  "extensions": [".pi/extensions/statusline.ts"]
}
```

**Quick test**:
```bash
pi -e ./extensions/statusline.ts
```

## Requirements

- pi ≥ 0.79
- macOS, Linux, or Windows (uses `scutil` on macOS, `hostname` on Windows, falls back to `os.hostname()` on Linux)

## Caveat

`(auto)` is always appended after the context %. The built-in footer hides it when auto-compaction is disabled (`session.autoCompactionEnabled`), but `ExtensionContext` does not expose that flag, so we cannot replicate it. Compaction is enabled by default, so this is accurate in the common case.
