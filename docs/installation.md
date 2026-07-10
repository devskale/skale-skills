# Installation & Precedence

> **Operational runbook:** [install-runbook.md](install-runbook.md) — the fast detect → install → clean → verify procedure to add this repo's skills & extensions to a pi install. This doc is the deep *why* (identity, dedup, precedence); the runbook is the *what to type*.

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

**Two merge modes when the same package is in both scopes:**

| Project entry | Behavior |
|---|---|
| plain `{ "source": "..." }` or string | **Replaces** the global entry for this project — re-list anything you want to keep. |
| `{ "source": "...", "autoload": false }` | **Delta over global** — toggle only what changes; everything else is inherited. `pi config -l` writes this automatically. |

```jsonc
// .pi/settings.json — delta: add one skill for this project, inherit the rest from global
{ "packages": [{
  "source": "git:github.com/devskale/skale-skills",
  "autoload": false,
  "skills": ["+skills/rodney"]
}]}
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
any skill / extension / prompt / theme from installed packages. It starts in global scope; press
**Tab** to switch to project-local, or run `pi config -l` to start there with inherited global
resources dimmed. In project mode it writes `autoload: false` delta entries (see above).

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

A tempting shortcut is to point a project setting at a local checkout:

```jsonc
// ~/code/.pi/settings.json — BROKEN if the global git package is also installed
{ "packages": ["~/code/skale-skills"] }
```

A local path is a **different identity** from the git URL. Project settings **merge** over global —
they don't shadow a different identity — so under `~/code` both the local path *and* the global git
package load and you hit the [conflict gotcha](#the-conflict-gotcha-read-this-before-editing-settings)
above (different identities → both load).

For live edits while developing this repo, follow the dev loop in [development.md](development.md)
(edit → push → `pi update`), or on a dev machine tell the git package to load **skills only** and
bring extensions in via symlinks (see [Loose-file conflicts](#loose-file-conflicts-the-other-vectors)).
