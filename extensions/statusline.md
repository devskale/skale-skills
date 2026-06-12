# statusline

Cloned built-in pi footer + machine name branding on line 1.

```
jMacAir ~/code/my-project (main) • session-name
↑102k ↓20k R2.0M W50.3k CH80.2% $0.042 28.5%/205k (auto)              (zai) glm-5.1 • low
Z.ai:6% (4h 9m 42s)
```

Identical to the built-in footer with **one addition**: machine name (`jMacAir`) prepended on line 1.

### What it includes (full parity with built-in)

- **Line 1**: `machineName` + cwd + `(git-branch)` + `• sessionName`
- **Line 2**: `↑in ↓out RcacheRead WcacheWrite CHhitRate% $cost (sub)` + colored context `%` + right-aligned model/provider/thinking
- **Line 3**: extension statuses (e.g. Z.ai usage)

### Context % coloring

- Normal: plain
- \>70%: warning (yellow)
- \>90%: error (red)

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
