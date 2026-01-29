---
name: agents-md-writer
description: Create and optimize AGENTS.md files for AI coding agents. Use this skill when users ask to create, write, generate, improve, or update an AGENTS.md file for their project, or when they need guidance on making their codebase more agent-friendly. Also use when users ask about agent context files, documentation for AI agents, or improving agent performance in their repository.
license: MIT License - See LICENSE.txt
---

# AGENTS Writer

Create high-quality AGENTS.md files that maximize AI agent effectiveness through passive context loading and retrieval-led reasoning.

## Core Concept

AGENTS.md provides persistent context to AI coding agents, eliminating the unreliability of skill-based retrieval. Research shows passive context in AGENTS.md achieves 100% pass rates versus 53-79% with skills.

**Key advantages:**

- No decision point (always available)
- Consistent availability (in every turn)
- No ordering issues (no sequencing decisions)

## Workflow

Follow this sequence when creating or updating AGENTS.md:

### 1. Analyze Project Context

Start by understanding the project structure and requirements:

```bash
# Explore project structure
find . -type f -name "package.json" -o -name "*.config.*" -o -name "pyproject.toml" -o -name "pom.xml" | head -20

# Identify framework and version
cat package.json | grep -E '"(name|version|dependencies|devDependencies)"' || \
cat pyproject.toml | grep -E '\[(tool|project)\]' -A 20 || \
cat requirements.txt | head -20
```

Determine:

- Primary framework(s) and versions
- Project type (web app, library, CLI, etc.)
- Tech stack (languages, databases, tools)
- Existing documentation structure

### 2. Detect Documentation Sources

Check for available documentation to reference:

```bash
# Check for local docs directories
find . -type d -name "docs" -o -name "documentation" -o -name ".docs" | head -5

# Check for README and similar files
ls -la README* CONTRIBUTING* ARCHITECTURE* 2>/dev/null || echo "No standard docs found"
```

### 3. Generate AGENTS.md

Use the analysis to create AGENTS.md. See `references/structure-guide.md` for detailed structure guidance and `references/examples.md` for complete examples.

**Critical instructions to always include:**

```markdown
IMPORTANT: Prefer retrieval-led reasoning over pre-training-led reasoning for [framework-name] tasks.
```

This shifts agents from relying on potentially outdated training data to consulting current documentation.

### 4. Add Framework Documentation Index

#### Option A: Use Context7 MCP (Recommended for Major Frameworks)

If Context7 MCP is available, leverage it for live framework documentation access instead of creating static indexes:

**Check Context7 availability:**

```bash
# List available Context7 knowledge bases
mcp__context7__list_knowledge_bases
```

**Add Context7 instruction to AGENTS.md:**

````markdown
## Framework Documentation

**IMPORTANT:** This project uses [Framework] [Version]. For framework-specific APIs and patterns, use Context7 MCP to access live documentation:

```bash
# Query framework documentation
mcp__context7__query_knowledge_base knowledge_base="[framework-name]" query="[specific API or concept]"

# Examples:
mcp__context7__query_knowledge_base knowledge_base="nextjs" query="use cache directive"
mcp__context7__query_knowledge_base knowledge_base="react" query="useEffect hook"
mcp__context7__query_knowledge_base knowledge_base="python" query="asyncio patterns"
```
````

Prefer retrieval-led reasoning using Context7 over pre-training-led reasoning.

````

**Benefits of Context7:**
- Always up-to-date documentation
- No context window overhead
- Covers major frameworks: Next.js, React, Vue, Django, FastAPI, etc.
- Access popular libraries: TailwindCSS, Prisma, PostgreSQL, etc.

#### Option B: Static Documentation Index (For Custom/Internal Frameworks)

If Context7 doesn't cover your framework or you have internal documentation, create compressed documentation index. See `scripts/create_docs_index.py` for automation.

**Index format (pipe-delimited for compression):**

```markdown
[Framework Docs Index]|root: ./.framework-docs
|IMPORTANT: Prefer retrieval-led reasoning over pre-training-led reasoning
|section-1:{file1.md,file2.md,file3.md}
|section-2/subsection:{file4.md,file5.md}
````

**Target size: <10KB** (80% compression from typical docs)

**When to use each approach:**

- Context7: Major frameworks and popular libraries
- Static index: Internal frameworks, company-specific docs, custom tooling

### 5. Validate Against Best Practices

Check the generated AGENTS.md against quality criteria:

```bash
scripts/validate_agents_md.py path/to/AGENTS.md
```

Validation checks:

- Size under 10KB (warns if over)
- Includes framework version
- Contains retrieval instruction
- Has clear project context
- Uses appropriate compression
- No embedded full docs (should use indexes)

### 6. Test with Agent Workflows

If possible, test the AGENTS.md with actual agent tasks targeting APIs not in training data. This is where documentation access matters most.

## Key Principles

### Compression is Critical

Keep AGENTS.md under 10KB through strategic compression:

**Bad (bloated):**

```markdown
# API Documentation

