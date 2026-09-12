# Deep review — external skill bundle

> Load when the task is a *whole-review* or a deep, category-specific pass.
> Not needed for ordinary improvements.

[jakubkrehel/skills](https://github.com/jakubkrehel/skills) bundles ready-made
agent skills: `better-ui`, `better-typography`, `better-colors`,
`better-accessibility`, `better-layout`, `better-writing`, `interface-review`,
`break` (render a component in every state) and `variant`.

```bash
npx skills add jakubkrehel/skills
```

Drive these for deep, category-specific reviews instead of reinventing each
checklist. `break` is especially useful before/after a change: render the
component in every state (default, hover, focus, loading, empty, error) and
compare.
