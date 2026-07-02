# xmodel — model/thinking fast-switcher

Fast-switch model + thinking-level presets from inside a pi session, with optional
automatic fallback to a free variant when the active provider rate-limits (HTTP 429/503/529).

Lives at `~/.pi/agent/extensions/xmodel.ts` (symlinked into the skale-skills repo).

## Commands

| Command | What |
|---|---|
| `/xm <name>` | Switch to preset `<name>` (sets model + thinking level) |
| `/xm off` | Disable the extension (stop auto-fallback) |
| `/xm list` | Show available presets + active preset |
| `/xm` | Same as `/xm list` |

## Config

Presets live in `~/.pi/agent/xmodel.json` (project-local `.pi/xmodel.json` overrides):

```jsonc
{
  "deep":       { "provider": "zai",        "model": "glm-5.2",            "thinkingLevel": "high",   "fallback": "deep-free" },
  "deep-free":  { "provider": "opencode",    "model": "deepseek-v4-flash-free", "thinkingLevel": "high" },
  "light":      { "provider": "zai",        "model": "glm-5.2",            "thinkingLevel": "off" },
  "vision":     { "provider": "opencode",    "model": "claude-sonnet-4-6",  "thinkingLevel": "medium" }
}
```

### Fallback resolution (first match wins)

1. **Explicit** `fallback` field on the active preset → switch to that preset.
2. **`<name>-free` convention** → e.g. active `deep` looks for `deep-free`.
3. **Any `*free*` preset** with a different model id → first match (last resort).

### Guards

- Only rate-limit/overload statuses trigger fallback: `429`, `503`, `529`.
- 30s cooldown prevents flapping between models.
- No infinite chain — if already on the best free model and it 429s, notifies instead of cascading.
- Badge (`↩ fallback: <name>`) clears on manual `/xm <name>` or `/xm off`.

## Status line

When a fallback is active, the status line shows `↩ fallback: <preset>`. `retry-after` header is surfaced in the notification when the provider sends one.
