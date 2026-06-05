# statusline

Custom pi footer with machine name branding + session stats.

```
jMacAir ~/code/my-project                                    (zai) glm-5.1 • low
↑102k ↓20k R2.0M 28.5%/205k (auto)
Z.ai:6% (4h 9m 42s)
```

- **Line 1**: machine name + cwd → provider + model + thinking level
- **Line 2**: token stats (↑in ↓out RcacheRead) + context usage
- **Line 3**: extension statuses from other extensions (e.g. Z.ai)

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

- pi ≥ 0.78
- macOS, Linux, or Windows (uses `scutil` on macOS, `hostname` on Windows, falls back to `os.hostname()` on Linux)

## Gotchas

- `setFooter()` replaces the built-in footer entirely — extension statuses from `setStatus()` don't render automatically. Collect them via `footerData.getExtensionStatuses()`.
- `getContextUsage()` returns `NaN`/`0` for `limit` on first render. Guard with `usage && usage.limit > 0`.
- `setTitle()` gets overwritten by pi during lifecycle events. Re-assert on `agent_end` if you need it.
