---
version: "1.0.0"
date: 2026-06-09
status: draft
author: skale
purpose: >
  Compile agent skills best practices for agents to use when building
  SKILL.md files. Distilled from the Agent Skills specification,
  official docs, community research, blog posts, and real-world skills.
  Agent-agnostic in scope. Examples reference the pi agent ecosystem
  where illustrative.

**Part of the skaleshare documentation guide.**
- Hub: `documentation-bestpractice.md` (local skaleshare collection) — broad principles, repo structure, Python/Next.js, web docs
- Companion: [`agents-md-best-practices.md`](agents-md-best-practices.md) — AGENTS.md content, anti-patterns, inclusion test, cross-tool compat
---

Agent Skills Best Practices
============================

Compiled: 2026-06-09
Audience: AI coding agents building or maintaining SKILL.md files
Scope: Cross-agent (Codex, Claude Code, Copilot, pi, OpenCode, Cursor, etc.)
Format: Agent Skills open standard (agentskills.io)


1. What Agent Skills Are
-------------------------

Agent Skills are a lightweight, open format for extending AI agent capabilities
with specialized knowledge and workflows. A skill is a directory containing a
SKILL.md file plus optional bundled resources (scripts, references, assets).

The Agent Skills standard was originally developed by Anthropic, released as
an open standard in December 2025, and is stewarded by the Agent Skills
project at agentskills.io. It is supported by Claude Code, OpenAI Codex,
GitHub Copilot (VS Code), OpenClaw, OpenCode, and others.

Key distinction from always-on files (AGENTS.md, CLAUDE.md, etc.):
  - Always-on files: loaded every session, for all tasks. Repo-wide rules,
    build commands, coding conventions.
  - Skills: loaded on demand, only when relevant. Specialized workflows,
    domain knowledge, tool integrations.

Skills are not a new agent capability. They are a context management strategy.
Their value comes from routing and progressive disclosure, not from smarter
prompts.


2. Progressive Disclosure: The Core Architecture
--------------------------------------------------

Skills use a three-level loading system. This is the design principle that
makes skills useful and scalable.

Level 1: Metadata (always loaded, ~100 tokens per skill)
  At startup, the agent reads only the name and description from every
  installed skill's YAML frontmatter. Nothing else. This compact catalog
  goes into the system prompt so the agent knows what skills exist and
  when to use them. You can install many skills without a context
  penalty.

Level 2: Instructions (loaded when triggered, under 5000 tokens recommended)
  When the agent decides a skill is relevant, it reads the full body of
  SKILL.md into context. Only at this point do the actual instructions
  get loaded.

Level 3: Referenced files and scripts (loaded on demand, effectively unlimited)
  If the skill body references other files, the agent reads those only when
  it needs them. Scripts can be executed without being read into context
  at all. The token cost at idle is zero regardless of how much content
  you bundle.

Practical sequence for a real request:
  1. Session starts
     Agent loads: name + description from every skill (~100 tokens each)
  2. User asks a question
     Agent matches against skill descriptions
  3. Skill triggers
     Agent reads: full SKILL.md body (Level 2)
  4. SKILL.md references a file
     Agent reads: references/specific-file.md (Level 3)
  5. SKILL.md includes a script
     Agent executes: scripts/do-thing.py
     (runs without being read into context)


3. Directory Structure
----------------------

Every skill is a directory. The only required file is SKILL.md.

  skill-name/
    SKILL.md              -- Required: metadata + core instructions
    scripts/              -- Optional: executable code (Python, Bash, etc.)
    references/           -- Optional: documentation loaded when needed
    assets/                -- Optional: templates, images, resources

The directory name MUST match the name field in the SKILL.md frontmatter.

Scripts contain executable code for tasks requiring deterministic reliability.
References contain documentation loaded into context when the agent needs
deeper information. Assets contain files used in output but not loaded into
context (templates, images, fonts).

Do NOT create extraneous files:
  - No README.md, CHANGELOG.md, INSTALLATION_GUIDE.md, or similar
  - No redundant logic the agent already handles reliably without help
  - No library code -- scripts should be tiny, single-purpose CLIs


4. SKILL.md Frontmatter (Metadata)
------------------------------------

Required fields:

  name
    1-64 characters. Lowercase letters, numbers, and hyphens only.
    Must not start or end with a hyphen. No consecutive hyphens.
    Must match the parent directory name exactly.

  description
    1-1024 characters. Non-empty.
    Must describe BOTH what the skill does AND when to use it.
    This is the routing key -- the agent uses it to decide whether
    to activate the skill. It is not a human-readable summary.

Optional fields (per spec):

  license             License name or reference to bundled license file
  compatibility        Max 500 chars. Environment requirements (packages,
                       network access, intended product, etc.)
  allowed-tools       Space-separated string of pre-approved tools.
                       Experimental. Support varies between agents.
  metadata            Arbitrary key-value mapping. Use unique key names.

