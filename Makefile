# ──────────────────────────────────────────────
# TCG – Makefile (Docker shortcuts)
# ──────────────────────────────────────────────

.PHONY: help up down dev dev-down build logs logs-api logs-web migrate seed ps clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-18s\033[0m %s\n", $$1, $$2}'

# ── Production ───────────────────────────────

up: ## Start production stack
	docker compose up -d

down: ## Stop production stack
	docker compose down

build: ## Build production images
	docker compose build

rebuild: ## Rebuild production images (no cache)
	docker compose build --no-cache

logs: ## Tail all logs
	docker compose logs -f

logs-api: ## Tail API logs
	docker compose logs -f api

logs-web: ## Tail Web logs
	docker compose logs -f web

logs-mobile: ## Tail Mobile logs
	docker compose logs -f mobile

ps: ## Show running containers
	docker compose ps

# ── Development ──────────────────────────────

dev: ## Start dev stack (hot-reload)
	docker compose -f docker-compose.dev.yml up

dev-down: ## Stop dev stack
	docker compose -f docker-compose.dev.yml down

dev-build: ## Build dev images
	docker compose -f docker-compose.dev.yml build

# ── Database ─────────────────────────────────

migrate: ## Run Prisma migrations (production)
	docker compose run --rm migrate

seed: ## Run database seed
	docker compose run --rm migrate sh -c "npx prisma db seed"

db-studio: ## Open Prisma Studio (dev only)
	docker compose -f docker-compose.dev.yml exec api npx prisma studio

# ── Cleanup ──────────────────────────────────

clean: ## Remove all containers, volumes, and images
	docker compose down -v --rmi local
	docker compose -f docker-compose.dev.yml down -v --rmi local

prune: ## Remove dangling Docker resources
	docker system prune -f
