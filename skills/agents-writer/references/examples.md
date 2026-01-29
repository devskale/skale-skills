# AGENTS.md Complete Examples

Full, production-ready AGENTS.md examples for different project types.

## Example 1: Next.js 16 Full-Stack App

```markdown
# E-Commerce Platform - AI Agent Guide

## Project Overview
Full-stack e-commerce platform with Next.js 16 App Router frontend, Express backend API, PostgreSQL database via Prisma, and Stripe payment processing.

## Tech Stack
- Framework: Next.js 16.0.0 (App Router)
- Language: TypeScript 5.3
- Styling: Tailwind CSS 3.4
- Database: PostgreSQL 16 via Prisma 5.8
- Auth: NextAuth.js v5
- Payments: Stripe SDK 14.0
- Testing: Jest 29 + React Testing Library

## Next.js 16 Documentation

**Use Context7 MCP for Next.js documentation (recommended):**

```bash
# Query Next.js APIs and patterns
mcp__context7__query_knowledge_base knowledge_base="nextjs" query="use cache directive"
mcp__context7__query_knowledge_base knowledge_base="nextjs" query="server components"
mcp__context7__query_knowledge_base knowledge_base="nextjs" query="connection function"
mcp__context7__query_knowledge_base knowledge_base="nextjs" query="forbidden unauthorized"

# Query related libraries
mcp__context7__query_knowledge_base knowledge_base="react" query="useEffect hook"
mcp__context7__query_knowledge_base knowledge_base="prisma" query="relation queries"
```

**IMPORTANT:** Prefer Context7 retrieval over pre-training knowledge for Next.js 16 APIs.

**Alternative (if Context7 unavailable):** Static docs index in `.next-docs/`:

[Next.js 16 Docs]|root:./.next-docs
|app/getting-started:{installation.mdx,project-structure.mdx,configuration.mdx}
|app/routing:{defining-routes.mdx,pages-layouts.mdx,dynamic-routes.mdx,route-groups.mdx}
|app/data-fetching:{server-actions.mdx,caching.mdx,use-cache.mdx,connection.mdx}
|app/rendering:{server-components.mdx,client-components.mdx,composition.mdx}
|app/functions:{forbidden.mdx,unauthorized.mdx,after.mdx,cookies.mdx,headers.mdx}
|app/caching:{cacheLife.mdx,cacheTag.mdx,updateTag.mdx}

## Architecture

```
src/
├── app/              # Next.js App Router pages and layouts
│   ├── (auth)/      # Auth route group (login, signup)
│   ├── (shop)/      # Main shop routes
│   └── api/         # API routes (proxy to backend)
├── components/       # React components
│   ├── ui/          # Base UI (buttons, inputs, cards)
│   └── features/    # Feature-specific (ProductCard, Cart)
├── lib/             # Utilities and shared logic
│   ├── db.ts        # Prisma client
│   ├── auth.ts      # NextAuth config
│   └── stripe.ts    # Stripe client
├── types/           # TypeScript definitions
└── actions/         # Server Actions
```

Backend API runs separately on port 3001, accessed via proxy.

## Key Conventions

### Server Components by Default
All components are Server Components unless marked with `'use client'`. Use client components only for:
- Interactive elements (forms, buttons with onClick)
- Browser APIs (localStorage, geolocation)
- React hooks (useState, useEffect)

### Data Fetching
```typescript
// Cached data fetching
async function getProducts() {
  'use cache'
  cacheTag('products')
  cacheLife('minutes', 5)
  
  return await db.products.findMany()
}

// Dynamic (non-cached)
async function getCurrentUser() {
  await connection() // Force dynamic
  const session = await auth()
  return session?.user
}
```

### Server Actions
Place in `src/actions/` with `'use server'`:
```typescript
'use server'

