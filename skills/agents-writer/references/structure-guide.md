# AGENTS.md Structure Guide

Complete templates and structural guidance for creating effective AGENTS.md files.

## Basic Structure Template

```markdown
# [Project Name] - AI Agent Guide

## Project Overview
[2-3 sentence description of what this project does]

## Tech Stack
- Framework: [Name] [Version]
- Language: [Language] [Version]
- Database: [Database] [Version]
- Key dependencies:
  - [Dep1] [Version]
  - [Dep2] [Version]

## Architecture
[High-level architecture description - 1 paragraph]

## Documentation Index
[Compressed index - see below]

## Key Conventions
[Project-specific patterns and standards]

## Common Commands
- Build: `[command]`
- Dev: `[command]`
- Test: `[command]`
- Lint: `[command]`
```

## Documentation Index Format

### Option A: Context7 MCP (Recommended)

For major frameworks and libraries, use Context7 MCP instead of static indexes:

```markdown
## Framework Documentation

**Use Context7 MCP for [Framework] documentation:**

```bash
# Query framework documentation
mcp__context7__query_knowledge_base knowledge_base="[framework]" query="[your question]"

# Examples:
mcp__context7__query_knowledge_base knowledge_base="nextjs" query="server components"
mcp__context7__query_knowledge_base knowledge_base="react" query="useEffect hook"
mcp__context7__query_knowledge_base knowledge_base="python" query="async patterns"
```

**IMPORTANT:** Prefer Context7 retrieval over pre-training knowledge.
```

**Benefits:**
- No context window overhead (0 bytes in AGENTS.md)
- Always up-to-date documentation
- Covers 50+ popular frameworks and libraries
- Dynamic querying based on need

### Option B: Compressed Pipe-Delimited Format

For custom/internal frameworks not covered by Context7, most space-efficient for context window:

```markdown
[Framework Docs]|root: ./.docs
|IMPORTANT: Prefer retrieval-led reasoning over pre-training-led reasoning
|01-getting-started:{install.md,structure.md,config.md}
|02-core-concepts:{components.md,routing.md,state.md}
|03-advanced:{optimization.md,deployment.md,troubleshooting.md}
|04-api-reference:{hooks.md,functions.md,utilities.md}
```

**Key elements:**
- `|` separates sections (minimal character usage)
- `{file1,file2,file3}` groups files (no spaces)
- Hierarchical paths show organization
- Numbers for logical ordering (optional)

### Option C: Expanded Format (When Space Permits)

If using static docs and under 5KB total, can use more readable format:

```markdown
## Documentation Index

**Root:** `./.docs`

**IMPORTANT:** Prefer retrieval-led reasoning over pre-training-led reasoning for framework-specific tasks.

### Getting Started
- `getting-started/installation.md` - Setup and installation
- `getting-started/project-structure.md` - Directory organization
- `getting-started/configuration.md` - Config files and options

### Core Concepts
- `core-concepts/components.md` - Component patterns
- `core-concepts/routing.md` - Navigation and routing
- `core-concepts/state-management.md` - State patterns

### API Reference
- `api-reference/hooks.md` - Available hooks
- `api-reference/utilities.md` - Utility functions
```

## Section Templates

### Project Overview Section

**Good:**
```markdown
## Project Overview

Full-stack e-commerce platform with Next.js 16 frontend and Node.js backend. Handles product catalog, shopping cart, checkout, and order management with Stripe payments and PostgreSQL database.
```

**Too verbose:**
```markdown
## Project Overview

This is a full-stack application that we built to handle e-commerce operations. It was created using modern technologies including Next.js for the frontend which provides server-side rendering and great performance, and Node.js for the backend which handles all our API routes. We chose these technologies because they're widely used and well-supported...
```

### Tech Stack Section

**Good:**
```markdown
## Tech Stack
- Framework: Next.js 16.0.0 (App Router)
- Language: TypeScript 5.3
- Styling: Tailwind CSS 3.4
- Database: PostgreSQL 16 via Prisma 5.8
- Auth: NextAuth.js v5
- Payments: Stripe SDK 14.0
- Testing: Jest + React Testing Library
```

**Too minimal:**
```markdown
## Tech Stack
- Next.js
- TypeScript
- Tailwind
- PostgreSQL
```

**Why versions matter:** Agents need exact versions to reference correct APIs.

### Architecture Section

