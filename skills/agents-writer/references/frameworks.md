# Framework-Specific AGENTS.md Templates

Quick-start templates for popular frameworks. Customize for your project.

## Using Context7 MCP

**Before using static templates, check if Context7 MCP is available for your framework.**

Available Context7 knowledge bases include:
- `nextjs` - Next.js framework
- `react` - React library  
- `vue` - Vue.js framework
- `python` - Python language
- `django` - Django framework
- `fastapi` - FastAPI framework
- `flask` - Flask framework
- `express` - Express.js framework
- `tailwindcss` - Tailwind CSS
- `prisma` - Prisma ORM
- `postgresql` - PostgreSQL
- `mongodb` - MongoDB
- And many more...

**Command format:**
```bash
mcp__context7__query_knowledge_base knowledge_base="[framework]" query="[your question]"
```

**If Context7 is available for your framework:** Use the Context7-enabled templates below.  
**If not available:** Use static documentation indexes (see templates below).

---

## Next.js (App Router)

```markdown
# [Project Name] - AI Agent Guide

## Project Overview
[Description]

## Tech Stack
- Framework: Next.js [version] (App Router)
- Language: TypeScript [version]
- Styling: [Tailwind/CSS Modules/etc]
- Database: [Database] via [ORM]
- [Other key dependencies]

## Framework Documentation

**Use Context7 MCP for Next.js documentation:**

```bash
# Next.js queries
mcp__context7__query_knowledge_base knowledge_base="nextjs" query="[your question]"

# Related libraries
mcp__context7__query_knowledge_base knowledge_base="react" query="[your question]"
mcp__context7__query_knowledge_base knowledge_base="tailwindcss" query="[your question]"
```

**IMPORTANT:** Prefer Context7 retrieval over pre-training knowledge for Next.js [version] APIs.

**Alternative (if Context7 unavailable):** See `.next-docs/` for static documentation.

## Architecture
[Brief architecture description]

## Key Conventions

### Server vs Client Components
- Server Components by default
- Use `'use client'` only for: interactivity, browser APIs, React hooks

### Data Fetching
[Your data fetching patterns]

### Server Actions
[Your server action patterns]

### File Naming
[Your naming conventions]

## Common Commands
- Dev: `npm run dev`
- Build: `npm run build`
- Test: `npm test`
- Lint: `npm run lint`

## Environment Variables
[List required env vars]
```

## React (Vite)

```markdown
# [Project Name] - AI Agent Guide

## Project Overview
[Description]

## Tech Stack
- Framework: React [version] with Vite [version]
- Language: TypeScript [version]
- State: [Redux/Zustand/Context]
- Styling: [Styling solution]
- Routing: React Router [version]

## Project Structure

```
src/
├── components/    # Reusable components
├── pages/         # Page components
├── hooks/         # Custom hooks
├── store/         # State management
├── services/      # API services
├── utils/         # Utilities
└── types/         # TypeScript types
```

## Key Conventions

### Component Organization
[Your component structure]

### State Management
[Your state patterns]

### Routing
[Your routing setup]

### API Integration
[Your API patterns]

## Common Commands
- Dev: `npm run dev`
- Build: `npm run build`
- Preview: `npm run preview`
- Test: `npm test`
- Lint: `npm run lint`

## Environment Variables
[List required env vars]
```

## Vue 3 (Composition API)

```markdown
# [Project Name] - AI Agent Guide

## Project Overview
[Description]

## Tech Stack
- Framework: Vue [version] (Composition API)
- Language: TypeScript [version]
- State: [Pinia/Vuex]
- Styling: [Styling solution]
- Routing: Vue Router [version]
- Build: [Vite/Nuxt]

## Project Structure

```
src/
├── components/     # Vue components
├── views/          # Page views
├── composables/    # Composition functions
├── stores/         # Pinia stores
├── router/         # Router config
└── types/          # TypeScript types
```

## Key Conventions

### Composition API
```vue
<script setup lang="ts">
import { ref, computed } from 'vue'

