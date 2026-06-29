---
version: "1.0.0"
date: 2026-06-09
status: draft
author: skale
purpose: >
  Compile AGENTS.md best practices for agents to use when building
  AGENTS.md files. Distilled from research, blog posts, official docs,
  and community experience. Designed as a reference, not a template.
---

**Part of the skaleshare documentation guide.**
- Hub: `documentation-bestpractice.md` (local skaleshare collection) — broad principles, repo structure, Python/Next.js, web docs
- Companion: [`agent-skills-best-practices.md`](agent-skills-best-practices.md) — SKILL.md format, progressive disclosure, skill taxonomy

AGENTS.md Best Practices
========================

Compiled: 2026-06-09
Audience: AI coding agents building or maintaining AGENTS.md files
Scope: Cross-tool (Codex, Cursor, Claude Code, Copilot, Windsurf, Amp, Devin, etc.)


1. What AGENTS.md Is (and Is Not)
----------------------------------

AGENTS.md is a Markdown file placed at the root of a repository that provides
AI coding agents with persistent, project-specific operational guidance.
It complements README.md (which targets humans) and contains the technical
instructions agents need to work effectively: build commands, test runners,
conventions, constraints, and landmines.

Stewarded by the Agentic AI Foundation under the Linux Foundation (since Dec 2025).
Adopted by 60k+ open-source projects. Native support in Codex CLI, Cursor,
GitHub Copilot, Windsurf, Amp, Devin, Jules, Factory, Aider, and others.
Claude Code reads it as fallback when no CLAUDE.md exists.


2. The Research: What Actually Works
-------------------------------------

2.1 ETH Zurich Study (AGENTbench, Feb 2026)
  Gloaguen et al., SRI Lab, ETH Zurich. arXiv:2602.11988.
  Tested 4 agents (Claude 3.5 Sonnet, GPT-5.2, GPT-5.1 mini, Qwen Code)
  across SWE-bench and custom benchmark.

  Findings:
  - LLM-generated context files reduced task success by 0.5-3% while
    increasing inference costs by 20-23%.
  - Human-written context files improved success by ~4% but increased
    costs by up to 19%.
  - When repos were stripped of all docs first, LLM-generated files
    improved performance by 2.7% -- proving the problem is redundancy,
    not uselessness.
  - Navigation/architecture sections had no measurable effect on agent
    file discovery time.
  - Non-standard tooling mentions (e.g. "use uv not pip") caused
    160x more correct tool usage (1.6 vs 0.01 invocations/task).

2.2 Lulla et al. (ICSE JAWs, 2026)
  124 real GitHub PRs, paired with/without AGENTS.md.
  - Human-authored AGENTS.md reduced median runtime by 28.64% and
    output token consumption by 16.58%.

2.3 Key Insight
  The question is not whether to have AGENTS.md, but what earns a line.
  Both studies agree: non-discoverable, non-obvious information is the
  only content that reliably improves agent performance.


3. The Inclusion Test: What Belongs
-----------------------------------

Before adding any line, ask: can the agent discover this by reading the code,
README, or existing docs? If yes, omit it.

