---
name: agents-md-init
description: Create and update concise AGENTS.md files using proven best practices.
license: MIT
compatibility: opencode
disable-model-invocation: true
---

## Skill: agents-md-init

**Base directory**: .opencode/skill/agents-md-init

## What I do

I create or update AGENTS.md files so they are short, actionable, and focused on agent success:

- Keep content under 100 lines when possible
- Include only critical commands and workflows
- Emphasize progressive discovery via links to deeper docs
- Capture gotchas and verification steps over time

## When to use me

Use this when:

- Starting a new AGENTS.md
- Refactoring an overly long or confusing AGENTS.md
- Adding missing build/test commands or workflow steps
- Capturing newly discovered gotchas or verification steps

## How I work

### Step 1: Investigate the repo

Read the highest-value sources first — prefer executable sources of truth over prose. If docs conflict with config or scripts, trust the executable source and only keep what you can verify.

**Read in this order:**

1. `README*`, root manifests (`package.json`, `pyproject.toml`, etc.), workspace config, lockfiles
2. Build, test, lint, formatter, typecheck, and codegen config
3. CI workflows and pre-commit / task runner config
4. Existing instruction files: `AGENTS.md`, `CLAUDE.md`, `.cursor/rules/`, `.cursorrules`, `.github/copilot-instructions.md`
5. Repo-local agent config (e.g. `opencode.json`)

If architecture is still unclear, inspect a small number of representative code files to find the real entrypoints, package boundaries, and execution flow. Prefer files that explain how the system is wired together over random leaf files.

### Step 2: Extract high-signal facts

Look for the facts that took reading multiple files to infer — the things an agent would likely miss without help. Every line should answer: *"Would an agent likely get this wrong without help?"* If not, leave it out.

**Extract:**

- Exact developer commands, especially non-obvious ones
- How to run a single test, a single package, or a focused verification step
- Required command order when it matters (e.g. `lint -> typecheck -> test`)
- Monorepo or multi-package boundaries, ownership of major directories, real app/library entrypoints
- Framework or toolchain quirks: generated code, migrations, codegen, build artifacts, special env loading, dev servers, infra deploy flow
- Repo-specific style or workflow conventions that differ from defaults
- Testing quirks: fixtures, integration test prerequisites, snapshot workflows, required services, flaky or expensive suites
- Important constraints from existing instruction files worth preserving

**Ask questions only if the repo cannot answer something important** (undocumented team conventions, branch/PR/release expectations, missing setup or test prerequisites). Use the `question` tool for at most one short batch. Do not ask about anything the repo already makes clear.

### Step 3: Draft the short guide

I include only these sections (with the docs index at the top):

- Docs index (deep dives)
- Project overview and structure
- Build/run commands
- Test commands
- Agent workflow (plan -> implement -> verify)

**Include only:**

- Exact commands and shortcuts the agent would otherwise guess wrong
- Architecture notes that are not obvious from filenames
- Conventions that differ from language or framework defaults
- Setup requirements, environment quirks, and operational gotchas
- References to existing instruction sources that matter

**Exclude:**

- Generic software advice
- Long tutorials or exhaustive file trees
- Obvious language conventions
- Speculative claims or anything you could not verify
- Content better stored in another file referenced via config

### Step 4: If AGENTS.md already exists

Improve it in place rather than rewriting blindly:

- Preserve verified useful guidance
- Delete fluff or stale claims
- Reconcile with the current codebase
- Don't duplicate content that lives in linked docs

### Step 5: Capture feedback loops

I ensure the guide:

- Lists verification commands (linters/tests)
- Notes any known gotchas or slow commands
- Encourages updating the guide when surprises occur

## Writing rules

- Prefer short sections and bullets
- If the repo is simple, keep the file simple; if large, summarize the few structural facts that actually change how an agent should work
- When in doubt, omit
- Every line earns its place

## Output format

I produce a concise AGENTS.md with:

- Clear headings
- Short bullet lists
- Minimal examples
- Links to deeper docs

## Example output structure

````markdown
# AGENTS.md - project guide (short)

## Docs index (deep dives)
- [docs/architecture.md](docs/architecture.md)
- [docs/frontend.md](docs/frontend.md)

## Overview
- One line on what the project is
- One line on the stack

## Build and verify
- `pnpm dev`
- `pnpm test`

## Workflow
- Update plan or PRD first
- Implement with small diffs
- Run tests and note any gotchas
````

## Validation checklist

Before finalizing, I ensure:

- [ ] File is under 100 lines when feasible
- [ ] Commands are correct and minimal
- [ ] Verification steps are included
- [ ] Progressive discovery links are present
- [ ] No redundant or conflicting guidance
- [ ] Language matches the project (e.g., German UI notes)
- [ ] Nothing generic or obvious remains — every line passes the "would an agent miss this?" test