const count = ref(0)
const double = computed(() => count.value * 2)
</script>
```

### State Management (Pinia)
[Your Pinia patterns]

### Routing
[Your routing patterns]

## Common Commands
- Dev: `npm run dev`
- Build: `npm run build`
- Test: `npm test`
- Lint: `npm run lint`

## Environment Variables
[List required env vars with VITE_ prefix]
```

## Django

```markdown
# [Project Name] - AI Agent Guide

## Project Overview
[Description]

## Tech Stack
- Framework: Django [version]
- Language: Python [version]
- Database: [Database]
- Task Queue: [Celery/RQ/none]
- Testing: pytest [version]

## Framework Documentation

**Use Context7 MCP for Django and Python documentation:**

```bash
# Django queries
mcp__context7__query_knowledge_base knowledge_base="django" query="[your question]"

# Python queries
mcp__context7__query_knowledge_base knowledge_base="python" query="[your question]"

# Database queries
mcp__context7__query_knowledge_base knowledge_base="postgresql" query="[your question]"
```

**IMPORTANT:** Prefer Context7 retrieval over pre-training knowledge.

## Project Structure

```
project/
├── apps/              # Django apps
│   ├── users/
│   ├── api/
│   └── core/
├── config/            # Project settings
│   ├── settings/     # Split settings (base, dev, prod)
│   ├── urls.py
│   └── wsgi.py
├── static/           # Static files
├── templates/        # Django templates
└── tests/            # Test files
```

## Key Conventions

### Apps Organization
[Your app structure]

### Models
[Your model patterns]

### Views/ViewSets
[Your view patterns]

### URL Configuration
[Your URL patterns]

### Serializers (if using DRF)
[Your serializer patterns]

## Common Commands
- Dev: `python manage.py runserver`
- Migrate: `python manage.py migrate`
- Create Migration: `python manage.py makemigrations`
- Test: `pytest`
- Shell: `python manage.py shell_plus`

## Environment Variables
[List required env vars]
```

## FastAPI

```markdown
# [Project Name] - AI Agent Guide

## Project Overview
[Description]

## Tech Stack
- Framework: FastAPI [version]
- Language: Python [version]
- Database: [Database] via [SQLAlchemy/etc]
- Cache: [Redis/etc]
- Task Queue: [Celery/etc]
- Testing: pytest [version]

## Framework Documentation

**Use Context7 MCP for FastAPI and Python documentation:**

```bash
# FastAPI queries
mcp__context7__query_knowledge_base knowledge_base="fastapi" query="[your question]"

# Python queries
mcp__context7__query_knowledge_base knowledge_base="python" query="[your question]"

# Database queries
mcp__context7__query_knowledge_base knowledge_base="postgresql" query="[your question]"
```

**IMPORTANT:** Prefer Context7 retrieval over pre-training knowledge.

## Project Structure

```
src/
├── api/              # API routes
│   ├── v1/          # API version 1
│   └── deps.py      # Dependencies
├── models/          # Database models
├── schemas/         # Pydantic schemas
├── services/        # Business logic
├── core/            # Config, security
└── tests/           # Test files
```

## Key Conventions

### Async Patterns
[Your async patterns]

### Dependency Injection
[Your DI patterns]

### Error Handling
[Your error handling]

### Database Sessions
[Your session management]

## Common Commands
- Dev: `uvicorn src.main:app --reload`
- Test: `pytest`
- Lint: `ruff check src/`
- Format: `black src/`
- Migrate: `alembic upgrade head`

## Environment Variables
[List required env vars]
```

## Flask

```markdown
# [Project Name] - AI Agent Guide

## Project Overview
[Description]

## Tech Stack
- Framework: Flask [version]
- Language: Python [version]
- Database: [Database] via [SQLAlchemy]
- Extensions: [List key Flask extensions]
- Testing: pytest [version]

## Project Structure

```
app/
├── __init__.py       # App factory
├── models/           # Database models
├── routes/           # Blueprints
├── services/         # Business logic
├── templates/        # Jinja templates
└── static/           # Static files
tests/                # Test files
```

## Key Conventions

### Application Factory
[Your app factory pattern]

### Blueprints
[Your blueprint organization]

### Database Patterns
[Your DB patterns]

## Common Commands
- Dev: `flask run`
- Shell: `flask shell`
- Migrate: `flask db migrate`
- Upgrade: `flask db upgrade`
- Test: `pytest`

## Environment Variables
[List required env vars]
```