INCLUDE (non-inferable, failure-backed):
  - Non-standard tooling choices (uv not pip, bun not npm, just not make,
    pixi instead of pip)
  - Exact build/test commands with full flags, especially non-standard scripts
    or unusual paths
  - File-scoped commands (run a single test, lint one file) -- highest ROI
    for iteration speed
  - Stack definition with exact versions
  - Custom deployment/release steps not discoverable from CI configs
  - Team decisions encoded nowhere in code (naming conventions, file naming
    patterns, commit message format)
  - Known footguns and landmines ("do not run migrations in dev",
    "the legacy/ directory is imported by three production modules")
  - "Don't touch" zones and permission boundaries
  - Counterintuitive patterns that look wrong but are intentional
  - Non-obvious error handling patterns (e.g. "our API client never throws;
    check .ok field instead of try/catch")

OMIT (redundant, inferable, or generic):
  - Architectural overviews (agent reads the code)
  - Folder structure explanations (visible from ls/tree)
  - Framework conventions (baked into model training)
  - Generic best practices ("write clean code", "follow SOLID")
  - Anything already in README.md or existing documentation
  - Auto-generated /init output without thorough human review
  - Full test suite for every commit (use conditional phrasing instead)


4. File Hierarchy and Scoping
------------------------------

4.1 Single file (under 150-200 lines)
  Start here. Sufficient for most projects.

4.2 Nested files (monorepos, complex projects)
  Place additional AGENTS.md in subdirectories. The nearest file to the
  edited file takes precedence. Agents walk from root to leaf, concatenating
  with later files overriding earlier ones.

  Example structure:
    project/
      AGENTS.md            -- global: tooling, shared commands
      src/
        AGENTS.md          -- backend: Python conventions, DB rules
        frontend/
          AGENTS.md        -- frontend only: TypeScript, component patterns
      scripts/
        AGENTS.md          -- DevOps only: deploy flags, env notes

4.3 Override files (Codex CLI)
  AGENTS.override.md -- gitignored, personal overrides that take precedence
  over AGENTS.md in the same directory. For local-only tweaks without
  committing.

4.4 Tool-specific files
  For multi-tool teams, use AGENTS.md as the canonical source and symlink
  for tool-specific files:
    ln -s AGENTS.md CLAUDE.md
    ln -s AGENTS.md .github/copilot-instructions.md
  Only create tool-specific files when you need features AGENTS.md cannot
  provide (Cursor's glob scoping, Copilot's path-specific .instructions.md).

4.5 Global defaults
  ~/.pi/agent/AGENTS.md        -- pi agent global defaults
  ~/.codex/AGENTS.md        -- Codex CLI global defaults
  ~/.claude/CLAUDE.md       -- Claude Code global defaults
  ~/.gemini/GEMINI.md       -- Gemini CLI global defaults


5. Recommended Sections (in priority order)
--------------------------------------------

5.1 Stack / Environment Setup
  Exact versions, non-standard tools, install commands.
  Example: "Python 3.12+, uv for package management, not pip."

5.2 Commands (build, test, lint)
  Most referenced section. Place early. Include file-scoped commands.
  Example: "uv run pytest tests/test_handlers.py" (single file)
           "uv run ruff check src/handlers.py" (single file lint)

5.3 Code Style / Conventions
  One concrete code snippet beats three paragraphs of description.
  Focus on counterintuitive choices.

5.4 Testing Rules
  Framework, location, how to run different test types, coverage
  expectations. Include exact commands in code blocks.

5.5 Don't Touch Zones / Permission Boundaries
  Three-tier system:
    - Allowed without prompting: read files, lint, type-check, unit tests
    - Require approval: package installs, git push/commit, file deletion,
      full build/E2E, infra changes
    - Never: secrets in code, modifying vendor/, deploying to prod

5.6 Known Footguns / Non-Obvious Patterns
  The section with the highest signal-to-noise ratio. Include only
  things that caused real failures.

5.7 PR / Commit Guidelines (if relevant to the agent's workflow)
  Title format, required checks, branching conventions.


6. Anti-Patterns and Pitfalls
-----------------------------

6.1 The Obedience Trap
  Agents are too obedient. Every instruction is followed, even irrelevant
  ones. "Run full test suite before each commit" is executed on
  documentation changes. Each line is a commitment to extra agent steps.

6.2 The Anchoring Effect
  If you mention a legacy technology (e.g. tRPC) in an overview, the model
  holds it in context for every prompt -- even when working on unrelated
  code. Mentioning obsolete patterns can bias the agent toward the
  wrong approach.

6.3 Silent Truncation
  Codex CLI silently truncates combined context at 32 KiB (configurable).
  No warning, no log. Instructions you care about most (typically at the
  end) are the first to be dropped. Monitor file size:
    find . -name "AGENTS.md" | xargs wc -c | tail -1

6.4 Stale Structural References
  Documentation rot. A section describing "the auth module uses Express
  middleware" is actively misleading after a migration to FastAPI.
  AGENTS.md describing a structure that no longer exists is worse than
  no AGENTS.md.

6.5 Config File Proliferation
  AGENTS.md + CLAUDE.md + .cursorrules + copilot-instructions.md + GEMINI.md
  -- each starts as a copy, drifts independently, contains contradictions.
  Consolidate to AGENTS.md and symlink.

6.6 Lost in the Middle
  Long context files suffer from degraded recall of information in the
  middle. Critical rules should appear early. Keep files short.

6.7 The Static File Problem
  A flat instruction set cannot condition on task type. An agent doing
  a CSS refactor does not need database migration warnings. Use conditional
  phrasing ("when modifying API endpoints, ...") or move to skills/systems
  that support progressive disclosure.


7. Size and Modularity Guidelines
----------------------------------

  - Keep root AGENTS.md under 150 lines when possible.
  - Hard cap: monitor combined byte size across all AGENTS.md files.
    Most agents silently truncate context at 30-50 KiB. Codex CLI: 32 KiB
    (configurable). Other tools have similar undocumented limits.
    Monitor: find . -name "AGENTS.md" | xargs wc -c | tail -1
  - When exceeding 150-200 lines, split into nested subdirectory files.
  - Move specialized workflows to SKILL.md or tool-specific rule files
    that support progressive disclosure (loaded on demand, not always-on).
  - Each line costs inference tokens. More lines = more steps = more cost.


8. Progressive Disclosure: Skills and Routing
---------------------------------------------

For large projects, consider a layered approach:

  Layer 1: Root AGENTS.md
    Minimum essential repo facts, tooling, non-obvious commands.
    Acts as a routing document rather than a comprehensive guide.

  Layer 2: SKILL.md files (or equivalent)
    Specialized instructions loaded by the agent only when relevant
    (triggered by keyword matching or explicit invocation).
    Examples: database migration patterns, Playwright automation,
    Docker deployment steps. See skills-bestpractices.md for details.

  Layer 3: Nested AGENTS.md
    Directory-scoped rules for submodules/monorepo packages.

This keeps baseline context lean while preserving access to specialized
knowledge on demand.


9. Maintenance and Lifecycle
-----------------------------

  - Treat AGENTS.md as a living list of codebase smells you haven't
    fixed yet, not permanent configuration.
  - Version-control changes and review them like code.
  - When an agent repeatedly fails at something, treat it as a codebase
    problem first (restructure, add linter, improve tests) before
    adding an AGENTS.md line.
  - Add a line, investigate the root cause, fix the underlying issue,
    then consider removing the line.
  - Start with an nearly-empty AGENTS.md. Add instructions only in
    response to observed failures.
  - Review and prune quarterly. Remove instructions for deprecated
    tools, outdated patterns, or things the codebase now makes obvious.
  - For teams running agents at scale in CI/CD, the 15-20% cost overhead
    compounds. Calculate before assuming the tradeoff is worth it.


10. Template (minimal, for reference)
--------------------------------------

# AGENTS.md -- Project Name

## Tooling
  - [package manager] for dependencies, not [default]
  - [runtime version]+

## Commands
  - Install: [exact command]
  - Test single file: [exact command with placeholder]
  - Test full: [exact command]
  - Lint: [exact command]
  - Build: [exact command]

## Conventions
  - [counterintuitive pattern with one-line explanation or code snippet]

## Boundaries
  - Never modify: [paths/patterns]
  - Always run before commit: [conditional command]

## Known Issues
  - [footgun with mitigation]

(Sections should only appear if they contain non-empty, non-redundant content.)


11. Cross-Tool Compatibility Reference
----------------------------------------

Tool                  Primary File            Also Reads           Override/Gitignored
---------------------  ----------------------  ------------------  -------------------
Codex CLI             AGENTS.md               AGENTS.override.md  Yes
Cursor                AGENTS.md               .cursor/rules/*.mdc  N/A (scoped)
Claude Code           CLAUDE.md               AGENTS.md (fallback) N/A (via .claude/)
GitHub Copilot        AGENTS.md               .github/copilot-     N/A
                                              instructions.md
Windsurf              AGENTS.md               .windsurf/rules/*.md N/A
Amp (Sourcegraph)     AGENTS.md               CLAUDE.md (fallback) N/A
Devin                 AGENTS.md               --                   N/A
Gemini CLI            GEMINI.md               AGENTS.md (config)   N/A


12. References
--------------

[REF-01]  AGENTS.md official site
  https://agents.md/
  The canonical specification. Stewarded by Agentic AI Foundation / Linux
  Foundation. File naming, location, hierarchy, FAQ.

[REF-02]  OpenAI Codex -- Custom instructions with AGENTS.md
  https://developers.openai.com/codex/guides/agents-md
  Discovery order, precedence, override files, config.toml settings,
  project_doc_max_bytes, fallback filenames.

[REF-03]  ETH Zurich -- Evaluating AGENTS.md (AGENTbench)
  Gloaguen et al., arXiv:2602.11988, Feb 2026
  https://arxiv.org/abs/2602.11988
  Empirical evaluation of context file effectiveness. 138 Python tasks.
  Key finding: LLM-generated files hurt, human-written files help modestly.
  Non-standard tooling mentions produce 160x correct usage.

[REF-04]  Daniel Vaughan -- The AGENTS.md Bloat Problem
  https://codex.danielvaughan.com/2026/03/27/agents-md-bloat-problem/
  Silent truncation at 32 KiB. The obedience trap. What actually belongs
  vs what doesn't. Nested file strategy. Skills as progressive disclosure.
  Decision flowchart for inclusion.

[REF-05]  Addy Osmani -- Stop Using /init for AGENTS.md
  https://medium.com/@addyosmani/stop-using-init-for-agents-md-3086a333f380
  The anchoring effect. Static vs dynamic context. Treat AGENTS.md as
  "living list of codebase smells you haven't fixed yet."
  Lulla et al. (ICSE JAWs 2026) runtime/token reduction findings.

[REF-06]  Augment Code -- How to Build Your AGENTS.md
  https://www.augmentcode.com/guides/how-to-build-agents-md
  Section-by-section breakdown with real repo examples. Modular rules
  decision matrix. Cost overhead calculations. Cross-tool comparison table.

[REF-07]  0xfauzi -- AGENTS.md Best Practices (GitHub Gist)
  https://gist.github.com/0xfauzi/7c8f65572930a21efa62623557d83f6e
  Comprehensive guide with section templates, tool parsing details,
  context window management, search/retrieval methods.

[REF-08]  DeployHQ -- CLAUDE.md, AGENTS.md, Copilot Instructions Guide
  https://www.deployhq.com/blog/ai-coding-config-files-guide
  Complete landscape of all config file formats. Discovery processes
  for each tool. Decision framework: when to use what.

[REF-09]  Vibecoding -- AGENTS.md Guide (2026)
  https://vibecoding.app/blog/agents-md-guide
  Tool-by-tool setup instructions. Cross-tool support landscape.
  Decision framework for AGENTS.md vs tool-specific files.

[REF-10]  Cursor Docs -- Rules
  https://cursor.com/docs/rules
  .cursor/rules/ MDC format, YAML frontmatter, glob scoping,
  rule types (Always, Auto Attached, Model Decision, Manual).

[REF-11]  Windsurf (Devin) Docs -- AGENTS.md
  https://docs.windsurf.com/windsurf/cascade/agents-md
  Focused instructions per directory. Clear formatting recommendations.

[REF-12]  GitLab Docs -- AGENTS.md customization
  https://docs.gitlab.com/user/duo_agent_platform/customize/agents_md/
  Repository structure, coding conventions, style guidelines.

[REF-13]  Lulla et al. -- ICSE JAWs 2026
  https://arxiv.org/abs/2601.20404
  124 real GitHub PRs. Human-authored AGENTS.md reduced runtime 28.64%
  and token consumption 16.58%.

[REF-14]  GitHub Blog -- How to Write a Great AGENTS.md
  https://github.blog/ai-and-ml/github-copilot/how-to-write-a-great-agents-md-lessons-from-over-2500-repositories/
  Analysis of 2500+ repositories. "Never commit secrets" most common
  helpful constraint. Section effectiveness rankings.

[REF-15]  agentsmd.io -- Articles Collection
  https://agentsmd.io/articles
  Curated articles about AGENTS.md and AI development best practices.

[REF-16]  AI Native Compass -- Good Practices Creating AGENTS.md
  https://ainativecompass.substack.com/p/good-practices-creating-agentsmd
  Practical section-by-section structure. Brevity and clarity guidelines.
  Single source of truth principle.

[REF-17]  Arize AI -- Claude.md Best Practices via Prompt Learning
  https://arize.com/blog/claude-md-best-practices-learned-from-optimizing-claude-code-with-prompt-learning/
  Automated optimization of context files. +5.19% accuracy on cross-repo,
  +10.87% on in-repo. What humans think agents need vs what actually helps.

[REF-18]  Anthropic -- Effective Context Engineering for AI Agents
  https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents
  Context prioritization. Agents preserve architectural decisions while
  discarding redundant tool outputs. Lost-in-the-middle mitigation.
