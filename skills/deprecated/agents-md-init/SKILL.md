---
name: agents-md-init
description: "Create and update concise AGENTS.md files using proven best practices. Use when starting a new AGENTS.md, refactoring an overly long or confusing one, adding missing build/test commands, or capturing gotchas and verification steps. Triggers on: AGENTS.md, agent instructions, project guide, CLAUDE.md, cursor rules, copilot instructions, agent onboarding."
disable-model-invocation: true
---

# AGENTS.md Best Practices

Create and update AGENTS.md files so they are short, actionable, and focused on agent success. Keep under 100 lines when possible. Include only critical commands and workflows. Capture gotchas and verification steps over time. Emphasize progressive discovery via links to deeper docs.

## References

- [references/vendor-agents-docs/](references/vendor-agents-docs/) — official docs from Anthropic, OpenAI, GitHub Copilot, and OpenCode on agent instruction files

## When to use

- Starting a new AGENTS.md
- Refactoring an overly long or confusing AGENTS.md
- Adding missing build/test commands or workflow steps
- Capturing newly discovered gotchas or verification steps

## Workflow

### Step 1: Investigate the repo

Read the highest-value sources first — prefer executable sources of truth over prose. If docs conflict with config or scripts, trust the executable source.

**Read in this order:**

1. `README*`, root manifests (`package.json`, `pyproject.toml`, etc.), workspace config, lockfiles
2. Build, test, lint, formatter, typecheck, and codegen config
3. CI workflows and pre-commit / task runner config
4. Existing instruction files: `AGENTS.md`, `CLAUDE.md`, `.cursor/rules/`, `.cursorrules`, `.github/copilot-instructions.md`
5. Repo-local agent config (e.g. `opencode.json`)

If architecture is still unclear, inspect a small number of representative code files to find real entrypoints, package boundaries, and execution flow.

### Step 2: Extract high-signal facts

Look for facts that took reading multiple files to infer — things an agent would likely miss. Every line must answer: *"Would an agent likely get this wrong without help?"* If not, leave it out.

**Extract:**

- Exact developer commands, especially non-obvious ones
- How to run a single test, a single package, or a focused verification step
- Required command order when it matters (e.g. `lint -> typecheck -> test`)
- Monorepo or multi-package boundaries, ownership of major directories, real entrypoints
- Framework or toolchain quirks: generated code, migrations, codegen, build artifacts, special env loading
- Repo-specific style or workflow conventions that differ from defaults
- Testing quirks: fixtures, integration test prerequisites, snapshot workflows, required services

Ask questions only if the repo cannot answer something important. Use the `question` tool for at most one short batch.

### Step 3: Draft the short guide

Include only these sections:

- **Docs index** — links to deep dives (at the top)
- **Overview** — one-liner on what the project is, one-liner on stack
- **Build/run commands** — exact commands, no commentary
- **Test commands** — including single-test and focused verification
- **Agent workflow** — plan → implement → verify loop

### Step 4: If AGENTS.md already exists

Improve in place rather than rewriting blindly:

- Preserve verified useful guidance
- Delete fluff or stale claims
- Reconcile with the current codebase
- Don't duplicate content that lives in linked docs

## Gotchas

- **Agents share context with everything else** — every line in AGENTS.md competes with conversation history, system prompt, and other skills. Omit ruthlessly.
- **Don't explain basics** — the agent already knows what a database migration is, how HTTP works, or what tests are. Only include project-specific facts.
- **Commands must be exact** — a wrong flag is worse than no command at all. Verify against config files, not README prose that may be stale.
- **Avoid generic advice** — "follow best practices", "handle errors appropriately", "write clean code" are noise, not signal.
- **Trust executable sources** — `pyproject.toml` over README, CI config over onboarding docs. Prose rots; configs are run.
- **Keep under 100 lines** — if it grows, split detail into linked docs rather than expanding the file.

## Writing rules

- Prefer short sections and bullets over prose
- Simple repo → simple file; large repo → summarize the few structural facts that change how an agent works
- When in doubt, omit
- Every line earns its place
- Use forward slashes in paths, even on Windows
- Consistent terminology throughout (pick one term, stick with it)

## Output template

````markdown
# AGENTS.md — project guide

## Docs index
- [docs/architecture.md](docs/architecture.md) — system design
- [docs/frontend.md](docs/frontend.md) — frontend conventions

## Overview
- One line on what the project is
- One line on the stack

## Build and verify
- `pnpm dev` — start dev server
- `pnpm test` — run all tests

## Workflow
- Update plan or PRD first
- Implement with small diffs
- Run tests; note gotchas
````

## Validation checklist

Before finalizing, verify:

- [ ] File is under 100 lines when feasible
- [ ] Commands are correct and minimal
- [ ] Verification steps are included
- [ ] Progressive discovery links are present
- [ ] No redundant or conflicting guidance
- [ ] Nothing generic or obvious — every line passes the "would an agent miss this?" test