## Express.js

```markdown
# [Project Name] - AI Agent Guide

## Project Overview
[Description]

## Tech Stack
- Framework: Express [version]
- Language: TypeScript [version]
- Database: [Database] via [ORM]
- Validation: [Zod/Joi/etc]
- Testing: Jest [version]

## Project Structure

```
src/
├── routes/           # Route handlers
├── controllers/      # Controller logic
├── services/         # Business logic
├── models/           # Database models
├── middleware/       # Express middleware
├── utils/            # Utilities
└── types/            # TypeScript types
```

## Key Conventions

### Route Organization
[Your route patterns]

### Middleware
[Your middleware patterns]

### Error Handling
[Your error handling]

### Database Patterns
[Your DB patterns]

## Common Commands
- Dev: `npm run dev`
- Build: `npm run build`
- Start: `npm start`
- Test: `npm test`
- Lint: `npm run lint`

## Environment Variables
[List required env vars]
```

## Ruby on Rails

```markdown
# [Project Name] - AI Agent Guide

## Project Overview
[Description]

## Tech Stack
- Framework: Rails [version]
- Language: Ruby [version]
- Database: [Database]
- Testing: RSpec [version]
- Background Jobs: [Sidekiq/etc]

## Project Structure

```
app/
├── controllers/      # Controllers
├── models/           # ActiveRecord models
├── views/            # ERB/Slim views
├── jobs/             # Background jobs
├── mailers/          # Action Mailers
├── services/         # Service objects
└── helpers/          # View helpers
```

## Key Conventions

### Controllers
[Your controller patterns]

### Models
[Your model patterns]

### Service Objects
[Your service patterns]

### Testing
[Your test patterns]

## Common Commands
- Dev: `rails server`
- Console: `rails console`
- Migrate: `rails db:migrate`
- Test: `rspec`
- Routes: `rails routes`

## Environment Variables
[List required env vars]
```

## React Native (Expo)

```markdown
# [Project Name] - AI Agent Guide

## Project Overview
[Description]

## Tech Stack
- Framework: Expo [version] (React Native [version])
- Language: TypeScript [version]
- State: [Redux/Zustand/etc]
- Navigation: React Navigation [version]
- Testing: Jest + React Native Testing Library

## Project Structure

```
src/
├── screens/         # Screen components
├── components/      # Reusable components
├── navigation/      # Navigation config
├── store/           # State management
├── services/        # API services
├── hooks/           # Custom hooks
└── types/           # TypeScript types
```

## Key Conventions

### Navigation
[Your navigation patterns]

### State Management
[Your state patterns]

### Platform-Specific Code
[Your platform handling]

## Common Commands
- Start: `npx expo start`
- iOS: `npx expo start --ios`
- Android: `npx expo start --android`
- Test: `npm test`
- Build iOS: `eas build --platform ios`
- Build Android: `eas build --platform android`

## Environment Variables
[List EXPO_PUBLIC_ prefixed vars]

## Platform Notes
- iOS minimum: iOS [version]
- Android minimum: SDK [version]
```

## Svelte/SvelteKit

```markdown
# [Project Name] - AI Agent Guide

## Project Overview
[Description]

## Tech Stack
- Framework: SvelteKit [version]
- Language: TypeScript [version]
- Database: [Database] via [ORM]
- Styling: [Styling solution]
- Testing: Vitest [version]

## Project Structure

```
src/
├── routes/          # File-based routing
├── lib/             # Shared code
│   ├── components/  # Reusable components
│   ├── server/      # Server-only code
│   └── stores/      # Svelte stores
└── app.html         # HTML template
```

## Key Conventions

### Routes
[Your routing patterns]

### Load Functions
[Your data loading patterns]

### Form Actions
[Your form handling]

### Stores
[Your store patterns]

## Common Commands
- Dev: `npm run dev`
- Build: `npm run build`
- Preview: `npm run preview`
- Test: `npm test`
- Lint: `npm run lint`

## Environment Variables
[List required env vars]
```

## NestJS