Platform-specific extensions (not in open spec):

  disable-model-invocation
    When true, prevents the agent from invoking the model while
    processing this skill. Used for instruction-only skills.

Description writing formula:
  [What the skill does] + [When to use it] + [Specific trigger phrases]

Good examples:
  name: pdf-processing
  description: "Extract text and tables from PDF files, fill forms,
    merge documents. Use when working with PDF files or when the user
    mentions PDFs, forms, or document extraction."

  name: migrate-review
  description: "Review PostgreSQL schema migrations and rollback safety.
    Use when creating, editing, or validating SQL migrations or
    rollback plans."

  name: web-search
  description: "Search the web with automatic backend selection.
    Works out-of-the-box with public SearXNG. Optional Duck API for
    advanced filters. Supports images, news, videos."

Bad examples:
  description: "Helps with documents."
    -- too vague, triggers on nothing specific

  description: "Creates sophisticated multi-page documentation."
    -- describes what but not when, will misfire or never fire

  description: "React skills."
    -- too vague, overlaps with every React-related task

Key rules for descriptions:
  - Include specific file extensions (.pdf, .xlsx, .json)
  - Mention concrete operations (extract, analyze, generate, rotate)
  - Include common user phrases as triggers
  - Make descriptions mutually exclusive with other installed skills
  - Consider negative triggers ("Don't use for Vue, Svelte, or vanilla CSS")


5. SKILL.md Body (Instructions)
-------------------------------

The body is Markdown with no format restrictions. Only loaded at Level 2
(after the skill triggers).

Size guideline: keep under 500 lines and 5000 tokens. This is the core
"brain" of the skill -- navigation and primary procedures.

Recommended section structure:

  # Skill Name
  One-line summary of what the skill provides.

  ## Quick Start
  Fastest path to a working example. Minimal commands.

  ## [Capability 1]
  Step-by-step instructions for a specific capability.

  ## [Capability 2]
  Another capability with its own steps.

  ## Gotchas
  Non-obvious facts, footguns, edge cases the agent will get wrong
  without being told. Highest signal-to-noise section in many skills.

  ## References
  Links to bundled files: references/foo.md, scripts/bar.py, assets/

