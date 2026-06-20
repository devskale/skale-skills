# Installation & Precedence

## Recommended

Install this package **once** from git, globally:

```bash
pi install git:github.com/devskale/skale-skills
```

This writes `git:github.com/devskale/skale-skills` into `~/.pi/agent/settings.json` and clones
it to `~/.pi/agent/git/github.com/devskale/skale-skills`. Heartbeat, statusline, and all skills
then load everywhere on the machine.

## The conflict gotcha (read this before editing settings)

Do **not** register this package's extension files via a raw `extensions:` path entry
*while also* having the git package installed — e.g.:

```jsonc
// ~/.pi/agent/settings.json — BROKEN: causes a tool-name conflict
{
  "packages": ["git:github.com/devskale/skale-skills"],
  "extensions": ["~/code/skale-skills/extensions/heartbeat.ts"]  // ❌ duplicate
}
```

**Why it breaks:** pi deduplicates packages by *identity*:

| Source type | Identity |
|-------------|----------|
| npm         | package name |
| git         | repository URL without ref |
| local path  | resolved absolute path |

A git package and a local-path entry are **different identities**, so pi loads both and you get
`Error: Tool "heartbeat" conflicts with ...`. This happens even though the two files are
byte-identical — identity, not content, decides dedup.

## Precedence rule

> **The git package is canonical.** Declare it once globally, and once per project that needs it.
> Never add the same resources again under a different identity.

Same identity in both global and project scope is **fine** — the project entry wins and the
package loads exactly once:

```jsonc
// ~/.pi/agent/settings.json (global)
{ "packages": ["git:github.com/devskale/skale-skills"] }

// ~/configs/.pi/settings.json (project — same identity, project wins, no clash)
{ "packages": ["git:github.com/devskale/skale-skills"] }
```

## Live dev setup (optional)

If you actively develop this repo at `~/code/skale-skills` and want edits reflected live in pi,
point a **project** setting at the local checkout instead of relying on the global clone:

```jsonc
// ~/code/.pi/settings.json
{ "packages": ["~/code/skale-skills"] }
```

This is a *local-path* identity scoped only under `~/code`, so it never co-loads with the git
package elsewhere (e.g. inside `~/configs`). No conflict, and pushes from the dev tree still flow
to the global git package after `pi update --extension git:github.com/devskale/skale-skills`.

Trade-off: with the global git package installed, the **global clone** wins everywhere outside
`~/code` — live edits only apply under the dev checkout.