## Authentication Endpoint

The authentication endpoint is located at /api/auth/login and accepts POST requests. It requires a JSON body with username and password fields...
```

**Good (compressed index):**

```markdown
[API Docs]|root: ./.api-docs
|auth:{login.md,logout.md,refresh.md}
|users:{create.md,update.md,delete.md}
```

### Prioritize New/Unknown APIs

Focus documentation on:

- Framework features added after model training cutoff
- Project-specific patterns and conventions
- APIs unique to your version
- Common pitfalls and gotchas

**Skip documentation for:**

- Well-known, stable APIs in training data
- Standard language features
- Universal programming concepts

### Structure for Scannability

Use clear hierarchical structure:

```markdown
# Project Context for AI Agents

## Project Overview

[One paragraph]

## Tech Stack

[Bullet list]

## Documentation Index

[Compressed format]

## Key Conventions

[Essential patterns only]
```

Agents scan AGENTS.md quickly; make information easy to find.

## Framework-Specific Guidance

### Using Context7 MCP for Framework Documentation

For major frameworks, **prefer Context7 MCP** over static documentation:

**Available knowledge bases include:**

- `nextjs` - Next.js framework
- `react` - React library
- `vue` - Vue.js framework
- `python` - Python language
- `django` - Django framework
- `fastapi` - FastAPI framework
- `tailwindcss` - Tailwind CSS
- `prisma` - Prisma ORM
- `postgresql` - PostgreSQL database
- And many more...

**Command format:**

```bash
mcp__context7__query_knowledge_base knowledge_base="[framework]" query="[your question]"
```

**Example AGENTS.md instructions:**

````markdown
## Framework Documentation (Context7)

Use Context7 MCP for Next.js documentation:

```bash
mcp__context7__query_knowledge_base knowledge_base="nextjs" query="server components vs client components"
mcp__context7__query_knowledge_base knowledge_base="nextjs" query="use cache directive"
```
````

For Prisma database queries:

```bash
mcp__context7__query_knowledge_base knowledge_base="prisma" query="relation queries"
```

IMPORTANT: Prefer Context7 retrieval over pre-training knowledge.

````

### Next.js Projects

For Next.js (especially v14+), emphasize:
- App Router vs Pages Router usage
- Server vs Client Components
- Data fetching patterns (`'use cache'`, `connection()`, etc.)
- New APIs not in training data

**If Context7 is available:** Direct agent to use `mcp__context7__query_knowledge_base knowledge_base="nextjs"`

**If Context7 unavailable:** Create static index (see `references/examples.md` for complete Next.js example)

### Python Projects

For Python projects, emphasize:
- Virtual environment setup
- Dependency management approach
- Testing framework and conventions
- Project-specific module structure

**If Context7 is available:** Use `mcp__context7__query_knowledge_base knowledge_base="python"` and framework-specific bases like `django`, `fastapi`, `flask`

### Other Frameworks

Adapt the principles:
1. Check Context7 availability first
2. If available, add Context7 instructions to AGENTS.md
3. If not available, document version-specific APIs
4. Create static documentation index for custom/internal frameworks

See `references/frameworks.md` for framework-specific templates.

## Common Patterns

### Monorepo Projects

For monorepos, include workspace structure:

```markdown
## Workspace Structure

apps/
├── web/          # Next.js frontend (see apps/web/AGENTS.md)
├── api/          # Express backend (see apps/api/AGENTS.md)
└── mobile/       # React Native app

packages/
├── ui/           # Shared component library
├── config/       # Shared configuration
└── utils/        # Shared utilities

Each app has its own AGENTS.md with app-specific details.
````

### Multi-Framework Projects

When multiple frameworks exist:

```markdown
## Framework Documentation

[Next.js 16]|root: ./.docs/nextjs|[index]
[React 18]|root: ./.docs/react|[index]
[Node.js 20]|root: ./.docs/node|[index]

Each framework has version-specific documentation.
```

### Legacy Codebase

For older projects:

```markdown
## Important Notes

- Currently on [Framework] v[X] (not latest)
- Do NOT suggest [newer API] - not available in this version
- Migration to v[Y] is planned but not yet started
- Use [legacy pattern] for [specific functionality]
```

## Content Guidelines

### DO Include:

