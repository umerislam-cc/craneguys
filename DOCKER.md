# Docker Implementation

## Architecture Overview

The project is a **pnpm monorepo** with 4 containerized services and a utility migration container.
There are two Compose files — one for production and one for development with hot-reload.

---

## Services

| Service    | Base Image                      | Port (prod) | Port (dev) | Purpose                           |
| ---------- | ------------------------------- | ----------- | ---------- | --------------------------------- |
| `postgres` | `postgres:16-alpine`            | 5432        | 5433       | PostgreSQL database               |
| `api`      | `node:22-slim` → `node:22-slim` | 3000        | 3000       | NestJS REST API                   |
| `web`      | `node:22-slim` → `node:22-slim` | 3001        | 3001       | Next.js web app                   |
| `mobile`   | `node:22-slim` → `nginx:alpine` | 3002        | 8081       | Expo web (static / Metro bundler) |
| `migrate`  | reuses API builder stage        | —           | —          | One-shot Prisma migrate + seed    |

---

## Multi-Stage Dockerfiles (Production)

All three apps (`api`, `web`, `mobile`) follow the same **4-stage pattern**:

```
base → deps → builder → runner
```

| Stage       | What happens                                                                               |
| ----------- | ------------------------------------------------------------------------------------------ |
| **base**    | Node 22 slim + pnpm enabled via corepack                                                   |
| **deps**    | Copies only `package.json` manifests, runs `pnpm install --frozen-lockfile` (layer-cached) |
| **builder** | Copies source, builds `@tcg/shared` first, then the app                                    |
| **runner**  | Minimal final image — only production artifacts, no devDeps or source                      |

### Per-App Runner Details

- **API** — plain `node:22-slim`, serves the compiled `dist/main.js`. Dependencies are pruned to prod-only via `pnpm deploy --prod`.
- **Web** — plain `node:22-slim`, uses Next.js **standalone output** (`server.js`) for a lean image.
- **Mobile** — **`nginx:alpine`**. Expo runs `expo export --platform web` to produce static files, which nginx serves on port 3002.

---

## Development vs Production

|                 | `docker-compose.dev.yml`                                    | `docker-compose.yml`                              |
| --------------- | ----------------------------------------------------------- | ------------------------------------------------- |
| **API**         | `Dockerfile.dev` — NestJS hot-reload (`nest start --watch`) | `Dockerfile` — compiled `dist/main.js`            |
| **Web**         | `Dockerfile.dev` — Next.js dev server                       | `Dockerfile` — standalone build                   |
| **Mobile**      | `Dockerfile.dev` — Expo Metro bundler (port 8081)           | `Dockerfile` — static files via nginx (port 3002) |
| **Source code** | Volume-mounted for live reload                              | Baked into image at build time                    |
| **DB port**     | 5433 (avoids conflict with local Postgres)                  | 5432                                              |

### Dev Volume Mounts (hot-reload)

The dev Compose file mounts source directories directly into the running containers so that file changes are reflected immediately without rebuilding:

- `apps/api/src` and `apps/api/prisma`
- `apps/web/src` and `apps/web/public`
- `apps/mobile/app`, `components`, `hooks`, `lib`, `providers`, `schemas`, `services`, `theme`, `assets`
- `packages/shared/src` (shared across all apps)

---

## Service Startup Order

```
postgres (healthcheck: pg_isready)
    └── api
            ├── web
            └── mobile
```

All services share a single Docker bridge network (`tcg-network` in production, `tcg-dev-network` in development). Containers resolve each other by service name (e.g. the API connects to `postgres:5432`).

---

## Environment Variables

### Build-time Args

`EXPO_PUBLIC_API_URL` and `NEXT_PUBLIC_API_URL` are passed as **build-time `ARG`** (not just runtime env) because Expo and Next.js bake `NEXT_PUBLIC_*` / `EXPO_PUBLIC_*` variables into the bundle at compile time.

### Runtime Secrets (production only)

The production API requires these to be set (no defaults — compose will error if missing):

```
JWT_ACCESS_SECRET
JWT_REFRESH_SECRET
```

---

## Database Migration Container

`migrate` is a **one-shot profile service** that runs Prisma migrations and seed, then exits:

```yaml
profiles:
  - tools
entrypoint: ['sh', '-c', 'npx prisma migrate deploy && npx prisma db seed']
```

Run it with:

```bash
docker compose run --rm migrate
```

It reuses the `builder` stage of the API Dockerfile so it has access to the Prisma CLI and migration files without the full runner image.

---

## Seed Users (created by `prisma db seed`)

| Role  | Email           | Password     |
| ----- | --------------- | ------------ |
| Admin | `admin@tcg.com` | `Admin@1234` |
| User  | `user@tcg.com`  | `User@1234`  |

---

## Makefile

The Makefile is a **shortcut layer** over Docker Compose commands. Run `make help` to list all targets.

### Production

| Command            | Description                          |
| ------------------ | ------------------------------------ |
| `make up`          | Start production stack (`-d`)        |
| `make down`        | Stop production stack                |
| `make build`       | Build production images              |
| `make rebuild`     | Rebuild production images (no cache) |
| `make logs`        | Tail all container logs              |
| `make logs-api`    | Tail API logs                        |
| `make logs-web`    | Tail web logs                        |
| `make logs-mobile` | Tail mobile logs                     |
| `make ps`          | Show running containers              |

### Development

| Command          | Description                     |
| ---------------- | ------------------------------- |
| `make dev`       | Start dev stack with hot-reload |
| `make dev-down`  | Stop dev stack                  |
| `make dev-build` | Build dev images                |

### Database

| Command          | Description                             |
| ---------------- | --------------------------------------- |
| `make migrate`   | Run Prisma migrations (production)      |
| `make seed`      | Run database seed                       |
| `make db-studio` | Open Prisma Studio (dev only, via exec) |

### Cleanup

| Command      | Description                                              |
| ------------ | -------------------------------------------------------- |
| `make clean` | Remove all containers, volumes, and local images         |
| `make prune` | Remove dangling Docker resources (`docker system prune`) |

---

## Quick Start

### Development

```bash
make dev
# or
docker compose -f docker-compose.dev.yml up
```

### Production

```bash
# 1. Start services
make up

# 2. Run migrations + seed (first time only)
make migrate
```

### Useful one-liners

```bash
# Rebuild a single service without cache
docker compose -f docker-compose.dev.yml build --no-cache mobile

# Follow logs for a specific service
docker compose -f docker-compose.dev.yml logs -f api

# Open a shell in a running container
docker exec -it tcg-api-dev sh
```