export async function createProduct(data: ProductInput) {
  await db.products.create({ data })
  updateTag('products') // Revalidate cache
  redirect('/admin/products')
}
```

### Error Handling
- Use `forbidden()` for 403 errors
- Use `unauthorized()` for 401 errors
- Create `error.tsx` for route-level error boundaries
- Create `not-found.tsx` for 404 pages

### File Naming
- Components: PascalCase (`ProductCard.tsx`)
- Utilities: camelCase (`formatPrice.ts`)
- Constants: SCREAMING_SNAKE_CASE (`API_BASE_URL`)
- Server Actions: camelCase (`createProduct.ts`)

### Code Style
- No `any` types - use `unknown` and narrow
- Async/await over promise chains
- Early returns over nested ifs
- Destructure props at parameter level

## Common Commands

Development: `npm run dev` (starts both Next.js and backend)
Build: `npm run build`
Test: `npm run test`
Test Watch: `npm run test:watch`
Lint: `npm run lint`
Type Check: `npm run type-check`

Database:
- Migrate: `npx prisma migrate dev`
- Generate: `npx prisma generate`
- Seed: `npm run db:seed`
- Studio: `npx prisma studio`

## Environment Variables

Required in `.env.local`:
- `DATABASE_URL` - PostgreSQL connection string
- `NEXTAUTH_SECRET` - Auth secret (32+ chars)
- `NEXTAUTH_URL` - App URL (http://localhost:3000 in dev)
- `STRIPE_SECRET_KEY` - Stripe secret key
- `STRIPE_PUBLISHABLE_KEY` - Stripe public key

## Common Tasks

### Creating a New Page
1. Create `src/app/[route]/page.tsx`
2. Export default async function component
3. Add metadata export for SEO
4. Use Server Components unless interactivity needed

### Adding an API Route
1. Create `src/app/api/[endpoint]/route.ts`
2. Export named functions: GET, POST, PUT, DELETE
3. Return Response objects with appropriate status
4. Use `NextRequest` and `NextResponse` types

### Creating a Server Action
1. Create file in `src/actions/[name].ts`
2. Add `'use server'` at top
3. Export async function
4. Use `revalidatePath()` or `updateTag()` for cache updates
5. Use `redirect()` for navigation after success

### Database Changes
1. Update `prisma/schema.prisma`
2. Run `npx prisma migrate dev --name [description]`
3. Run `npx prisma generate`
4. Update TypeScript types as needed

## Troubleshooting

**Hydration errors:** Server/client mismatch - check for `Date.now()`, `Math.random()`, or browser APIs in Server Components

**"use cache" not working:** Ensure function is async and tagged with `cacheTag()`

**Server Actions failing:** Verify `'use server'` directive and proper error handling

**Build errors:** Run `npm run type-check` to catch TypeScript issues before build
```

## Example 2: Python FastAPI Backend

```markdown
# Payment Processing API - AI Agent Guide

## Project Overview
RESTful API for payment processing built with FastAPI, handling transactions, webhooks, and reporting. Uses PostgreSQL for data persistence and Redis for caching.

## Tech Stack
- Framework: FastAPI 0.109.0
- Language: Python 3.12
- Database: PostgreSQL 16 via SQLAlchemy 2.0
- Cache: Redis 7.2 via redis-py
- Task Queue: Celery 5.3 with Redis broker
- Testing: pytest 8.0 + httpx

## Project Structure

```
src/
├── api/              # API routes
│   ├── v1/          # API v1 endpoints
│   │   ├── payments.py
│   │   ├── webhooks.py
│   │   └── reports.py
│   └── deps.py      # Dependencies (DB sessions, auth)
├── models/          # SQLAlchemy models
├── schemas/         # Pydantic schemas
├── services/        # Business logic
├── tasks/           # Celery tasks
└── core/            # Config, security, database
```

## Framework Documentation

**Use Context7 MCP for framework documentation:**

```bash
# FastAPI queries
mcp__context7__query_knowledge_base knowledge_base="fastapi" query="dependency injection"
mcp__context7__query_knowledge_base knowledge_base="fastapi" query="async route handlers"

# Python queries
mcp__context7__query_knowledge_base knowledge_base="python" query="async await patterns"
mcp__context7__query_knowledge_base knowledge_base="python" query="type hints"

# Database queries
mcp__context7__query_knowledge_base knowledge_base="postgresql" query="connection pooling"
```

**IMPORTANT:** Prefer Context7 retrieval over pre-training knowledge.

## Key Conventions

### File Organization
- Routes: `/src/api/v1/[resource].py` - One file per resource
- Models: `/src/models/[resource].py` - SQLAlchemy ORM models
- Schemas: `/src/schemas/[resource].py` - Pydantic for validation
- Services: `/src/services/[resource]_service.py` - Business logic
- Tests: `/tests/[module]/test_[feature].py` - Mirror src structure

### Code Style
- Type hints required on all functions
- Docstrings in Google format
- Black formatting (line length 88)
- isort for import sorting
- No wildcard imports

### Async Patterns
```python
# Use async for I/O-bound operations
async def get_payment(payment_id: int, db: AsyncSession):
    result = await db.execute(
        select(Payment).where(Payment.id == payment_id)
    )
    return result.scalar_one_or_none()