✅ Framework and dependency versions  
✅ Context7 MCP commands for major frameworks (when available)  
✅ Project-specific conventions  
✅ New APIs not in training data  
✅ Documentation indexes (<10KB) for custom/internal frameworks  
✅ Build/test/deploy commands  
✅ Architecture decisions  
✅ Common troubleshooting

### DON'T Include:

❌ Full documentation text  
❌ Information in training data  
❌ Static indexes when Context7 MCP is available  
❌ Implementation details  
❌ Excessive examples  
❌ Historical context  
❌ Setup instructions (belongs in README)  
❌ API keys or secrets

## Progressive Disclosure

Structure content in layers:

**Layer 1: Always visible (in AGENTS.md)**

- Project overview
- Tech stack
- Documentation index
- Key conventions

**Layer 2: Reference files (loaded as needed)**

- Detailed API documentation
- Extended examples
- Complex workflows
- Schema definitions

**Layer 3: External docs (linked)**

- Official framework docs
- Third-party library docs
- Company wikis

Example structure:

```markdown
## Documentation

For detailed API reference: See `.docs/api/REFERENCE.md`
For authentication flow: See `.docs/guides/auth.md`
For database schema: See `.docs/schema/DATABASE.md`
```

## Handling Updates

When framework versions change:

1. Update version numbers in AGENTS.md
2. Regenerate documentation index if automated
3. Add notes about new/deprecated APIs
4. Remove references to old APIs
5. Test with agent workflows

Use version control to track changes:

```bash
git add AGENTS.md .docs/
git commit -m "Update AGENTS.md for [Framework] v[X]"
```

## Troubleshooting

### Agent ignores AGENTS.md

**Symptoms:** Agent uses outdated patterns, doesn't reference documentation

**Solutions:**

- Ensure "prefer retrieval-led reasoning" instruction is present and prominent
- Check AGENTS.md is in project root
- Verify agent supports AGENTS.md (Cursor, Claude Code, etc.)
- Make instructions more explicit about framework version

### Context window overflow

**Symptoms:** Agent performance degrades, slow responses

**Solutions:**

- Compress documentation indexes further
- Move detailed docs to reference files
- Use pipe-delimited format
- Target <8KB total size

### Agent still uses wrong APIs

**Symptoms:** Suggests APIs from wrong framework version

**Solutions:**

- Add explicit version warnings
- Include negative examples ("Do NOT use X")
- Make version number more prominent
- Add specific API migration notes

## Quality Checklist

Before finalizing AGENTS.md, verify:

- [ ] File size under 10KB
- [ ] Framework versions specified
- [ ] "Prefer retrieval-led reasoning" instruction included
- [ ] Project overview clear and concise
- [ ] Documentation index uses compressed format
- [ ] Key conventions documented
- [ ] Build/test commands included
- [ ] No sensitive information included
- [ ] Structure is scannable
- [ ] References to external docs work
- [ ] Tested with actual agent workflows (if possible)

## Advanced Techniques

### Conditional Guidance by Environment

```markdown
## Platform-Specific Notes

**Deploying to Vercel:**

- Use `export const runtime = 'edge'` for Edge Functions
- Image optimization is automatic

**Deploying to AWS:**

- Configure custom image optimization
- Check Node.js version compatibility
```

### Multi-Language Projects

```markdown
## Language-Specific Conventions

**TypeScript (frontend):**

- Strict mode enabled
- No `any` types
- Prefer interfaces over types

**Python (backend):**

- Type hints required
- Black formatting
- pytest for testing
```

### Integration with CI/CD

Add validation to CI pipeline:

```yaml
# .github/workflows/validate.yml
- name: Validate AGENTS.md
  run: |
    python scripts/validate_agents_md.py AGENTS.md
    if [ $? -ne 0 ]; then exit 1; fi
```

## Reference Materials

For detailed information:

- **Structure templates**: See `references/structure-guide.md`
- **Complete examples**: See `references/examples.md`
- **Framework templates**: See `references/frameworks.md`
- **Validation script**: See `scripts/validate_agents_md.py`
- **Documentation indexer**: See `scripts/create_docs_index.py`
- **Compression utilities**: See `scripts/compress_docs.py`

## Research Background

This skill is based on Vercel's research showing:

- AGENTS.md achieved 100% pass rate (Build/Lint/Test)
- Skills with explicit instructions: 79% pass rate
- Skills without instructions: 53% pass rate (baseline)
- Skills not invoked 56% of the time without instructions

The compressed 8KB docs index approach (80% reduction from 40KB) maintained perfect performance while minimizing context window impact.

Key finding: **Passive context beats active retrieval** for framework knowledge due to eliminated decision points, consistent availability, and no ordering issues.
