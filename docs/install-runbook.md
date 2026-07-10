# Install Runbook — add this repo's skills & extensions to pi

The fast, copy-pasteable procedure. For the *why* (identity, dedup, precedence) see
[installation.md](installation.md); this doc is the *what to type, in what order, and how to
verify*.

## When to use

A machine has this repo checked out but **not** registered as a pi package — i.e. the skills
and extensions aren't loading in pi yet, or are loading only as loose symlinks/files left over
from an old setup. Goal: one canonical git package, no conflicts, clean startup.

> **Do not** register this repo via a local-path entry (`"~/code/skale-skills"`) while the git
> package is (or will be) installed — a local path and a git URL are *different identities*, so
> both load and conflict on every startup. The git package is canonical. See
> [installation.md → The conflict gotcha](installation.md#the-conflict-gotcha-read-this-before-editing-settings).

---

## 0. Detect & classify loose conflicts (the footgun)

Pi auto-loads anything dropped directly into `~/.pi/agent/skills/` and `~/.pi/agent/extensions/`.
If a loose copy of a repo resource is sitting there when you install the git package, the two
are *different identities* → both load → `[Skill conflicts]` warning, or a **fatal tool-name
clash** for tool-registering extensions. This is the step everyone skips and then debugs for an
hour. Run it first.

```bash
repo=~/code/skale-skills

echo "== loose skills =="
for s in ~/.pi/agent/skills/*; do [ -e "$s" ] || continue; n=$(basename "$s")
  if [ -e "$repo/skills/$n" ]; then echo "  CONFLICT: $n  (repo ships it → delete loose copy)"
  else echo "  keep:     $n  (unrelated to this repo)"; fi
done

echo "== loose extensions =="
for e in ~/.pi/agent/extensions/*.ts; do [ -e "$e" ] || continue; n=$(basename "$e")
  if [ -e "$repo/extensions/$n" ]; then echo "  CONFLICT: $n  (repo ships it → delete loose copy)"
  else echo "  keep:     $n  (unrelated to this repo)"; fi
done
```

Then check **which extensions register tools** — those go from a silent shadow to a **hard
load error** if a loose copy coexists:

```bash
grep -l registerTool "$repo"/extensions/*.ts   # e.g. heartbeat.ts imagegen.ts xmodel.ts
```

Anything printed here **must** not have a loose copy in `~/.pi/agent/extensions/` when the
package loads. Event-only extensions (e.g. `statusline.ts`) only shadow/silently-override —
still delete the loose copy, but they won't crash pi.

> **Stale-copy trap:** a loose extension that *differs* from the repo's isn't safer — it still
> conflicts by identity, **and** it silently shadows the (possibly newer) package copy until
> removed. `diff` it against the repo to tell identical-stale from customized-stale; back up
> any differing file in step 2 before deleting, in case it carries local changes.

## 1. Install the git package globally

```bash
pi install git:github.com/devskale/skale-skills
```

Clones to `~/.pi/agent/git/github.com/devskale/skale-skills` and appends a bare
`"git:github.com/devskale/skale-skills"` entry to `~/.pi/agent/settings.json`.

> **All resources load by default.** A bare entry (no `skills`/`extensions` keys) loads every
> skill and extension the package ships. That's fine for a first install; narrow it in step 4
> if you want only a subset. Each loaded skill adds its name+description to the system-prompt
> catalog, so loading all of a large set causes context rot — don't leave "load everything" on
> long-term without reason.

## 2. Remove loose conflicts (back up differing files first)

For each `CONFLICT` from step 0, back up the loose copy **only if it differs** from the repo
(it may carry local customizations), then delete it:

```bash
mkdir -p /tmp/pi-cleanup-backup
for n in <conflict-skill-names>; do
  rm ~/.pi/agent/skills/"$n"   # symlink or real dir
done
for n in <conflict-extension-names>; do
  if ! diff -q ~/.pi/agent/extensions/"$n" "$repo/extensions/$n" >/dev/null 2>&1; then
    cp ~/.pi/agent/extensions/"$n" /tmp/pi-cleanup-backup/"$n".bak
    echo "backed up differing $n → /tmp/pi-cleanup-backup/$n.bak"
  fi
  rm ~/.pi/agent/extensions/"$n"
done
```

Leave the `keep:` entries alone — they belong to other packages.

> Never "fix" a conflict by making the loose file byte-identical to the package — identity, not
> content, decides dedup. Delete the loose copy; the git package is the canonical source.

## 3. Verify a clean load

```bash
pi list                       # shows the package, no error
```

Then **restart pi** and confirm the startup banner has **no `[Skill conflicts]` block** and no
`Tool "..." conflicts` error. A clean startup is the only real proof — `pi list` won't surface
load-time tool clashes.

Sanity check the clone is at the tip you expect:

```bash
git -C ~/.pi/agent/git/github.com/devskale/skale-skills log --oneline -1
```

## 4. (Optional) Narrow to a whitelist

Loading everything is fine to start, but for long-term use pick the 4–8 skills you actually use.
Two ways:

**Interactive (recommended):**

```bash
pi config            # TUI: space=toggle, Tab=switch scope, esc=close
```

**Or hand-edit** the package entry in `~/.pi/agent/settings.json` to the whitelist form (plain
paths/names = "only these load"):

```jsonc
{ "packages": [{
  "source": "git:github.com/devskale/skale-skills",
  "skills": ["fetch-url", "web-search"],
  "extensions": ["extensions/statusline.ts", "extensions/xmodel.ts"]
}]}
```

See [installation.md → Selective loading](installation.md#selective-loading-filter-package-resources)
for filter syntax and the `+path` gotcha. Omit a key to load all of that type; `[]` loads none.

---

## Fast path (clean machine, no loose leftovers)

If step 0 finds no conflicts, the whole thing collapses to:

```bash
pi install git:github.com/devskale/skale-skills && pi list
# restart pi → confirm no [Skill conflicts] block
```

## Why this works

Pi deduplicates packages by **identity** (git URL / npm name / resolved local path), not by
file content. A loose file in `~/.pi/agent/{skills,extensions}/` is a *different identity* from
the git package, so both load and clash. Installing the git package once and deleting every
loose copy of its resources leaves exactly one identity per resource → no conflicts, and the
package is the single source of truth. Full model: [installation.md](installation.md).