# Use sync for CPU-bound operations
def calculate_fees(amount: Decimal) -> Decimal:
    return amount * Decimal("0.029") + Decimal("0.30")
```

### Error Handling
```python
# Use HTTPException for API errors
from fastapi import HTTPException, status

if not payment:
    raise HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail="Payment not found"
    )

# Use custom exceptions for business logic
class InsufficientFundsError(Exception):
    pass
```

### Dependency Injection
```python
# Use FastAPI dependencies
from fastapi import Depends
from api.deps import get_db, get_current_user

@router.post("/payments/")
async def create_payment(
    payment: PaymentCreate,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user)
):
    return await payment_service.create(db, payment, user)
```

## Common Commands

Setup: `python -m venv venv && source venv/bin/activate && pip install -r requirements.txt`
Dev: `uvicorn src.main:app --reload`
Test: `pytest`
Test Coverage: `pytest --cov=src --cov-report=html`
Lint: `ruff check src/`
Format: `black src/ && isort src/`
Type Check: `mypy src/`

Database:
- Migrate: `alembic upgrade head`
- Create Migration: `alembic revision --autogenerate -m "[description]"`
- Rollback: `alembic downgrade -1`

## Environment Variables

Required in `.env`:
- `DATABASE_URL` - PostgreSQL connection (async driver)
- `REDIS_URL` - Redis connection string
- `SECRET_KEY` - JWT signing key (64+ chars)
- `STRIPE_SECRET_KEY` - Stripe API key
- `STRIPE_WEBHOOK_SECRET` - Webhook signature key

## Common Tasks

### Adding a New Endpoint
1. Create route in `src/api/v1/[resource].py`
2. Define Pydantic schema in `src/schemas/[resource].py`
3. Add service logic in `src/services/[resource]_service.py`
4. Write tests in `tests/api/v1/test_[resource].py`
5. Update API docs (automatic via FastAPI)

### Database Changes
1. Update model in `src/models/[resource].py`
2. Update schema in `src/schemas/[resource].py`
3. Run `alembic revision --autogenerate -m "[description]"`
4. Review migration in `alembic/versions/`
5. Run `alembic upgrade head`

### Adding Background Task
1. Create task in `src/tasks/[name].py`
2. Decorate with `@celery_app.task`
3. Call with `.delay()` or `.apply_async()`
4. Monitor with Flower: `celery -A src.tasks flower`

## Testing Guidelines

- Use `pytest` fixtures for DB sessions and clients
- Mock external services (Stripe, email)
- Use `httpx.AsyncClient` for API testing
- Aim for 80%+ coverage
- Test happy path and error cases

## Documentation

API docs available at:
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc
- OpenAPI JSON: http://localhost:8000/openapi.json
```

## Example 3: React Native Mobile App

```markdown
# Fitness Tracker - AI Agent Guide

## Project Overview
Cross-platform mobile fitness tracking app built with React Native and Expo. Tracks workouts, nutrition, and progress with offline support and cloud sync.

## Tech Stack
- Framework: Expo 50 (React Native 0.73)
- Language: TypeScript 5.3
- State: Redux Toolkit 2.0 + RTK Query
- Navigation: React Navigation 6
- Database: WatermelonDB (SQLite)
- Backend: Firebase (Auth, Firestore, Storage)
- Testing: Jest + React Native Testing Library

## Project Structure

```
src/
├── screens/         # Screen components
├── components/      # Reusable components
├── navigation/      # Navigation config
├── store/          # Redux store, slices, API
├── models/         # WatermelonDB models
├── services/       # Firebase, sync, analytics
├── hooks/          # Custom hooks
├── utils/          # Helper functions
└── types/          # TypeScript types
```

## Key Conventions

### Component Organization
```typescript
// Screens in src/screens/[Feature]/[Screen]Screen.tsx
export default function WorkoutScreen() { ... }

// Components in src/components/[Feature]/[Component].tsx
export function WorkoutCard({ workout }: Props) { ... }

// Shared UI in src/components/ui/
export function Button({ onPress, children }: Props) { ... }
```

### State Management
```typescript
// Redux slices in src/store/slices/
import { createSlice } from '@reduxjs/toolkit'

// RTK Query APIs in src/store/api/
export const workoutsApi = createApi({ ... })

// Use hooks from React Redux
const dispatch = useAppDispatch()
const workouts = useAppSelector(selectWorkouts)
```

### Navigation
```typescript
// Type-safe navigation
import type { NativeStackScreenProps } from '@react-navigation/native-stack'

