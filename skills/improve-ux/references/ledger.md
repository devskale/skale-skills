# Findings ledger — progressive passes per target

> The memory that makes improvement *progressive*: each target keeps a ledger
> of found issues, severities and statuses. Re-invocations continue the last
> pass instead of restarting from zero.

Path: `~/.cache/skale-skills/improve-ux/targets/<slug>.json`
(slug = project dir name, or a name the user gives).

## Schema

```json
{
  "target": "klark0 checkout page",
  "stack": "React + Tailwind + shadcn",
  "passes": [
    {
      "date": "2026-09-12",
      "scope": "checkout form",
      "findings": [
        { "id": "F1", "severity": "blocker", "topic": "a11y",
          "issue": "submit button 32×20px", "fix": "padded to 44×44",
          "citation": "WCAG 2.5.5", "status": "fixed" },
        { "id": "F2", "severity": "minor", "topic": "motion",
          "issue": "drawer 400ms linear", "fix": null,
          "citation": "sota/motion.md", "status": "open" }
      ]
    }
  ]
}
```

## Protocol

1. **Read the ledger first.** A target with a ledger continues its last pass —
   open items come before new discovery.
2. **Verify claimed `fixed` items still hold** (spot-check + axe); regressions
   reopen the finding.
3. New findings get ids `F<n>` (per target, monotonic — never reuse).
4. Severity ladder: **blocker** (a11y fail / unusable) > **major**
   (hierarchy or interaction broken) > **minor** (polish).
5. Deferred work stays `open` — the next pass starts exactly there.
6. Append passes; never rewrite history.