Writing rules:
  - Write in imperative/infinitive form ("Extract the text...", not
    "I will extract..." or "You should extract...")
  - Use step-by-step numbering for workflows
  - Map decision trees explicitly ("Step 2: If X, run Y. Otherwise,
    skip to Step 3.")
  - Provide concrete templates over prose descriptions
  - Use identical terminology throughout (pick one term per concept)
  - Use the most specific terminology native to the domain
  - Prefer short sections and bullets over paragraphs
  - Do not state the obvious -- the agent already knows what a PDF is,
    how HTTP works, or what a database migration does


6. Content Philosophy: What to Include vs Omit
----------------------------------------------

The core question for every line: "Would the agent get this wrong without
this instruction?" If no, cut it.

Include (non-inferable, failure-backed):
  - Project-specific conventions the model doesn't know or gets wrong
  - Non-obvious tooling choices (uv not pip, bun not npm)
  - Exact commands with full flags for non-standard operations
  - Gotchas: environment-specific facts that defy reasonable assumptions
  - Counterintuitive patterns that look wrong but are intentional
  - Procedures the agent should follow in a specific order
  - Output format templates
  - Validation steps (how to prove the work is done)
  - Edge cases and error recovery paths

Omit (redundant, inferable, or generic):
  - Explanations of what common tools, formats, or protocols are
  - Generic best practices ("handle errors appropriately")
  - Prose that could be replaced by one code example
  - Anything the agent handles reliably without the skill
  - Detailed content that belongs in references/ (move it there)

The highest-value content in many skills is a gotchas section. These are
not general advice but concrete corrections to mistakes the agent will
make without being told.


7. Progressive Disclosure Patterns
-----------------------------------

When SKILL.md grows beyond 500 lines, split content into separate files.
The key is telling the agent WHEN to load each file, not just that files
exist.

Pattern 1: High-level guide with references
  SKILL.md contains the core workflow and links to detail files.
  Each link includes when to read it.

  ## Advanced features
  - Form filling: See references/forms.md for complete guide
  - API reference: See references/api-reference.md for all methods

Pattern 2: Domain-specific organization
  For skills covering multiple domains or frameworks, organize by domain
  so the agent loads only what's relevant.

  skill-name/
    SKILL.md              -- overview and navigation
    references/
      finance.md          -- loaded only for finance tasks
      sales.md            -- loaded only for sales tasks
      product.md          -- loaded only for product tasks

Pattern 3: Conditional details
  Show basic content inline, link to advanced content with conditions.

  ## Editing documents
  For simple edits, modify the XML directly.
  For tracked changes: See references/redlining.md
  For OOXML details: See references/ooxml.md

Rules for references/ files:
  - Keep one level deep from SKILL.md (no nested subdirectories)
  - Always use relative paths with forward slashes, regardless of OS
  - For files over 100 lines, include a table of contents at the top
  - For large files, include grep search patterns in SKILL.md
  - Avoid duplication between SKILL.md and references
  - Keep individual reference files focused -- smaller files mean less
    context consumption when loaded


8. Skills vs Always-On Files: When to Use Which
-------------------------------------------------

Use always-on files (AGENTS.md) when:
  - Instructions apply to every task in the repo
  - The content is stable, repo-wide rules
  - Examples: build commands, coding conventions, permission boundaries

Use skills when:
  - Instructions apply only to specific task types
  - The content is specialized domain knowledge
  - Loading it for every task would waste context
  - Examples: PDF processing, database migrations, PR review, deployment

The threshold: if your always-on file is under 150-200 lines and covers
everything, you probably don't need skills yet. Skills earn their overhead
when you have enough specialized workflows that putting them all in the
always-on file would bloat it past usefulness.

Practical setup for a project:

  project/
    AGENTS.md                  -- always-on: tooling, shared commands
    .pi/skills/                -- pi agent skills directory
      web-search/              -- skill: loaded when searching the web
        SKILL.md
        references/
      rodney/                  -- skill: loaded for browser automation
        SKILL.md
        references/
    .claude/skills/            -- alternative agent skills directory
    .codex/skills/             -- alternative agent skills directory

Skills locations by agent:
  pi agent:       ~/.pi/agent/skills/<name>/
  Codex CLI:      ~/.codex/skills/<name>/ (user) or .codex/skills/<name>/ (project)
  Claude Code:    ~/.claude/skills/<name>/ (personal) or .claude/skills/<name>/ (project)
  GitHub Copilot: .github/skills/<name>/, .claude/skills/<name>/, or .agents/skills/<name>/
  OpenCode:       ~/.config/opencode/skill/<name>/

When two skills share the same name, the higher-precedence location wins.
Project-level overrides personal.


9. Skill Taxonomy (Four Categories)
------------------------------------

Knowledge skills
  Override the model's defaults. Explain how to correctly use a library,
  API, or internal framework. Reference code snippets, gotchas, and
  "here's how we do it" guidance.
  Risk: low (inform decisions but don't touch production).
  Invocation: can auto-fire safely.

Execution skills
  Orchestrate tools and scripts into a repeatable workflow. Code
  scaffolding, migration generation, deployment pipelines.
  Risk: high (may touch production systems).
  Invocation: should require explicit confirmation for destructive ops.

Verification skills
  Prove correctness. Describe how to test or verify that code actually
  works, often paired with test frameworks or custom harnesses.
  Risk: low.
  Invocation: can auto-fire safely.
  Note: these are often the highest-leverage skills you can build.

Automation skills
  Handle recurring business processes -- standup posts, ticket creation,
  weekly recaps, dependency audits, orphan resource cleanup.
  Risk: medium (may post to external systems or create artifacts).
  Invocation: should require confirmation for external actions.
  Tip: store previous results in log files for cross-run consistency.

Most real workflows combine skills from two or three categories. Keep each
skill focused on one category. Skills that straddle several should probably
be split.


10. Script Bundling Guidelines
------------------------------

Add a script when:
  - The agent reinvents the same logic each run
  - Deterministic reliability is required (variation is a bug)
  - It saves tokens compared to model-generated code
  - It removes ambiguity in output

Script design rules:
  - Self-contained or clearly documented dependencies
  - Helpful, human-readable error messages on stderr/stdout
  - Handle edge cases gracefully
  - Tiny, single-purpose CLIs (not library code)
  - Test by actually running before bundling
  - May be executed without being read into context -- the agent can
    run them directly via bash

Script dependency management:
  - Use credgoo for API keys and credentials (never hardcode)
  - Document expected credential key names in SKILL.md
  - Use uv pip install for Python dependencies
  - Include install.sh / install.bat in the skill directory


11. Instruction Patterns That Work
-----------------------------------

Gotchas section
  List non-obvious facts that the agent will get wrong. Concrete
  corrections, not general advice. Keep in SKILL.md (not references/)
  because the agent may not recognize the trigger condition.

  ## Gotchas
  - The users table uses soft deletes. Queries must include
    WHERE deleted_at IS NULL.
  - The user ID is user_id in the database, uid in the auth service,
    and accountId in the billing API. All three refer to the same value.

Templates for output format
  Agents pattern-match well against concrete structures. Provide a
  template rather than describing the format in prose.
  Short templates can live inline in SKILL.md; longer ones go in assets/.

Checklists for multi-step workflows
  Explicit checklists help the agent track progress and avoid
  skipping steps with dependencies.

  ## Form processing workflow
  - [ ] Step 1: Analyze the form (run scripts/analyze_form.py)
  - [ ] Step 2: Create field mapping (edit fields.json)
  - [ ] Step 3: Validate mapping (run scripts/validate_fields.py)
  - [ ] Step 4: Fill the form (run scripts/fill_form.py)
  - [ ] Step 5: Verify output (run scripts/verify_output.py)

Validation loops
  Instruct the agent to validate its own work before proceeding.
  Pattern: do the work, run a validator, fix issues, repeat until
  validation passes.

Plan-validate-execute
  For batch or destructive operations: create an intermediate plan,
  validate against a source of truth, then execute. The key ingredient
  is a validation script that checks the plan and returns actionable
  error messages the agent can use to self-correct.


12. Calibrating Control and Specificity
----------------------------------------

Match specificity to the fragility of the task.

High freedom (flexible instructions)
  When multiple approaches are valid and the task tolerates variation.
  Explain WHY, not just WHAT -- an agent that understands the purpose
  makes better context-dependent decisions.

Medium freedom (pseudocode or scripts with parameters)
  When a preferred pattern exists but some variation is acceptable.

Low freedom (specific scripts, few parameters)
  When operations are fragile, consistency is critical, or a specific
  sequence must be followed.

  ## Database migration
  Run exactly this sequence:
  python scripts/migrate.py --verify --backup
  Do not modify the command or add additional flags.

Provide defaults, not menus.
  When multiple tools or approaches could work, pick a default and
  mention alternatives briefly. Don't present equal options.

Favor procedures over declarations.
  Teach the agent HOW to approach a class of problems, not WHAT to
  produce for a specific instance. The approach should generalize even
  when individual details are specific.


13. Multi-Skill Composition
---------------------------

When multiple skills should activate for a single task, be aware of:

Routing competition
  Every skill's description competes in the same system prompt space.
  Overlap in descriptions creates ambiguity. Make descriptions
  mutually exclusive: one skill reviews migrations, another reviews
  API contracts, a third enforces style standards.

Ordering uncertainty
  When multiple skills should activate, the model decides the sequence.
  You can influence this by making dependencies explicit in the
  workflow section ("Before running this skill, check whether the
  schema-conventions skill applies to the changed files").

Non-deterministic composition
  Two runs of the same prompt can trigger different skill combinations.
  At scale, you are shaping probabilities, not designing a deterministic
  system.

Recommendation: keep active skill count low. Use role-based bundles
when you need more. More skills is not always more capability.


14. Skill Creation Process
-------------------------

Step 1: Start with a real task
  Complete a real task with the agent, providing context and corrections.
  Pay attention to steps that worked, corrections you made, input/output
  formats, and context you provided.

Step 2: Extract the reusable pattern
  Identify what scripts, references, and assets would help when
  executing similar workflows repeatedly. Analyze each example to
  create a list of reusable resources.

Step 3: Initialize the skill structure
  Create the directory with SKILL.md and resource subdirectories.
  Remove any example files not needed for the skill.

Step 4: Write the SKILL.md
  Frontmatter: name and description optimized for discoverability.
  Body: core instructions, workflows, gotchas.
  References: link to detail files with explicit load conditions.

Step 5: Add scripts only when they earn it
  A script earns its place when it replaces fragile model-generated
  code with reliable execution, saves tokens, or removes ambiguity.

Step 6: Validate
  Run the skill against real tasks. Test scripts by actually running them.
  Check that the skill triggers when it should and stays quiet when
  it shouldn't.

Step 7: Iterate from real usage
  Use the skill on real tasks. Notice struggles or inefficiencies.
  Identify how SKILL.md or bundled resources should be updated.
  Every time the agent gets something wrong while using the skill,
  add it to the gotchas list. This is the part that compounds.

Alternative approach: extract from session transcripts
  Use a session extraction tool (e.g. scripts/extract-session.js) to
  pull the conversation history from a completed agent session.
  Analyze the transcript for confusion patterns, missing examples,
  workarounds, errors, and successful patterns. Convert findings
  into skill content.


15. Evaluation and Maintenance
--------------------------------

Before/after measurement
  A skill is successful if it increases success rate, reduces retries,
  reduces manual correction, or cuts time-to-completion compared to the
  baseline (agent without the skill). A skill that produces correct
  output but takes three times as long because it loaded too much context
  is still a bad skill.

Trigger testing
  Test separately from output quality: does the skill fire when it
  should, stay quiet when it shouldn't, and handle ambiguous prompts?
  A skill that produces beautiful output but triggers on the wrong
  requests is broken in a way that output metrics will never catch.

Observability
  Log skill invocations. Track which skills activate, how often, and
  whether the user overrides or corrects the result. A spike in user
  corrections is often the first sign a skill is misfiring.

Regular pruning
  Review skills quarterly. Remove instructions for deprecated tools,
  outdated patterns, or things the underlying model has gotten better at.
  Models improve over time -- instructions essential six months ago may
  now be pure overhead.


16. Security Considerations
---------------------------

Skills are a real attack surface. A malicious skill can execute with the
same permissions as your agent -- hidden instructions, embedded prompt
injection, or scripts that run with full shell access.

Guidelines:
  - Install skills only from trusted sources
  - Audit third-party skills before use: read all files, especially
    scripts and references
  - Pay attention to instructions that connect to external network sources
  - Don't give skills more access than they need
  - Avoid XML angle brackets (< >) in frontmatter as they can inject
    unintended instructions into the system prompt
  - Never hardcode credentials in scripts or config files


17. Common Failure Modes
-------------------------

Routing ambiguity (most common)
  The wrong skill gets selected because descriptions overlap, are too
  vague, or compete with other skills for the same trigger phrases.
  The output looks plausible -- it's just answering the wrong question.

Context overload
  Too many skills are active, or the skill itself is too long, or
  the always-on layer is bloated. The agent's outputs degrade because
  too much material competes for attention.

Hidden dependencies
  The skill assumes packages are installed, services are running, or
  credentials are configured -- and none of that is declared or checked.
  Self-contained scripts with explicit dependencies and helpful errors
  are the difference between a skill that works on your machine and one
  that works everywhere.

Missing verification
  The skill tells the agent what to do but not how to prove it worked.
  The agent finishes and says "done" but the output is wrong. A skill
  without verification occasionally works and silently fails.


18. Distribution & Installation
---------------------------------

How a finished skill reaches users. The SKILL.md format is portable (any agent that reads
it), but the delivery mechanism is agent-specific.


The single-source principle
  One resource, one identity. Pi deduplicates packages by identity:

    - npm         -> package name
    - git         -> repository URL without ref
    - local path  -> resolved absolute path

  A git package and a local-path entry for the same skill are DIFFERENT identities, so pi
  loads both -> "[Skill conflicts]" at startup, even if the files are byte-identical.
  Identity, not content, decides dedup. This bites on three vectors:

    1. settings.json: a `packages` git entry AND a `skills`/`extensions` local-path
       entry for the same resource.
    2. Loose skill symlinks/dirs in ~/.pi/agent/skills/ that duplicate a package skill.
    3. Loose .ts files in ~/.pi/agent/extensions/ that duplicate a package extension.

  Fix: pick ONE source (the package is canonical) and delete the others. Do not "fix" a
  conflict by making the loose file byte-identical -- that does not change its identity.


Selective loading (do not load every skill)
  A package that bundles many skills loads all of them by default. Each loaded skill adds
  its name+description to the always-on system prompt catalog (Level 1 progressive
  disclosure). Loading a large collection causes context rot and routing competition --
  Microsoft's agent-skills repo (130+ skills) explicitly recommends installing only 4-8.

  Pi's object-form package entry filters what loads:

    {
      "packages": [{
        "source": "git:github.com/devskale/skale-skills",
        "skills": ["d2", "rodney", "fetch-url", "web-search"]
      }]
    }

  Omit a key to load all of that type; [] loads none; !pattern excludes; +path/-path are
  exact-path force include/exclude. Toggle interactively with `pi config`.


Four canonical delivery methods (cross-agent)
  Research across the ecosystem (Microsoft, Anthropic, openskills, community guides)
  converges on four methods:

    1. Package manager / marketplace -- the primary path.
         Anthropic: /plugin marketplace add + /plugin install
         Pi:        pi install git:<url>  or  npm:<pkg>
         Microsoft: npx skills add
    2. Manual copy -- git clone + cp -r the skill dir into the agent's skills folder.
       Precise control, but unversioned and drifts from upstream.
    3. Symlinks (ln -s) -- share one checkout across multiple agents/projects. Good for
       multi-agent setups, but each symlink is a separate identity that can collide with a
       package install (see single-source principle above).
    4. Local dev path -- point settings at a working tree for live editing. Scope it to
       the project (project-path package), never global, to avoid co-loading with the
       global package.

  Prefer method 1. Methods 2-4 are valid for specific cases (offline, multi-agent sharing,
  active development) but each creates a separate identity that must be reconciled with any
  package install.


Cross-agent install (non-pi agents)
  openskills (`npm i -g openskills`) installs any GitHub skill into Claude Code, Cursor,
  Windsurf, Aider, OpenCode, etc. It clones, validates frontmatter, and copies:

    openskills install <owner>/<repo>                   # all skills in the repo
    openskills install <owner>/<repo>/<skill-subpath>   # one skill by path

  Useful when a skill should work across harnesses, not just pi. The subpath form
  resolves a single skill from a multi-skill repo (name = basename of the subpath).


Skill-directory layout for distribution
  Ship the skill as a self-contained directory rooted at SKILL.md:

    skill-name/
      SKILL.md          # metadata + instructions (the only required file)
      scripts/          # executable helpers (if any)
      references/       # on-demand detail
      assets/           # templates, fixtures

  Knowledge skills (no executable code) need only SKILL.md + optional references/. Do NOT
  add install.sh, pyproject.toml, or a launcher unless the skill bundles a CLI -- a
  knowledge skill is consumed by the agent reading it, not installed as a tool.


19. Developing & Iterating (the dev loop)
------------------------------------------

How to edit a skill or extension against a live agent session without leaving conflicts
behind. This section is pi-specific in mechanism (the identity and precedence rules below
were verified by reading pi's package-manager source), but the workflow generalizes: edit
in a working tree, try it against one session, land it upstream, then stop overriding.


The precedence ladder (why "the dev version wins" works)
  When two resources claim the same name, pi resolves the collision by a fixed precedence.
  Lower rank = loaded first = wins; the loser is skipped with a diagnostic. The ladder,
  from the source:

    0  project + settings entry   (source: "local", scope: "project")
    1  project + auto-discovered  (source: "auto",  scope: "project")
    2  user + settings entry      (source: "local", scope: "user")
    3  user + auto-discovered     (source: "auto",  scope: "user")
    4  package resource           (origin: "package")

  Key consequence: ANY non-package (local) resource beats ANY package resource. So a
  working-tree override always shadows the installed package during a session. That is the
  mechanism that makes live dev possible -- and the mechanism that causes "[conflicts]"
  warnings when the override is left in place after dev ends.


The identity rule (why two copies of the same thing both load)
  Pi deduplicates packages by IDENTITY, and identity is type-dependent:

    npm    -> "npm:<name>"                 (scope-independent)
    git    -> "git:<host>/<path>"           (scope-independent)
    local  -> "local:<resolved-absolute-path>" (scope affects resolution)

  Same identity in both global and project scope -> project wins, the other is dropped,
  NO conflict. DIFFERENT identities -> both load -> conflict warning, resolved by the
  precedence ladder above. A git URL and a local checkout path are ALWAYS different
  identities, even when they contain identical bytes. This is the single biggest gotcha:

    # These collide (git identity != local identity):
    #   global: { packages: [{ source: "git:github.com/me/repo" }] }
    #   project: { packages: ["~/code/repo"] }   <- local path

    # These do NOT collide (same git identity, project wins):
    #   global:   { packages: ["git:github.com/me/repo"] }
    #   project:  { packages: ["git:github.com/me/repo"] }
    #   BUT pi resolves a project git entry to a CLONE under .pi/git/, not your working
    #   tree -- so this is useless for live-editing tracked files.


Two dev setups (use the first)

  A. Session-only override (PREFERRED -- zero persistent state)
     Load the working tree for ONE run via a CLI flag. Nothing is written to settings, so
     there is no leftover to clean up and no conflict on any other project. The flag depends
     on what you are dev'ing, because SKILLS AND EXTENSIONS COLLIDE DIFFERENTLY:

       cd ~/code/skale-skills

       # Skill dev -- soft collision (first wins, loser skipped, warning only):
       pi --skill skills/d2/SKILL.md          # load one skill for this run (additive)

       # Extension dev -- HARD collision: same tool name = load ERROR, not a warning.
       # Suppress the package's extensions first, then load yours:
       pi -ne -e ./extensions/statusline.ts   # -ne = no package exts; -e = load this one

     Why the split: skills collide on NAME (soft -- loser skipped with a diagnostic, winner
     serves); extensions collide on TOOL/COMMAND name (hard -- pi refuses to load the second
     and errors out). So "pi -e ." on a whole package that ships extensions fails against an
     installed copy of the same package; -ne fixes the extension path by silencing the
     package's extensions for that run. The temporary resource beats the package on name
     collision (scope "temporary", rank ~2-3 vs package rank 4).

     "Additive" means packages from settings STILL load; the temporary path just joins
     them and wins on name collision. To load ONLY your override and silence everything
     else, combine with --no-skills (explicit --skill still loads):

       pi --no-skills --skill skills/d2/SKILL.md

     This is the right tool for: iterating on a skill/extension you are about to ship.
     Restart and it is gone.

  B. Project-path package (persistent, for long-running dev on a repo)
     Point a PROJECT setting at the working tree so every session inside that repo loads
     it live:

       # ~/code/skale-skills/.pi/settings.json   (project-scoped, gitignored)
       { "packages": ["."] }

     CAVEAT verified from source: a local-path project package has a DIFFERENT identity
     than the global git package, so both load -> you WILL see "[conflicts]" / "Tool
     conflicts" warnings at startup. Functionally fine: the project-local entry (rank 0)
     wins, so your working-tree version is served and the package copy is skipped. The
     warnings are noise, not breakage. Remove the file when dev is done (see loop below).

     Never put a working-tree path in GLOBAL settings while the git package is also
     installed -- that collides on EVERY project, not just the one you are developing.


The loop (edit -> try -> land -> stop overriding)

  1. EDIT in the working tree.
  2. TRY against one session -- setup A (pi --skill / pi -ne -e) for iteration, B for a long
     session in the repo.
  3. LAND upstream: commit + push from the working tree. For git/npm packages this is what
     makes the fix real -- until it ships, the override is the ONLY thing carrying it.
  4. SYNC the installed package to the new tip:
       pi update --extension git:github.com/<org>/<repo>
  5. STOP overriding: remove the session flag (A: nothing to do; just restart) or the
     project settings file (B: rm the .pi/settings.json). Now the package is the sole
     source and the conflict warnings clear.

  The critical catch (do not get this backwards): never do step 5 before steps 3 and 4.
  If the override carries a fix the package does not yet have, removing it early silently
  regresses the agent back to the old package version.


Skill vs extension dev specifics

  Skill (markdown): no build step. Edit SKILL.md, then `pi --skill path/to/SKILL.md` to
  load it. The agent reads it on demand; changes apply the next time the skill is invoked
  in that session (or restart to be safe). Verify routing: does it fire on the right
  prompts and stay quiet on the wrong ones?

  Extension (.ts/.js): pi loads the file fresh each session start -- restart pi to pick up
  edits (no hot reload). Use `pi -ne -e path/to/ext.ts` for a one-shot test (the -ne suppresses
  package extensions so yours is the only one registering its tools; without -ne a same-named
  package extension causes a hard Tool conflict). Extensions can
  register tools, commands, and UI hooks; test each surface you added.

  Knowledge skill vs CLI skill: a knowledge skill (no scripts) needs only SKILL.md +
  optional references/ -- do not add install.sh/pyproject.toml/launcher. A CLI skill
  bundles a launcher; its install.sh symlinks the launcher into ~/.local/bin (that is a
  PATH convenience for the command, separate from pi's skill-loading).


Sanity checks after cleanup

  pi list                               # only declared packages; no stray entries
  ls ~/.pi/agent/skills/                # empty if a package provides skills
  ls ~/.pi/agent/extensions/            # only files NOT provided by a package
  pi -p "ok" 2>&1 | grep -i conflict    # empty = clean startup


20. References
--------------

[REF-01]  Agent Skills Specification
  https://agentskills.io/specification
  Official format specification. Directory structure, SKILL.md format,
  frontmatter fields, progressive disclosure levels, file references,
  validation tooling.

[REF-02]  Agent Skills Overview
  https://agentskills.io/home
  What skills are, why they exist, how they work, progressive disclosure
  explanation, ecosystem overview.

[REF-03]  Best Practices for Skill Creators
  https://agentskills.io/skill-creation/best-practices
  Start from real expertise, refine with real execution, spending
  context wisely, calibrating control, gotchas sections, templates,
  checklists, validation loops, plan-validate-execute, bundling scripts.

[REF-04]  Anthropic Engineering -- Equipping Agents for the Real World
  https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills
  Original skills announcement. Three-level progressive disclosure.
  Skills and the context window. Code execution. Development and
  evaluation guidelines. Security considerations.

[REF-05]  Steve Kinney -- Agent Skills, Stripped of Hype
  https://stevekinney.com/writing/agent-skills
  Skills as context management strategy, not new capability.
  Always-on vs on-demand distinction. Skill taxonomy (knowledge,
  execution, verification, automation). Routing competition in
  multi-skill composition. Four root causes of skill failure.
  Practical template.

[REF-06]  Bibek Poudel -- The SKILL.md Pattern
  https://bibek-poudel.medium.com/the-skill-md-pattern-how-to-write-ai-agent-skills-that-actually-work-72a3169dd7ee
  Three-level loading system explained. Description as routing key.
  Skills vs slash commands. Where skills live per platform.
  Common mistakes. Four worked examples (README writer, git commit
  generator, code reviewer, sprint planner).

[REF-07]  Nicolas Frankel -- Writing an Agent Skill
  https://blog.frankel.ch/writing-agent-skill/
  DRY principle for agent context. Token economics. Skills vs AGENTS.md.
  Kotlin skill example with frontmatter, content structure, and
  reference file approach.

[REF-08]  mgechev/skills-best-practices (GitHub)
  https://github.com/mgechev/skills-best-practices
  Validate skills using LLMs, maintain lean context window.
  Frontmatter optimization, progressive disclosure, flat subdirectories,
  procedural instructions, script bundling, trigger testing.

[REF-09]  Ardalis -- Optimizing AI Agents with Progressive Disclosure
  https://ardalis.com/optimizing-ai-agents-with-progressive-disclosure/
  Progressive disclosure as a system design pattern. Context window
  limits. Anti-patterns: monolithic files, giant descriptions.
  Signal-to-noise ratio of agent context.

[REF-10]  MindStudio -- What Is Progressive Disclosure in AI Agent Design?
  https://www.mindstudio.ai/blog/progressive-disclosure-ai-agent-skill-design
  Loading context only as needed. Skills as progressive disclosure
  mechanism. Token efficiency in skill design.

[REF-11]  Swirl AI -- Agent Skills: Progressive Disclosure as a System
  https://www.newsletter.swirlai.com/p/agent-skills-progressive-disclosure
  Progressive disclosure in research agents. System design pattern framing.

[REF-12]  LinkedIn -- Cole Medin -- Implementing Skills with Progressive
           Disclosure
  https://www.linkedin.com/posts/cole-medin-727752184_skills-are-one-of-the-most-important-advances-activity-7422443396411191296-jFrS
  On-demand context retrieval. Skills as context engineering pattern.

[REF-13]  Arize AI -- Prompt Learning for Claude.md Optimization
  https://arize.com/blog/claude-md-best-practices-learned-from-optimizing-claude-code-with-prompt-learning/
  Automated optimization of context files. +5.19% accuracy cross-repo,
  +10.87% in-repo. Gap between what humans think agents need and
  what actually helps. Applicable to skills as well as AGENTS.md.

[REF-14]  Termdock -- Agent Skills Guide 2026
  https://www.termdock.com/en/blog/agent-skills-guide
  SKILL.md format, 490K+ skill ecosystem, security risks, best practices.

[REF-15]  VoltAgent/awesome-agent-skills (GitHub)
  https://github.com/VoltAgent/awesome-agent-skills
  Curated collection of 1000+ agent skills from official dev teams
  and the community. Cross-agent compatible.

[REF-16]  Pi agent -- agent-skill-creator skill
  /Users/johannwaldherr/code/agents/skills/skale-skills/skills/agent-skill-creator/SKILL.md
  Real-world example: universal skill creator for pi agent. Covers
  creation process, progressive disclosure patterns, credential
  management, packaging, validation.

[REF-17]  Pi agent -- improve-skill skill
  /Users/johannwaldherr/code/agents/skills/skale-skills/skills/improve-skill/SKILL.md
  Real-world example: session transcript analysis for skill improvement.
  Extract-improve workflow. Multi-agent support (Claude Code, pi,
  Codex, OpenCode).

[REF-18]  Pi agent -- agents-md-init skill
  /Users/johannwaldherr/code/agents/skills/skale-skills/skills/agents-md-init/SKILL.md
  Real-world example: AGENTS.md creation skill with investigation
  workflow, extraction patterns, gotchas, validation checklist.

[REF-19]  Pi agent -- rodney skill
  /Users/johannwaldherr/code/agents/skills/skale-skills/skills/rodney/SKILL.md
  Real-world example: browser automation skill. Demonstrates CLI tool
  pattern, references/ directory, gotchas section, command reference
  split across multiple files.

[REF-20]  VS Code -- Use Agent Skills in VS Code
  https://code.visualstudio.com/docs/copilot/customization/agent-skills
  Project-specific coding standards. Language/framework conventions.
  Code review guidelines. Rule scoping by file pattern.

[REF-21]  Microsoft -- agent-skills (GitHub)
  https://github.com/microsoft/agent-skills
  130+ skills, 1169 test scenarios. Four install methods (CLI wizard, plugin
  marketplace, manual copy, symlinks). "Install only 4-8 skills" guidance
  (context rot). Sensei-style frontmatter scoring. Ralph Loop iterative
  improvement. Canonical source for distribution taxonomy in section 18.

[REF-22]  numman-ali -- openskills (npm / GitHub)
  https://github.com/numman-ali/openskills
  Universal skills loader for any AI coding agent (Claude Code, Cursor,
  Windsurf, Aider, OpenCode). Clones a GitHub repo, validates SKILL.md
  frontmatter, copies into the agent's skills dir. owner/repo/<subpath>
  form resolves a single skill from a multi-skill repo. Cross-agent install
  method in section 18.