type Props = NativeStackScreenProps<RootStackParamList, 'Workout'>

export default function WorkoutScreen({ navigation, route }: Props) {
  navigation.navigate('WorkoutDetail', { id: workout.id })
}
```

### Database (WatermelonDB)
```typescript
// Define models with decorators
import { Model, field, date } from '@nozbe/watermelondb/decorators'

class Workout extends Model {
  static table = 'workouts'
  
  @field('name') name!: string
  @date('created_at') createdAt!: Date
}
```

### Styling
- Use StyleSheet.create() for performance
- Theme values from src/theme/colors.ts
- Responsive with useWindowDimensions()
- Platform-specific styles with Platform.select()

### File Naming
- Screens: PascalCase with "Screen" suffix
- Components: PascalCase
- Hooks: camelCase with "use" prefix
- Utils: camelCase
- Tests: [name].test.tsx

## Common Commands

Start: `npx expo start`
iOS: `npx expo start --ios`
Android: `npx expo start --android`
Web: `npx expo start --web`

Build:
- iOS: `eas build --platform ios`
- Android: `eas build --platform android`

Test: `npm test`
Test Watch: `npm test -- --watch`
Lint: `npm run lint`
Type Check: `npm run type-check`

## Environment Variables

In `.env`:
- `EXPO_PUBLIC_FIREBASE_API_KEY` - Firebase API key
- `EXPO_PUBLIC_FIREBASE_AUTH_DOMAIN` - Auth domain
- `EXPO_PUBLIC_FIREBASE_PROJECT_ID` - Project ID
- `EXPO_PUBLIC_API_URL` - Backend API URL

Note: Only vars prefixed with `EXPO_PUBLIC_` are exposed to app.

## Platform-Specific Notes

### iOS
- Minimum version: iOS 13
- Use SafeAreaView for notch devices
- Test on both iPhone and iPad
- Handle keyboard with KeyboardAvoidingView

### Android
- Minimum SDK: 21 (Android 5.0)
- Handle back button with BackHandler
- Test different screen sizes
- Request permissions at runtime

## Common Tasks

### Adding a New Screen
1. Create screen in `src/screens/[Feature]/[Name]Screen.tsx`
2. Add to navigation in `src/navigation/[Navigator].tsx`
3. Add TypeScript types to navigation params
4. Create tests in `src/screens/[Feature]/__tests__/`

### Adding Redux Slice
1. Create slice in `src/store/slices/[name]Slice.ts`
2. Add to store in `src/store/index.ts`
3. Export selectors and actions
4. Use in components with hooks

### Database Migration
1. Update schema in `src/models/schema.ts`
2. Increment schema version
3. Add migration in `src/models/migrations.ts`
4. Test on both platforms

### Adding Native Module
1. Install: `npx expo install [package]`
2. Configure in `app.json` if needed
3. Add TypeScript types
4. Test on both iOS and Android
5. Handle permissions if required

## Offline Support

App works offline with WatermelonDB local storage:
- All data cached locally
- Changes synced when online
- Optimistic updates for better UX
- Conflict resolution on sync

Sync strategy:
- Manual: Pull to refresh
- Automatic: On app open and every 5 minutes
- Background: When app returns to foreground

## Testing Guidelines

- Test components with React Native Testing Library
- Mock navigation with `@react-navigation/native`
- Mock Firebase with `firebase-mock`
- Test on both iOS and Android simulators
- Use `waitFor` for async operations

## Troubleshooting

**Metro bundler issues:** Clear cache with `npx expo start --clear`

**Build failures:** Check `eas.json` and run `eas build --platform all --clear-cache`

**Navigation errors:** Ensure types match between navigator config and screen props

**Database errors:** Reset with `db.write(async () => await db.unsafeResetDatabase())`
```

## Example 4: Monorepo with Multiple Apps

```markdown
# SaaS Platform - AI Agent Guide

## Project Overview
Multi-tenant SaaS platform with separate web app, admin dashboard, marketing site, and shared packages. Uses Turborepo for build orchestration.

## Workspace Structure

```
apps/
├── web/             # Main web app (Next.js) - See apps/web/AGENTS.md
├── admin/           # Admin dashboard (Next.js) - See apps/admin/AGENTS.md  
├── marketing/       # Marketing site (Astro) - See apps/marketing/AGENTS.md
├── mobile/          # Mobile app (Expo) - See apps/mobile/AGENTS.md
└── api/             # Backend API (Fastify) - See apps/api/AGENTS.md