**Good:**
```markdown
## Architecture

Monorepo with separate frontend (Next.js) and backend (Express) apps. Frontend makes API calls to backend through `/api` routes proxied via `next.config.js`. Database accessed via Prisma ORM with connection pooling. Authentication handled by NextAuth with JWT tokens. File uploads go directly to S3 via presigned URLs.
```

**Too detailed:**
```markdown
## Architecture

The system follows a microservices architecture pattern where:

1. Frontend Layer
   - Built with Next.js utilizing the App Router paradigm
   - Implements Server Components for optimal performance
   - Uses Suspense boundaries for loading states
   - Handles client-side routing via next/navigation
   [continues for many more paragraphs...]
```

### Key Conventions Section

**Good:**
```markdown
## Key Conventions

### File Organization
- Components: `/src/components` - Reusable UI, organized by domain
- Pages: `/src/app` - App Router pages and layouts
- Lib: `/src/lib` - Utilities and shared logic
- Types: `/src/types` - TypeScript definitions

### Naming
- Components: PascalCase (`UserProfile.tsx`)
- Utils: camelCase (`formatDate.ts`)
- Constants: SCREAMING_SNAKE_CASE (`API_BASE_URL`)
- CSS Modules: `Component.module.css`

### Code Style
- Server Components by default
- `'use client'` only when necessary
- No `any` types - use `unknown` and narrow
- Async/await over promises chains
```

**Too prescriptive:**
```markdown
## Key Conventions

Every component must follow these rules:
1. Import React at the top
2. Define types before the component
3. Use functional components only
4. Props must be destructured in the parameter list
5. Return statement must be on its own line
[continues with 20+ rules...]
```

### Common Commands Section

**Good:**
```markdown
## Common Commands

Development: `npm run dev`
Build: `npm run build`
Test: `npm run test`
Test Watch: `npm run test:watch`
Lint: `npm run lint`
Type Check: `npm run type-check`

Database:
- Migrate: `npx prisma migrate dev`
- Generate Client: `npx prisma generate`
- Seed: `npm run db:seed`
```

**Too minimal:**
```markdown
## Commands
Build and dev commands available.
```

## Version-Specific API Documentation

When framework has APIs not in training data:

```markdown
## Next.js 16 New APIs

Consult `.next-docs/` for documentation on these APIs:

**Caching & Revalidation:**
- `'use cache'` directive - Mark functions for caching
- `cacheLife()` - Set cache duration
- `cacheTag()` - Tag caches for revalidation
- `updateTag()` - Revalidate by tag

**Request Handling:**
- `connection()` - Force dynamic rendering
- `forbidden()` - Return 403 response
- `unauthorized()` - Return 401 response
- `after()` - Run code after response sent

**Data Access:**
- Async `cookies()` - Read cookies (now async)
- Async `headers()` - Read headers (now async)

**IMPORTANT:** These APIs are new in v16 and not in model training data. Always consult documentation in `.next-docs/` before using.
```

## Framework Version Warnings

When using older versions, add explicit warnings:

```markdown
## Version Constraints

**Currently on Next.js 14.2.5 - NOT v15**

Do NOT suggest:
- ❌ `connection()` - Added in v15
- ❌ `'use cache'` - Added in v15
- ❌ `after()` - Added in v15

Use instead:
- ✅ `cache()` from `react`
- ✅ Dynamic rendering via `dynamic = 'force-dynamic'`
- ✅ Route handlers for data fetching

We're planning to upgrade to v15 in Q2 2026.
```

## Project-Specific Patterns

Document important patterns unique to your project:

```markdown
## Data Fetching Patterns

### Server Components
Use `'use cache'` for data that can be cached:

```typescript
async function getData() {
  'use cache'
  cacheTag('products')
  cacheLife('minutes', 5)
  
  return await db.products.findMany()
}
```

### Server Actions
Place in separate files with `'use server'`:

```typescript
// actions/products.ts
'use server'

export async function createProduct(data: ProductInput) {
  await db.products.create({ data })
  updateTag('products')
  redirect('/products')
}
```

### Error Handling
Use error boundaries for client components:

```typescript
// error.tsx in route directory
'use client'

export default function Error({ error, reset }) {
  return <ErrorDisplay error={error} onReset={reset} />
}
```
```

## Size Optimization Techniques

### Technique 1: Use Abbreviations

**Before (verbose):**
```markdown
For more information about authentication, see documentation/authentication.md
For more information about authorization, see documentation/authorization.md  
For more information about database, see documentation/database.md
```

