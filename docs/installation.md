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

## Selective loading (filter package resources)

The git package ships **all** skills and extensions declared in its manifest. Loading
everything is rarely what you want — each loaded skill adds its name + description to the
system prompt catalog (progressive disclosure keeps the *body* out of context, but the
*catalog* is always in). Install only what you use (typically 4–8 skills); loading all of a
large collection causes context rot and routing competition.

Use the **object form** to whitelist specific resources:

```jsonc
// ~/.pi/agent/settings.json
{
  "packages": [
    {
      "source": "git:github.com/devskale/skale-skills",
      "skills": ["d2", "rodney", "fetch-url", "web-search"],  // only these load
      "extensions": ["./extensions/*.ts"]                     // omit a key to load all of a type
    }
  ]
}
```

Filter syntax (layers over the manifest, narrows what it declares):
- Omit a key → load **all** resources of that type the package provides.
- `[]` → load **none** of that type (e.g. `"extensions": []` for skills-only).
- `["name1", "name2"]` → load only named skills (by directory name).
- `!pattern` → exclude matches; `+path` / `-path` → force include/exclude an exact path.

Toggle resources interactively without editing JSON: `pi config` opens a TUI to enable/disable
any skill / extension / prompt / theme from installed packages.

> When migrating from loose symlinks to the package, **remove the loose copies** — see
> [Loose-file conflicts](#loose-file-conflicts) below. Otherwise both identities load and pi
> emits `[Skill conflicts]` at startup.

## Loose-file conflicts (the other vectors)

The identity rule above covers `settings.json` entries. But pi **also** auto-loads any
file dropped directly into two agent directories, and those collide with the git package just
the same — they are *different identities* (a loose path vs. a git URL):

| Dir | What pi loads there | Conflict symptom |
|-----|---------------------|------------------|
| `~/.pi/agent/skills/` | skill dirs or **symlinks** (e.g. `fetch-url`, `web-search`) | `[Skill conflicts]` warning at startup |
| `~/.pi/agent/extensions/` | loose `.ts` extension files (e.g. `statusline.ts`) | **tool-registering extensions → hard error** (see below); event-only extensions → loose file shadows/overrides the package copy |

#### Tool-registering extensions collide hard

If the loose extension registers a tool (e.g. `generate_image` via `pi.registerTool()`),
the collision is not a silent shadow — it's a fatal load error and pi won't start:

```
Error: Failed to load extension "...git/.../skale-skills/extensions/imagegen.ts":
Tool "generate_image" conflicts with ~/.pi/agent/extensions/imagegen.ts
```

This is why `statusline` (event/widget only, no tool) tolerates a dev symlink, but
`imagegen` (registers `generate_image`) does not — the git-package copy and the
loose copy both try to register the same tool name.

These get left behind after manual `install.sh` runs, hand-copies, or old symlink setups. They
load **in addition to** the git package → conflict, even if byte-identical. Identity, not
content, decides dedup.

### How to check for them

```bash
ls ~/.pi/agent/skills/             # should be empty if the git package provides them
ls ~/.pi/agent/extensions/         # only files NOT in the git package belong here
```

### Fix

Delete the loose copies — the git package is the canonical source:

```bash
rm ~/.pi/agent/skills/<name>        # symlink or directory
rm ~/.pi/agent/extensions/<name>.ts # loose file
```

> Do **not** "fix" this by making the loose file byte-identical to the package — that doesn't
> change its identity, so the conflict persists. Delete it.

#### Dev machine: keep the symlink, suppress the package copy instead

If you develop this repo locally and want **live edits** via a symlink
(`~/.pi/agent/extensions/imagegen.ts` → your checkout), you can't also let the
git package load its extensions — the two copies conflict. On a dev machine,
tell the git package to load **skills only** and let extensions come from your
symlinks:

```jsonc
// ~/.pi/agent/settings.json (dev machine)
{
  "packages": [{
    "source": "git:github.com/devskale/skale-skills",
    "skills": ["fetch-url", "web-search"],
    "extensions": []   // ← dev: extensions via symlinks, package = skills only
  }]
}
```

Event-only extensions (statusline) can coexist either way since they register
no tool to clash on; tool-registering ones (imagegen) require this split.

See [development.md](development.md) for the loop that produces these leftovers and how to
avoid leaving them behind.

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