packages/
├── ui/              # Shared React components
├── config/          # Shared configs (ESLint, TS, Tailwind)
├── database/        # Prisma schema and client
├── auth/            # Auth utilities (shared between apps)
└── utils/           # Shared utilities

Each app has its own AGENTS.md with app-specific details.
```

## Tech Stack

**Shared:**
- Monorepo: Turborepo 1.11
- Language: TypeScript 5.3
- Package Manager: pnpm 8.14
- Database: PostgreSQL 16 via Prisma

**Per-App:** See individual app AGENTS.md files

## Monorepo Conventions

### Package References
```json
// In app package.json
{
  "dependencies": {
    "@repo/ui": "workspace:*",
    "@repo/database": "workspace:*"
  }
}
```

### Shared Configuration
- ESLint: Extends `@repo/config/eslint`
- TypeScript: Extends `@repo/config/typescript`  
- Tailwind: Imports from `@repo/config/tailwind`

### Versioning
- Apps: Independent versions
- Packages: Synchronized versions
- Update all with `pnpm run version`

## Common Commands

**Root level:**
- Dev (all): `pnpm dev`
- Build (all): `pnpm build`
- Test (all): `pnpm test`
- Lint (all): `pnpm lint`
- Type check: `pnpm type-check`
- Clean: `pnpm clean`

**Workspace-specific:**
- Dev one app: `pnpm dev --filter=web`
- Build one app: `pnpm build --filter=admin`
- Test one package: `pnpm test --filter=@repo/ui`

**Dependencies:**
- Add to app: `pnpm add [package] --filter=web`
- Add workspace package: `pnpm add @repo/ui --filter=admin`
- Update all: `pnpm up -r`

## Key Conventions

### Import Paths
```typescript
// Workspace packages
import { Button } from '@repo/ui'
import { db } from '@repo/database'

// Within app - use relative paths
import { Header } from '@/components/Header'
import { formatDate } from '@/utils/date'
```

### Code Sharing
- UI components: `@repo/ui`
- Business logic: `@repo/utils`
- Database: `@repo/database` (single Prisma schema)
- Config: `@repo/config` (ESLint, TS, Tailwind)

### File Locations
- Shared types: `packages/types/src/`
- Shared constants: `packages/utils/src/constants.ts`
- API types: `packages/api-types/src/`

## Database

Single Prisma schema in `packages/database/prisma/schema.prisma` shared across all apps.

Migrations:
- Create: `pnpm --filter=@repo/database db:migrate:dev`
- Deploy: `pnpm --filter=@repo/database db:migrate:deploy`
- Generate: `pnpm --filter=@repo/database db:generate`

All apps import from `@repo/database`:
```typescript
import { db } from '@repo/database'
```

## Deployment

**Web & Admin (Vercel):**
- Deploy: Automatic on push to main
- Preview: Automatic on PR
- Env vars: Set in Vercel dashboard

**API (Railway):**
- Deploy: Automatic on push to main
- Database: Provisioned by Railway
- Env vars: Set in Railway dashboard

**Marketing (Netlify):**
- Deploy: Automatic on push to main
- Build: `pnpm build --filter=marketing`

## App-Specific Documentation

For detailed app-specific guidance, see:
- Web app: `apps/web/AGENTS.md`
- Admin dashboard: `apps/admin/AGENTS.md`
- Marketing site: `apps/marketing/AGENTS.md`
- Mobile app: `apps/mobile/AGENTS.md`
- API: `apps/api/AGENTS.md`

Each contains framework-specific conventions, commands, and patterns.

## Troubleshooting

**Workspace dependency not updating:** Run `pnpm install` from root

**Type errors after schema change:** Run `pnpm db:generate` and restart TS server

**Build cache issues:** Run `pnpm clean && pnpm build`

**Port conflicts:** Check `.env` files - each app uses different port
```

## Summary

These examples demonstrate:

1. **Size management** - All under 5KB, easily scannable
2. **Framework versioning** - Exact versions specified
3. **Retrieval instruction** - "Prefer retrieval-led reasoning" prominent
4. **Compressed indexes** - Pipe-delimited format for documentation
5. **Clear structure** - Consistent sections across examples
6. **Practical guidance** - Real commands and patterns
7. **No bloat** - Essential information only

Adapt these templates to your specific project, maintaining the core principles of conciseness, specificity, and scannability.