```markdown
# [Project Name] - AI Agent Guide

## Project Overview
[Description]

## Tech Stack
- Framework: NestJS [version]
- Language: TypeScript [version]
- Database: [Database] via TypeORM/Prisma
- Testing: Jest [version]
- Task Queue: [Bull/etc]

## Project Structure

```
src/
├── modules/          # Feature modules
│   ├── users/
│   ├── auth/
│   └── [feature]/
├── common/           # Shared code
│   ├── decorators/
│   ├── filters/
│   ├── guards/
│   ├── interceptors/
│   └── pipes/
└── config/           # Configuration
```

## Key Conventions

### Module Organization
[Your module patterns]

### Dependency Injection
[Your DI patterns]

### Guards & Interceptors
[Your middleware patterns]

### DTOs & Validation
[Your validation patterns]

## Common Commands
- Dev: `npm run start:dev`
- Build: `npm run build`
- Start: `npm run start:prod`
- Test: `npm test`
- Migrate: `npm run migration:run`

## Environment Variables
[List required env vars]
```

## Angular

```markdown
# [Project Name] - AI Agent Guide

## Project Overview
[Description]

## Tech Stack
- Framework: Angular [version]
- Language: TypeScript [version]
- State: [NgRx/Akita/etc]
- Styling: [SCSS/CSS]
- Testing: Jasmine + Karma

## Project Structure

```
src/
├── app/
│   ├── core/        # Singleton services, guards
│   ├── shared/      # Shared components, directives
│   ├── features/    # Feature modules
│   └── [feature]/
└── assets/          # Static assets
```

## Key Conventions

### Module Organization
[Your module patterns]

### Services
[Your service patterns]

### Components
[Your component patterns]

### State Management
[Your state patterns]

## Common Commands
- Dev: `ng serve`
- Build: `ng build`
- Test: `ng test`
- E2E: `ng e2e`
- Lint: `ng lint`

## Environment Variables
[Environment config approach]
```

## Usage Notes

1. **Choose your framework template** from above
2. **Check Context7 availability** - Run `mcp__context7__list_knowledge_bases` to see available frameworks
3. **Use Context7 when available** - Replace static docs with Context7 commands
4. **Fill in the bracketed placeholders** with your project specifics
5. **Add framework version documentation** only if Context7 doesn't cover your version
6. **Customize conventions** to match your team's practices
7. **Keep under 10KB** - Context7 eliminates need for large static indexes
8. **Add retrieval instruction** - Always include "Prefer Context7/retrieval over pre-training"

## Context7 Command Reference

### Check Available Knowledge Bases
```bash
mcp__context7__list_knowledge_bases
```

### Query Documentation
```bash
mcp__context7__query_knowledge_base knowledge_base="[framework]" query="[question]"
```

### Common Knowledge Bases
- Frontend: `nextjs`, `react`, `vue`, `angular`, `svelte`
- Backend: `django`, `fastapi`, `flask`, `express`, `nestjs`
- Database: `postgresql`, `mongodb`, `redis`, `prisma`
- Styling: `tailwindcss`, `bootstrap`
- Mobile: `react-native`, `expo`
- Tools: `typescript`, `webpack`, `vite`

### Best Practices
- Be specific in your queries: "Next.js server components" vs "components"
- Include version when relevant: "Next.js 16 use cache directive"
- Ask about specific APIs: "FastAPI dependency injection" vs "dependencies"
- Query multiple bases for complex topics: Use both `nextjs` and `react` for React Server Components

## Multi-Framework Projects

For projects using multiple frameworks:

```markdown
# Multi-Framework Project - AI Agent Guide

## Project Overview
[Description]

## Tech Stack by Component

**Frontend (Next.js):**
- Framework: Next.js [version]
- See `frontend/AGENTS.md` for details

**Backend (FastAPI):**
- Framework: FastAPI [version]
- See `backend/AGENTS.md` for details

**Mobile (React Native):**
- Framework: Expo [version]
- See `mobile/AGENTS.md` for details

## Monorepo Commands
[Root-level commands]

## Shared Conventions
[Cross-cutting concerns]
```

Each sub-project should have its own AGENTS.md with framework-specific details.
