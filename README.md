# TCG Platform Monorepo

Crane rental platform. One pnpm workspace, four projects, orchestrated by [Nx](https://nx.dev).

| Project        | Package       | Stack                                             | Path               | Port |
| -------------- | ------------- | ------------------------------------------------- | ------------------ | ---- |
| API            | `@tcg/api`    | NestJS 11 · Prisma 7 · PostgreSQL                 | `apps/api/`        | 3000 |
| Web            | `@tcg/web`    | Next.js 16 (App Router) · Tailwind v4 · shadcn/ui | `apps/web/`        | 3001 |
| Mobile         | `@tcg/mobile` | Expo SDK 54 · Expo Router                         | `apps/mobile/`     | 8081 |
| Shared library | `@tcg/shared` | Pure TypeScript — types, enums, constants, utils  | `packages/shared/` | —    |

Every app depends on `@tcg/shared` (`workspace:*`) and consumes it as a **built package**
(`packages/shared/dist`). You never build it by hand — Nx does, before any task that needs it.

---

## Prerequisites

| Tool                   | Version                | Notes                                                                                                      |
| ---------------------- | ---------------------- | ---------------------------------------------------------------------------------------------------------- |
| Node.js                | **22.22.0** (`.nvmrc`) | `.npmrc` sets `use-node-version=22.22.0`, so pnpm fetches and uses it automatically. `nvm use` also works. |
| pnpm                   | **10.30.2**            | pinned in `package.json` → `packageManager`. Easiest: `corepack enable` (ships with Node).                 |
| PostgreSQL             | 15+                    | local install, or the `postgres` service from `docker-compose.dev.yml` (see below).                        |
| Docker                 | optional               | only for the containerised dev stack / local image builds.                                                 |
| Xcode / Android Studio | optional               | only to run the mobile app on a simulator/emulator; Expo Go on a phone works without them.                 |

```bash
corepack enable            # pnpm at the pinned version
git clone <repository-url> craneguys-platform
cd craneguys-platform
pnpm install               # installs every workspace; wires the git hooks
```

> `pnpm install` must be run from the repo root. Never `npm install` inside an app.

---

## Quick start

### 1. Environment files

Each app reads **its own** env files. The root `.env` is used only by `docker compose` for
variable substitution — no app loads it.

```bash
cp apps/api/.env.example    apps/api/.env          # read by the API, Prisma and the db:* scripts
cp apps/web/.env.example    apps/web/.env.local
cp apps/mobile/.env.example apps/mobile/.env.local
```

> Use `apps/api/.env`, not `.env.development`: Prisma (`prisma.config.ts`) and `pnpm db:recover`
> only read `apps/api/.env`. The API itself reads `.env.<NODE_ENV>` first and then `.env`, so a
> `.env.development` is an optional overlay, never a replacement.

The API validates its env on boot (`apps/api/src/config/env.validation.ts`) and refuses to start
if any of these are missing — the example file leaves the secrets blank, so fill in:

| Key                                                                              | Local value                                                                                                                   |
| -------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| `DATABASE_URL`                                                                   | `postgresql://postgres:postgres@localhost:5432/tcg_db` (port = your Postgres)                                                 |
| `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`                                        | any string **≥ 32 characters** each                                                                                           |
| `JWT_ACCESS_EXPIRATION`, `JWT_REFRESH_EXPIRATION`                                | already set in the example (`15m`, `7d`)                                                                                      |
| `NODE_ENV`, `PORT`, `CORS_ORIGIN`                                                | `development`, `3000`, `http://localhost:3001` (already in the example)                                                       |
| `AWS_REGION`, `AWS_S3_BUCKET_NAME`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` | required even locally; dummy values (`us-east-1`, `local`, `local`, `local`) let the API boot — uploads/email just won't work |

Clients: `NEXT_PUBLIC_API_URL` and `EXPO_PUBLIC_API_URL` default to `http://localhost:3000/api/v1`
in the examples; for a phone on Expo Go use your machine's LAN IP instead of `localhost`. Full key
lists are in [Environment configuration](#environment-configuration).

### 2. Database

Either a local PostgreSQL, or just the DB container:

```bash
docker compose -f docker-compose.dev.yml up -d postgres   # tcg_db on localhost:5432, postgres/postgres
```

> Compose reads the root `.env` for substitution: if it sets `POSTGRES_PORT` (e.g. `5433`), the
> container is published on that port and your `DATABASE_URL` in `apps/api/.env` must match.

Then, from the repo root:

```bash
pnpm db:generate     # Prisma client
pnpm db:recover      # existing local DB after a pull (safe re-sync of migrations)
# — or —
pnpm db:reset        # fresh database (drops data), then:
pnpm db:seed         # optional demo data
```

### 3. Run the apps

Each command builds `@tcg/shared` first (or restores it from cache) and then starts the app.
Open one terminal per app:

```bash
pnpm api:dev         # http://localhost:3000        Swagger: /api/docs   Health: /api/v1/health
pnpm web:dev         # http://localhost:3001
pnpm mobile:start    # Expo dev server on :8081 — press i / a for simulator, or scan the QR in Expo Go
```

One-shot for API-only work (lint shared+api, generate client, regenerate DBML, recover
migrations, start API):

```bash
pnpm local:all
```

---

## Everyday commands

All commands run from the repo root. Script names have not changed for years — they now go
through Nx, which adds ordering, caching and parallelism (see [Task runner](#task-runner-nx)).

### Per app

```bash
# API
pnpm api:dev | api:build | api:start | api:lint | api:lint:fix | api:test

# Web
pnpm web:dev | web:build | web:start | web:lint | web:clean       # web:clean wipes .next-dev (+ legacy .next/dev/cache)

# Mobile
pnpm mobile:start | mobile:android | mobile:ios | mobile:lint

# Shared
pnpm shared:build                                                    # rarely needed by hand — Nx does it
```

Anything else in an app's `package.json` is reachable as an Nx target, e.g.
`pnpm nx run @tcg/api:test:cov`, `pnpm nx run @tcg/api:start:debug`, `pnpm nx run @tcg/web:lint:fix`,
`pnpm nx run @tcg/mobile:typecheck`, or the old way, `pnpm --filter @tcg/api test:e2e`.

### Database (Prisma, all target `apps/api`)

```bash
pnpm db:generate       # prisma generate
pnpm db:migrate        # prisma migrate dev  — creates + applies a migration; COMMIT the SQL
pnpm db:deploy         # prisma migrate deploy (what deploy uses)
pnpm db:recover        # re-sync a local DB whose migration history drifted (P3009 etc.)
pnpm db:reset          # drop + recreate (destructive)
pnpm db:seed           # prisma db seed
pnpm db:studio         # Prisma Studio
pnpm db:dbml           # regenerate prisma/schema.dbml
pnpm db:squash-resolve # baseline helper — see apps/api/prisma/MIGRATION_BASELINE.md
```

### Whole workspace

```bash
pnpm build       # every project that has a build, in dependency order, cached
pnpm lint        # every project (currently fails on pre-existing errors in apps/web — check whether a failure is yours)
pnpm test        # api (jest), web (node --test), mobile (jest)
pnpm typecheck   # web + mobile (tsc --noEmit)
pnpm affected    # lint + build + test only for projects changed vs main
pnpm graph       # project graph in the browser
pnpm nx:reset    # wipe .nx/cache and restart the Nx daemon
pnpm clean       # nx reset + remove every dist/ and node_modules/
```

---

## Task runner (Nx)

The workspace is orchestrated by Nx in **package-based mode**: nothing about how the apps are
built changed — `nest`, `next` and `expo` run exactly as before — Nx sits on top and owns
**task ordering**, **caching**, and **affected-only runs**.

- **Ordering** — `build`, `dev`, `start`, `test` and `typecheck` depend on `^build`, so
  `@tcg/shared` is always built (or restored from cache) before an app that imports it.
- **Caching** — `build`, `lint`, `test`, `typecheck` are cached in `.nx/cache` (git-ignored).
  Unchanged projects are replayed instead of re-run. Second `pnpm build` on a clean tree: ~4 s
  instead of ~3 min.
- **Affected** — `pnpm affected` runs only what a change touches, relative to `main`. PRs run
  the same via [`.github/workflows/affected.yml`](.github/workflows/affected.yml) (lint excludes
  `@tcg/web` until its pre-existing ESLint errors are fixed).
- **Security overrides** live in [`pnpm-workspace.yaml`](pnpm-workspace.yaml) (`overrides` /
  `peerDependencyRules`). pnpm 10 ignores a `pnpm` key in `package.json`.

Where the config lives: [`nx.json`](nx.json) for workspace-wide rules (`targetDefaults`,
`namedInputs`); the `"nx"` key in each project's `package.json` for per-project overrides. Every
`package.json` script is automatically a target — no registration step.

```bash
pnpm nx run @tcg/api:build                          # one target
pnpm nx run-many -t lint -p @tcg/web @tcg/mobile    # a target on some projects
pnpm nx run @tcg/api:build --skip-nx-cache          # force a real run
pnpm nx show project @tcg/web                       # what Nx resolved (targets, inputs, outputs)
pnpm nx show projects --affected                    # which projects a change touches
```

**Rules to keep it working**

1. **Always invoke Nx as `pnpm nx …`, never `npx nx` or a global `nx`.** The root `nx` script
   sets `NX_LOAD_DOT_ENV_FILES=false`. Without it Nx injects the workspace-root `.env` (the
   API's env, incl. `NODE_ENV`) into every task, which breaks `next build`. Each app keeps
   reading its own `.env*` exactly as before.
2. **`@tcg/shared` is consumed as built `dist/`** by every app via its `package.json` `exports`.
   Never alias it to `src` in a tsconfig. Editing shared while an app is running? keep
   `pnpm --filter @tcg/shared dev` (`tsc --watch`) open in another terminal.
3. **Adding a script to a `package.json`?** It is an Nx target immediately. If it produces
   files, add `outputs` (per-project `nx` key); if it should be cached, make sure a
   `targetDefaults` entry in `nx.json` covers it. Anything that mutates the tree (`--fix`,
   codegen into `src`) must stay `cache: false`.
4. **Adding a `NEXT_PUBLIC_*` variable to web?** Add it to `build.inputs` in
   `apps/web/package.json` — those values are inlined at build time and are part of the cache
   key. Miss it and a cached web build can be stale.
5. **Adding a workspace (`apps/*` or `packages/*`)?** `pnpm install` + a `package.json` with a
   `name` is enough. Depend on other workspaces with `workspace:*`. Toolchain deps
   (`typescript`, `eslint`, `prettier`, `@types/node`, …) must reference the `catalog:` in
   [`pnpm-workspace.yaml`](pnpm-workspace.yaml), not a version. (`@tcg/mobile`'s
   `typescript`/`react`/`jest` are the deliberate exception — Expo pins them.)
6. **Docker image builds do not use Nx.** `apps/*/Dockerfile` and `deploy/deploy.sh` call
   `pnpm --filter … build` directly, on purpose. PR CI _does_ use Nx (`affected` lint/build/test).

If a cached result ever looks wrong: `pnpm nx:reset`, re-run with `--skip-nx-cache`, and if the
two differ an input is missing from `nx.json` / the project's `nx` block — fix the input, don't
disable the cache.

---

## Environment configuration

Only `.env.example` files are committed. Real env files are git-ignored.

### API — `apps/api/.env` (optionally overlaid by `apps/api/.env.<NODE_ENV>`)

The API loads `.env.<NODE_ENV>` first, then `.env`, from `apps/api/`; Prisma and the `db:*`
scripts read only `.env`. Copy `apps/api/.env.example` to `apps/api/.env`; the important groups are:

| Group          | Keys                                                                                                                                                                                        |
| -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| App            | `PORT` (3000), `NODE_ENV`, `CORS_ORIGIN`, `COOKIE_DOMAIN`, `FRONTEND_URL`, `API_URL`                                                                                                        |
| Database       | `DATABASE_URL` — `postgresql://user:password@host:5432/tcg_db`                                                                                                                              |
| Auth           | `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET` (each ≥ 32 chars), `JWT_ACCESS_EXPIRATION`, `JWT_REFRESH_EXPIRATION`, `JWT_REFRESH_EXPIRATION_REMEMBER` (no code fallbacks — expiries are config) |
| Email / SMS    | `AWS_REGION`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `SES_FROM_EMAIL`, `SNS_SMS_ORIGINATION_NUMBER`, `DEFAULT_PHONE_COUNTRY`                                                         |
| Push           | `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY` (or `FIREBASE_SERVICE_ACCOUNT_PATH`)                                                                                 |
| Integrations   | `AZURE_*` (Microsoft sign-in), `DOCUSIGN_*`, `BUGSNAG_API_KEY`, `NEW_RELIC_*`                                                                                                               |
| Business rules | `QUOTATION_APPROVAL_TOTAL_THRESHOLD`, `QUOTATION_*_REMINDER_DAYS`, `DISPATCH_DEPARTMENT_CODE`, `HR_DEPARTMENT_CODE`, `TICKET_REMINDER_TIMEZONE`, `CRON_TRIGGER_SECRET`                      |

### Web — `apps/web/.env.local`

`NEXT_PUBLIC_API_URL` (include the prefix: `http://localhost:3000/api/v1`), `NEXT_PUBLIC_SOCKET_URL`,
`NEXT_PUBLIC_API_PORT`, `NEXT_PUBLIC_APP_VERSION`, `NEXT_PUBLIC_RELEASE_STAGE`, plus
`NEXT_PUBLIC_BUGSNAG_API_KEY`, `NEXT_PUBLIC_NEW_RELIC_*`, `NEXT_PUBLIC_FIREBASE_*`. All of these
are build-time inputs (see Nx rule 4).

### Mobile — `apps/mobile/.env.local`

`EXPO_PUBLIC_API_URL` (include `/api/v1`; use your machine's LAN IP, not `localhost`, when
testing on a device). Data source switches: `EXPO_PUBLIC_DATA_SOURCE=mock|api` globally, or per
domain `EXPO_PUBLIC_DS_<DOMAIN>=mock|api` (`TICKETS`, `IDENTITY`, `NOTIFICATIONS`, `CUSTOMERS`,
`QUOTATIONS`, `JOBS`, `PROJECTS`, `DISPATCH`, …) — see `apps/mobile/data/config.ts`. Only the
field-ops domains have a backend today; sales/dispatch domains are mock-only.

---

## Project structure

```
craneguys-platform/
├── apps/
│   ├── api/                       NestJS — layered: presentation → usecase → service → orm (never import upward)
│   │   ├── src/
│   │   │   ├── presentation/<f>/   controllers + dto/
│   │   │   ├── usecase/<f>/        modules + services (business logic)
│   │   │   ├── service/<f>/        repositories (data access)
│   │   │   ├── orm/                PrismaService (tenant-scoping client extension), BaseRepository
│   │   │   ├── config/ context/ decorator/ filter/ guard/ interceptor/ strategy/ utility/
│   │   │   ├── app.module.ts  main.ts  setup-swagger.ts
│   │   ├── prisma/                 schema.prisma, migrations/, seed.ts, scripts/, MIGRATION_BASELINE.md
│   │   └── Dockerfile  Dockerfile.dev
│   ├── web/                       Next.js — feature-first
│   │   ├── src/
│   │   │   ├── app/                App Router routes (thin pages that delegate to features)
│   │   │   ├── features/<f>/       ~40 features: components/ hooks/ services|api/ views/ types/ utils/ schemas/
│   │   │   ├── components/         shared library — ui/ (shadcn, most used), patterns/, templates/, molecules/, …
│   │   │   ├── hooks/ lib/ layout/ providers/ styles/ types/ utils/
│   │   └── Dockerfile  Dockerfile.dev
│   └── mobile/                    Expo — persona-driven routing
│       ├── app/                    (auth) (common) (dev) (dispatch) (field) (onboarding) (sales) — groups are personas
│       ├── app-shell/ components/ data/ design-system/ features/ hooks/ lib/ providers/ session/
│       ├── ARCHITECTURE.md  app.json
│       └── Dockerfile  Dockerfile.dev
├── packages/
│   └── shared/                    @tcg/shared — src/{types,enums,constants,utils}, built to dist/
├── deploy/                        deploy.sh + config (GitHub Actions → AWS ECS)
├── docker-compose.yml             production-shaped stack (postgres, api, web, mobile, migrate)
├── docker-compose.dev.yml         hot-reload dev stack (+ ses-local)
├── nx.json  pnpm-workspace.yaml  tsconfig.base.json  .prettierrc  .prettierignore
└── package.json                   root scripts (everything above), lint-staged, engines
```

Import aliases: API `@orm/* @presentation/* @usecase/* @service/* @config/* @guard/* @decorator/*
@strategy/* @utility/* @filter/* @interceptor/* @context/*`; Web `@/*` → `./src/*`; Mobile
`@/*` → app root. `@tcg/shared` everywhere.

---

## Database

### Identity — UUID primary keys, per-tenant business codes

- Every business entity has a UUID `id` (`@id`) **and** a prefixed business code
  (`customerCode`, `quoteNo`, `unitCode`, …) that is unique **per tenant**:
  `@@unique([tenantCompanyId, <code>])`. Two tenants can both own `QUOT-00001`.
- Child tables reference parents by UUID, never by code.
- Routes and DTOs use the code for UX; the service resolves `(tenant, code) → id` once and works
  by UUID after that. New codes are minted from `entity_sequences`.
- Tables are `snake_case` plural via `@@map()`, columns `snake_case` via `@map()`, timestamps
  `@db.Timestamptz`.

### Tenant scoping

Multi-tenant. Scoping is applied by a Prisma **client extension** in
`apps/api/src/orm/prisma.service.ts` — it injects `tenantCompanyId` for models in its allowlist,
and skips scoping when there is no request context (cron, seeds), for `SUPER_ADMIN`, or for
models not in the list. Do not assume a query is scoped without checking.

### Migrations

- **Any schema change ships with a committed migration**: `pnpm db:migrate` with a descriptive
  name, commit the generated SQL alongside the feature.
- History is squashed into 3 baseline files under `apps/api/prisma/migrations/`; details and
  the recovery procedure are in `apps/api/prisma/MIGRATION_BASELINE.md`.
- After pulling: `pnpm db:recover`. If `pnpm local:all` fails with **P3009** or
  `relation "…" does not exist`, run `pnpm db:recover`.
- Fresh DB: `pnpm db:reset` then `pnpm db:seed`.

---

## Testing

```bash
pnpm test                                # all three, in parallel, cached
pnpm api:test                            # jest (apps/api/jest.config.cjs; specs are src/**/*.spec.ts)
pnpm nx run @tcg/api:test:cov            # coverage → apps/api/coverage
pnpm nx run @tcg/web:test                # node --test over *.test.mjs
pnpm nx run @tcg/mobile:test             # jest-expo
```

---

## Code quality

- **TypeScript**: strict, no `any`, named exports (Next.js pages excepted), JSDoc on public APIs.
- **Prettier**: one config, the root [`.prettierrc`](.prettierrc). Every app resolves it by
  walking up; do not add per-app copies. `.prettierignore` keeps the lockfile and build outputs
  untouched.
- **ESLint**: flat config per app (`apps/*/eslint.config.mjs`, `packages/shared/eslint.config.mjs`).
  `pnpm lint` runs all four; `pnpm api:lint` / `web:lint` / `mobile:lint` check,
  `…:lint:fix` fixes.
- **Typecheck**: `pnpm typecheck` (web + mobile).
- **Git hooks** are tracked files in [`.husky/`](.husky/) and run in the main checkout **and in
  every linked worktree** (`pnpm install` sets `core.hooksPath=.husky`, which is shared git
  config). They refuse to run ungated: a worktree without `node_modules` fails the commit with
  instructions — run `pnpm install` there first (fast, links from the shared store).
  - `pre-commit`: `lint-staged` only (ESLint `--fix` + Prettier on staged `apps/*/…ts,tsx` and
    `packages/shared/src/**`; Prettier on `json/md/yml`). No build — keeps commits cheap and
    avoids Nx cache restore stomping a live `web:dev` / `api:dev`.
  - `pre-push`: refuses a direct push of `main`; otherwise `nx affected -t lint --exclude=@tcg/web`
    (web's pre-existing lint errors), `nx affected -t typecheck --exclude=@tcg/mobile` (mobile's 2
    pre-existing TS errors), then `nx affected -t build`, all against `origin/main`.
    `SKIP_GATES=1 git push` skips the gates, never the branch guard. `--no-verify` skips everything —
    treat that as a decision, not a habit.

Naming: files `kebab-case`, classes `PascalCase`, functions `camelCase`, constants
`UPPER_SNAKE`, DB `snake_case` via `@map()`.

Web tables: two shells exist in `components/templates/` — `WorkspaceTable` and `CommonTable`.
Match the module you are working in. Whichever you use: enumerate every searchable field in
`searchPlaceholder`, and when select filters can yield zero rows, set an empty-state message
that names the filter.

---

## Docker & deployment

**Local containers** (both compose files read the root `.env` for substitution):

```bash
pnpm docker:dev        # docker-compose.dev.yml — postgres, api, web, mobile (hot reload) + ses-local
pnpm docker:dev:down
pnpm docker:up         # docker-compose.yml — production-shaped images (postgres, api, web, mobile, migrate)
pnpm docker:down | docker:build | docker:logs | docker:migrate
make help              # the same via Makefile targets (up, down, dev, migrate, seed, db-studio, …)
```

Images are built from `apps/api/Dockerfile`, `apps/web/Dockerfile`, `apps/mobile/Dockerfile`
(and their `.dev` variants). They pin pnpm via corepack and call `pnpm --filter … build`
directly — no Nx inside images. See `DOCKER.md`.

**Staging deploy**: `.github/workflows/deploy.yml` runs on every push to `main` and executes
`deploy/deploy.sh --tag=<sha> --build --migrate`, which builds the api and web images and
deploys them to AWS ECS. There is no Vercel deployment.

**Mobile builds**: EAS — `eas build --profile <development|preview|production>` from `apps/mobile/` (profiles in `eas.json`).

---

## Authentication

Dual-token JWT (access + refresh; refresh token hashed in the DB). Web uses http-only cookies;
mobile uses Bearer tokens stored in `expo-secure-store`. Expiries come from env — there are no
defaults in code.

`POST /api/v1/auth/signin` · `POST /auth/refresh` · `POST /auth/logout` ·
`POST /auth/forgot-password` · `POST /auth/reset-password` · `GET /auth/microsoft` (+ `/callback`) ·
mobile: `POST /auth/field/signin` · `POST /auth/field/refresh`.

Guards are global (`AccessTokenGuard`, `RolesGuard`, `PermissionsGuard`, `ThrottlerGuard`); opt
out with `@Public()`. Swagger UI at `http://localhost:3000/api/docs` (non-production).

---

## Troubleshooting

| Symptom                                                   | Do                                                                                                             |
| --------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| `P3009`, `relation "…" does not exist`, migration drift   | `pnpm db:recover` (see `apps/api/prisma/MIGRATION_BASELINE.md`)                                                |
| DB connection refused                                     | `pg_isready -h localhost -p 5432` (or your `POSTGRES_PORT`); check `DATABASE_URL` in `apps/api/.env`           |
| `DATABASE_URL is not set` from `pnpm db:*`                | the file must be `apps/api/.env` — Prisma and the db scripts do not read `.env.development`                    |
| API exits with `Config validation error: "X" is required` | fill the key in `apps/api/.env` — see the required-keys table in Quick start (AWS_* are required even locally) |
| Port in use                                               | `lsof -i :3000` (or 3001 / 8081) → `kill <PID>`                                                                |
| `next build` fails with `useState of null` / odd env      | you invoked Nx without the wrapper — use `pnpm nx …` / `pnpm build`, not `npx nx`                              |
| A cached task looks stale                                 | `pnpm nx:reset`, re-run with `--skip-nx-cache`; if results differ, declare the missing input                   |
| `.nx/` or `apps/web/.next-dev/` is huge                   | `pnpm nx:reset` · `pnpm web:clean` (dev Turbopack cache lives under `.next-dev`; builds use `.next`)           |
| Shared types look stale in an app                         | shared `dist` is out of date — any Nx command rebuilds it; or `pnpm --filter @tcg/shared dev`                  |
| Metro weirdness on mobile                                 | `pnpm mobile:start -- --clear`                                                                                 |
| Broken `node_modules`                                     | `pnpm clean && pnpm install`                                                                                   |
| `pnpm lint` fails                                         | check whether the failure is yours — `apps/web` has known pre-existing lint errors                             |

---

## Git workflow

- Conventional commits (`feat(api): …`, `fix(web): …`, `chore: …`, `build: …`), imperative
  mood, body says what changed and why.
- Branch from `origin/main`, rebase before pushing, PR into `main`. Merging to `main` deploys
  staging.
- Tracked git hooks: `pre-commit` (lint-staged only) and `pre-push` (branch guard +
  affected lint/typecheck/build) — see [Code quality](#code-quality). They run in worktrees too.
- PR CI: [`.github/workflows/affected.yml`](.github/workflows/affected.yml) runs affected lint
  (excluding `@tcg/web`), build, and test vs `main`.

### Git worktrees

Linked worktrees share git history, not gitignored local files (env, `node_modules`, the
`.ai` overlay). From a worktree, run bootstrap once so it can build, commit, and push
without copying those trees:

```bash
git worktree add .worktrees/my-feature feat/my-feature
cd .worktrees/my-feature
pnpm worktree:bootstrap          # or: bash scripts/worktree-bootstrap.sh --force
```

Or in one step from the primary checkout (creates the branch from `origin/main` when it
does not exist yet):

```bash
pnpm worktree:add .worktrees/my-feature feat/my-feature
```

Bootstrap **always** symlinks env files from the primary checkout (`apps/api/.env`,
`apps/api/.env.development`, `apps/web/.env.local`, `apps/mobile/.env`,
`apps/mobile/.env.local`, and a root `.env` if you have one).

**`.ai` overlay** — a nested git repo, gitignored from the client tree. Bootstrap creates
an overlay git worktree at `primary/.ai-worktrees/<name>/` on the **same branch name** as the
client worktree, then symlinks `.ai` to it. That lets parallel ticket worktrees each carry
their own overlay branch (`git -C .ai commit/push` per the `commit` and `close-ticket`
skills). Primary `.ai/` stays on `main`; ticket overlay WIP lives under `.ai-worktrees/`.
Then `bash .ai/setup.sh` (or legacy `setup:skills`) wires tool symlinks in the worktree.

`node_modules` (root + each workspace package) is linked **only when `pnpm-lock.yaml`
matches the primary checkout**. If the lockfile differs, install in the worktree instead:

```bash
pnpm install
```

Existing real directories are left alone unless you pass `--force` (replaces them with
symlinks). Build outputs (`dist/`, `.next/`, `coverage/`) are **not** shared — Nx rebuilds
those per branch.

Limitations: macOS/Linux only (symlinks). Sharing `node_modules` is unsafe across lockfile
changes. The primary checkout remains the place you run `pnpm install` as the source of
truth for deps. After merging a lockfile change from `main`, either install in primary and
re-run bootstrap, or `pnpm install` in the worktree. **Do not run `pnpm clean` in a
worktree** with symlinked `node_modules` — it deletes the primary install.

**Publishing overlay memory — the step that makes worktree work count.** The `commit` and
`close-ticket` skills push the _ticket_ overlay branch, which nobody reads. A fact reaches
the team only on overlay **main**. After `close-ticket` (or whenever the overlay work is
committed), publish and retire the overlay worktree in one step:

```bash
pnpm worktree:done          # from inside the worktree
```

It merges the ticket overlay branch into overlay main, pushes, deletes the branch, and
repoints `.ai` at the primary overlay. Conflicts in the append-only files
(`processed.log`, `reflections/INDEX.md`) are keep-both-sides; the script tells you the
exact commands.

When the PR is merged, remove the worktree pair — the guard refuses to discard
unpublished overlay memory:

```bash
pnpm worktree:remove .worktrees/my-feature          # add --force to discard
```

**Parallel-execution limits** (by design, document-level — plan around them):

- **Dev-server ports are fixed** (api 3000, web 3001, mobile 8081) — one running dev-server
  set at a time across all worktrees.
- **One Postgres.** Parallel `prisma migrate dev` from two worktrees collides — schema
  tickets don't co-run; everything else can.
- **Shared `node_modules` shares its caches** (`node_modules/.cache`). If two worktrees
  build simultaneously and Nx behaves oddly, set `NX_DAEMON=false` in the worktree —
  or skip sharing and `pnpm install` there (fast via the pnpm store).

---

## Further reading

- `DOCKER.md` — container setup in depth
- `apps/api/prisma/MIGRATION_BASELINE.md` — migration history and recovery
- `apps/mobile/ARCHITECTURE.md` — mobile layering and open findings
- `nx.json`, `pnpm-workspace.yaml` — task graph, caching, dependency catalog
- If the AI overlay is set up (`pnpm setup:skills`): `CLAUDE.md` and `.ai/claude/contexts/*.md`
  hold the per-surface conventions; `.ai/vault/` holds product knowledge.

---

Private and proprietary. **Last updated:** 17 August 2026.
