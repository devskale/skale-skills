# Installing skale-skills in pi

This repo is a **pi package** — `package.json` declares a `pi` manifest (`./skills`,
`./extensions/*.ts`, `./prompts`). Install it once from git, globally, then activate only the
skills you use.

## Install (one line)

```bash
pi install git:github.com/devskale/skale-skills
```

This clones to `~/.pi/agent/git/github.com/devskale/skale-skills` and writes
`git:github.com/devskale/skale-skills` into `~/.pi/agent/settings.json`. The package then
loads **everywhere** on the machine.

> A bare entry loads **all** skills and extensions the package ships. Each loaded skill adds
> its name + description to the system-prompt catalog, so loading everything causes context
> rot and routing competition. Install the package, then **narrow to what you use** (below).

## Activate only the skills you use

The package ships all skills, but you typically want 2–8. Two ways — pick one:

**Interactive (recommended):**

```bash
pi config            # TUI: space=toggle, Tab=switch scope, esc=close
pi config -l         # start in (project) scope; inherited globals shown DIMMED
```

**Or hand-edit** the package entry in `~/.pi/agent/settings.json` to the whitelist form —
plain names/paths mean "only these load":

```jsonc
// ~/.pi/agent/settings.json
{ "packages": [{
  "source": "git:github.com/devskale/skale-skills",
  "skills": ["web-search", "fetch-url"],   // only these two skills load
  "extensions": ["extensions/heartbeat.ts",
                 "extensions/xmodel.ts",
                 "extensions/statusline.ts"]
}]}
```

Restart pi to apply.

### Filter semantics (what decides what loads)

| `skills` / `extensions` array | Result |
|---|---|
| key **omitted** | load **all** of that type |
| `[]` | load **none** (explicitly off) |
| `["name1", "name2"]` (plain) | load **only** named (whitelist) |
| `"!pattern"` | exclude glob matches |
| `"+path"` / `"-path"` | force include / exclude an exact path |

Plain-name includes match by skill **directory name** (e.g. `"rodney"`). Paths match relative
to package root (e.g. `"+skills/jodney/SKILL.md"`).

> ⚠️ **`+path` gotcha:** force-includes (`"+extensions/x.ts"`) re-enable within an otherwise-on
> set — used **alone** they turn the whole type on. For "only these", use plain names/paths,
> not `+path`. The `pi config` TUI manages this for you; hand-editing is where it bites.

## Update

```bash
pi update git:github.com/devskale/skale-skills   # one package
pi update --all                                    # pi + all packages
```

---

## Troubleshooting: the loose-file conflict

> Skip this unless you see `[Skill conflicts]` at startup, or a `Tool "..." conflicts` error.

Pi **auto-loads** anything dropped directly into `~/.pi/agent/skills/` and
`~/.pi/agent/extensions/` — including **symlinks**. When a loose copy of a repo resource sits
there *and* the git package is installed, the two are **different identities** → both load →
conflict (a startup warning for skills, a **fatal load error** for tool-registering
extensions).

This is what bites a bare `pi install` on a machine with old symlink setups, hand-copies, or
leftover dev overrides. **Identity, not content, decides dedup** — making a loose file
byte-identical to the package does **not** fix it; delete it.

### Detect

```bash
# loose skills/symlinks that the package also ships:
for s in ~/.pi/agent/skills/*; do [ -e "$s" ] || continue; n=$(basename "$s")
  [ -e ~/.pi/agent/git/github.com/devskale/skale-skills/skills/$n ] && echo "CONFLICT: $n"
done

# loose extensions that the package also ships:
for e in ~/.pi/agent/extensions/*.ts; do [ -e "$e" ] || continue; n=$(basename "$e")
  [ -e ~/.pi/agent/git/github.com/devskale/skale-skills/extensions/$n ] && echo "CONFLICT: $n"
done
```

> **Which extensions register tools?** `grep -l registerTool extensions/*.ts` (e.g.
> `heartbeat.ts`, `imagegen.ts`, `xmodel.ts`). A loose copy of one of these is a **hard load
> error**, not a warning. Event-only extensions (e.g. `statusline.ts`) only silently shadow —
> still delete the loose copy.

### Fix

Delete the loose copies — the git package is the canonical source:

```bash
rm ~/.pi/agent/skills/<name>         # symlink or directory
rm ~/.pi/agent/extensions/<name>.ts  # loose file
```

Then restart pi and confirm a **clean startup** — no `[Skill conflicts]` block, no
`Tool "..." conflicts` error. `pi list` won't surface load-time tool clashes; a clean restart
is the only real proof.

> Back up a loose file **before** deleting it **only if it differs** from the package copy —
> it may carry local customizations. `diff` it first.

### Why this happens (the deep model)

Pi deduplicates packages by **identity**:

| Source type | Identity |
|-------------|----------|
| npm         | package name |
| git         | repository URL without ref |
| local path  | resolved absolute path |

A git package and a loose path/symlink are different identities, so pi loads both and they
clash — even if byte-identical. The git package is canonical: install it once, delete every
loose copy of its resources, and you get exactly one identity per resource.

**Per-project skills** (when you want one skill in one project without re-cloning the whole
package): symlink it from the global clone —

```bash
ln -s ~/.pi/agent/git/github.com/devskale/skale-skills/skills/<name> <project>/.pi/skills/<name>
```

pi discovers `.pi/skills/` and follows symlinks. Don't symlink a skill that's *also* in the
global whitelist, or it loads twice.

---

## Dev loop (editing this repo)

While developing skills/extensions here, load the working tree **without** leaving conflicts
for the git package. Prefer session-only flags; land changes upstream before removing any
override. Full workflow: [development.md](development.md).