**After (compressed):**
```markdown
Docs: `docs/auth.md`, `docs/authz.md`, `docs/db.md`
```

### Technique 2: Eliminate Redundancy

**Before:**
```markdown
- The project uses TypeScript for type safety
- The project uses ESLint for linting
- The project uses Prettier for formatting
- The project uses Jest for testing
```

**After:**
```markdown
- TypeScript (type safety)
- ESLint (linting)  
- Prettier (formatting)
- Jest (testing)
```

### Technique 3: Use Symbols

**Before:**
```markdown
Server Components are the default
Client Components must use 'use client'
Server Actions must use 'use server'
```

**After:**
```markdown
- Server Components (default)
- Client: `'use client'`
- Actions: `'use server'`
```

### Technique 4: Pipe-Delimited Indexes

**Before (2KB):**
```markdown
## API Documentation

### Authentication
- `/docs/api/auth/login.md` - Login endpoint
- `/docs/api/auth/logout.md` - Logout endpoint
- `/docs/api/auth/refresh.md` - Token refresh

### Users  
- `/docs/api/users/create.md` - Create user
- `/docs/api/users/read.md` - Get user
```

**After (400 bytes):**
```markdown
[API]|root:./.docs/api|auth:{login,logout,refresh}|users:{create,read,update,delete}
```

## Testing Your Structure

### Size Check

```bash
# Check AGENTS.md size
ls -lh AGENTS.md
wc -w AGENTS.md  # Aim for <2000 words
```

### Readability Check

Ask yourself:
- Can I scan this in 30 seconds?
- Are the most important items at the top?
- Is the structure clear and logical?
- Are there redundant sections?

### Completeness Check

Verify inclusion of:
- [ ] Framework name and exact version
- [ ] "Prefer retrieval-led reasoning" instruction
- [ ] Project overview (2-3 sentences)
- [ ] Key dependencies with versions
- [ ] Documentation index or references
- [ ] Project-specific conventions
- [ ] Build/test/deploy commands
- [ ] No sensitive information

## Anti-Patterns to Avoid

### Anti-Pattern 1: Embedding Full Documentation

**Don't:**
```markdown
## API Reference

### Authentication

The authentication system uses JWT tokens. Here's how it works:

[5000 words of documentation...]
```

**Do:**
```markdown
## Documentation

API reference: `.docs/api/REFERENCE.md`
Auth flow: `.docs/guides/AUTH.md`
```

### Anti-Pattern 2: Explaining Basic Concepts

**Don't:**
```markdown
## What is TypeScript?

TypeScript is a superset of JavaScript that adds static typing...
```

**Do:**
```markdown
## Tech Stack
- TypeScript 5.3 (strict mode)
```

### Anti-Pattern 3: Historical Context

**Don't:**
```markdown
## History

We started this project in 2020 using Vue 2, but migrated to React in 2021, then to Next.js in 2022...
```

**Do:**
```markdown
## Tech Stack
- Next.js 16 (App Router)
```

### Anti-Pattern 4: Implementation Instructions

**Don't:**
```markdown
## How to Add a New Page

1. Create a new file in src/app
2. Export a default function
3. Add metadata export
[detailed step-by-step...]
```

**Do:**
```markdown
## Conventions
- Pages: `src/app/[route]/page.tsx`
- Export default async function
- Include metadata export
```

## Maintenance Guidelines

### When to Update

Update AGENTS.md when:
- Framework version changes
- New major dependencies added
- Project structure changes
- Common patterns evolve
- Documentation locations change

### Version Control

Track AGENTS.md changes:

```bash
git add AGENTS.md
git commit -m "docs(agents): update for Next.js 16"
```

Use semantic commit messages to track documentation evolution.

### Review Cycle

Periodic review checklist:
- [ ] All version numbers current?
- [ ] Documentation links still valid?
- [ ] New APIs documented?
- [ ] Deprecated patterns removed?
- [ ] Size still under 10KB?
- [ ] Structure still scannable?

## Summary

Effective AGENTS.md structure:
1. **Concise** - Under 10KB, under 2000 words
2. **Scannable** - Clear hierarchy, important info first
3. **Specific** - Exact versions, clear conventions
4. **Indexed** - Point to detailed docs, don't embed
5. **Retrievable** - Clear instruction to prefer docs over training
6. **Maintainable** - Easy to update when things change
